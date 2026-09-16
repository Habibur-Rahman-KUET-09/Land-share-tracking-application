// FR 2.6 (Notifications & Reminders):
//   - due-date reminders for members (a few days before the group's due day)
//   - "কেউ কিস্তি না দিলে Admin কে alert" (a day after the due day)
//   - "বিল্ডারকে টাকা জমা দেওয়ার deadline reminder" for whoever records
//     builder payments (Creator/Collector)
//   - "Push Notification for Pending Approval" whenever a member submits a
//     contribution, to every OTHER approver (never the submitter — mirrors
//     the Maker-Checker rule enforced in Firestore rules / ContributionService)
//   - a contribution's submitter told once it's approved/rejected
//   - the group's Creator/Admin told when a builder payment is recorded
//
// Every notification is written twice: once as an FCM push (best-effort —
// silently does nothing if the recipient has no registered device), and
// once as a users/{uid}/notifications/{id} doc, which is what the app's
// in-header notification bell actually reads (see
// lib/services/notification_service.dart) — a push can be missed (app
// closed, permission denied, notification swiped away) but the in-app
// inbox is always there next time they open the app.
//
// Deploy with: firebase deploy --only functions (after `npm install` in
// this directory — see README.md "Firebase setup"). Scheduled functions
// require the project to be on the Blaze (pay-as-you-go) plan; the free
// Spark plan can still deploy the on-write triggers below.
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Writes a users/{uid}/notifications doc (read by the app's bell icon) and
 * best-effort pushes to every FCM token registered under
 * users/{uid}/fcmTokens (see lib/services/notification_service.dart).
 */
async function notifyUser(uid, { title, body, type, groupId = null, extra = {} }) {
  await db
    .collection('users')
    .doc(uid)
    .collection('notifications')
    .add({
      title,
      body,
      type,
      groupId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });

  const tokensSnap = await db.collection('users').doc(uid).collection('fcmTokens').get();
  const tokens = tokensSnap.docs.map((d) => d.id);
  if (tokens.length === 0) return;
  await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: { type, groupId: groupId || '', ...extra },
  });
}

/**
 * Active members of [groupRef] whose role is one of [roles] — roles live
 * only on each member's own doc (see firestore.rules), there's no
 * denormalized "adminIds" list on the group document itself.
 */
async function activeMembersWithRole(groupRef, roles) {
  const snap = await groupRef.collection('members').where('status', '==', 'active').get();
  return snap.docs.filter((d) => roles.includes(d.data().role)).map((d) => d.id);
}

exports.onContributionCreated = onDocumentCreated(
  'groups/{groupId}/contributions/{contributionId}',
  async (event) => {
    const contribution = event.data.data();
    if (contribution.status !== 'pendingConfirmation') return;

    const groupId = event.params.groupId;
    const groupRef = db.collection('groups').doc(groupId);
    const groupSnap = await groupRef.get();
    if (!groupSnap.exists) return;
    const group = groupSnap.data();

    // Maker-Checker: never notify the person who submitted it, or the
    // member the entry belongs to (they can't approve their own entry
    // anyway — see firestore.rules and ContributionService.approve).
    const approverIds = (await activeMembersWithRole(groupRef, ['creator', 'admin', 'collector'])).filter(
      (uid) => uid !== contribution.submittedBy && uid !== contribution.memberId,
    );

    await Promise.all(
      approverIds.map((uid) =>
        notifyUser(uid, {
          title: 'নতুন কিস্তি অনুমোদনের অপেক্ষায়',
          body: `${group.name} — একটি কিস্তির এন্ট্রি আপনার অনুমোদনের অপেক্ষায় আছে।`,
          type: 'pending_approval',
          groupId,
          extra: { contributionId: event.params.contributionId },
        }),
      ),
    );
  },
);

exports.onContributionUpdated = onDocumentUpdated(
  'groups/{groupId}/contributions/{contributionId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (before.status === after.status) return;
    if (after.status !== 'approved' && after.status !== 'rejected') return;

    const groupId = event.params.groupId;
    const groupSnap = await db.collection('groups').doc(groupId).get();
    if (!groupSnap.exists) return;
    const group = groupSnap.data();

    const approved = after.status === 'approved';
    const title = approved ? 'কিস্তি অনুমোদিত হয়েছে' : 'কিস্তি প্রত্যাখ্যাত হয়েছে';
    const body = approved
      ? `${group.name} — আপনার একটি কিস্তির এন্ট্রি অনুমোদিত হয়েছে।`
      : `${group.name} — আপনার একটি কিস্তির এন্ট্রি প্রত্যাখ্যাত হয়েছে${after.rejectReason ? ': ' + after.rejectReason : ''}।`;

    // The member the entry belongs to, and whoever submitted it — usually
    // the same person, but a submission can be made on another member's
    // behalf, so both are told.
    const recipients = new Set([after.memberId, after.submittedBy].filter(Boolean));

    await Promise.all(
      [...recipients].map((uid) =>
        notifyUser(uid, {
          title,
          body,
          type: approved ? 'contribution_approved' : 'contribution_rejected',
          groupId,
          extra: { contributionId: event.params.contributionId },
        }),
      ),
    );
  },
);

exports.onBuilderPaymentCreated = onDocumentCreated(
  'groups/{groupId}/builderPayments/{paymentId}',
  async (event) => {
    const payment = event.data.data();
    const groupId = event.params.groupId;
    const groupRef = db.collection('groups').doc(groupId);
    const groupSnap = await groupRef.get();
    if (!groupSnap.exists) return;
    const group = groupSnap.data();

    // Oversight: Creator/Admin told a payment went out, excluding whoever
    // recorded it themselves.
    const recipients = (await activeMembersWithRole(groupRef, ['creator', 'admin'])).filter(
      (uid) => uid !== payment.recordedBy,
    );

    await Promise.all(
      recipients.map((uid) =>
        notifyUser(uid, {
          title: 'বিল্ডারকে টাকা জমা দেওয়া হয়েছে',
          body: `${group.name} — বিল্ডারকে ৳${payment.amount} জমা দেওয়া হয়েছে।`,
          type: 'builder_payment',
          groupId,
          extra: { paymentId: event.params.paymentId },
        }),
      ),
    );
  },
);

exports.dailyReminders = onSchedule('every day 09:00', async () => {
  const today = new Date();
  const day = today.getDate();
  const month = today.getMonth() + 1;
  const year = today.getFullYear();

  const groupsSnap = await db.collection('groups').get();

  for (const groupDoc of groupsSnap.docs) {
    const group = groupDoc.data();
    const groupId = groupDoc.id;
    const dueDay = group.dueDayOfMonth || 5;

    const membersSnap = await groupDoc.ref.collection('members').where('status', '==', 'active').get();
    const members = membersSnap.docs.map((d) => ({ uid: d.id, ...d.data() }));

    const contributionsSnap = await groupDoc.ref
      .collection('contributions')
      .where('month', '==', month)
      .where('year', '==', year)
      .where('status', '==', 'approved')
      .get();
    const paidByMember = {};
    contributionsSnap.docs.forEach((d) => {
      const c = d.data();
      paidByMember[c.memberId] = (paidByMember[c.memberId] || 0) + c.amount;
    });

    const unpaidMembers = members.filter((m) => (paidByMember[m.uid] || 0) + 0.005 < m.monthlyAmount);

    // ৩ দিন আগে: যেসব সদস্য এখনো এই মাসের কিস্তি (পুরোপুরি) দেননি তাদের reminder.
    if (day === dueDay - 3) {
      await Promise.all(
        unpaidMembers.map((m) =>
          notifyUser(m.uid, {
            title: 'কিস্তির তারিখ কাছে আসছে',
            body: `${group.name} — আপনার এই মাসের কিস্তি ${dueDay} তারিখের মধ্যে দিন।`,
            type: 'due_reminder',
            groupId,
          }),
        ),
      );
    }

    // ২ দিন আগে: যারা বিল্ডারকে টাকা জমা দেন (Creator/Collector) তাদের deadline reminder।
    if (day === dueDay - 2) {
      const collectorIds = members.filter((m) => ['creator', 'collector'].includes(m.role)).map((m) => m.uid);
      await Promise.all(
        collectorIds.map((uid) =>
          notifyUser(uid, {
            title: 'বিল্ডারকে জমা দেওয়ার সময় কাছে আসছে',
            body: `${group.name} — বিল্ডারকে এই মাসের কিস্তি জমা দেওয়ার তারিখ কাছে আসছে (${dueDay} তারিখ)।`,
            type: 'builder_deadline',
            groupId,
          }),
        ),
      );
    }

    // ১ দিন পর: যারা এখনো দেননি, তাদের তালিকা Creator/Admin-দের কাছে alert হিসেবে।
    if (day === dueDay + 1 && unpaidMembers.length > 0) {
      const managerIds = members.filter((m) => ['creator', 'admin'].includes(m.role)).map((m) => m.uid);
      await Promise.all(
        managerIds.map((uid) =>
          notifyUser(uid, {
            title: 'কিস্তি বাকি আছে',
            body: `${group.name} — ${unpaidMembers.length} জন সদস্য এখনো এই মাসের কিস্তি দেননি।`,
            type: 'missed_payment_alert',
            groupId,
            extra: { memberIds: unpaidMembers.map((m) => m.uid).join(',') },
          }),
        ),
      );
    }
  }
});
