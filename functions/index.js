// FR 2.6 (Notifications & Reminders):
//   - due-date reminders for members (a few days before the group's due day)
//   - "কেউ কিস্তি না দিলে Admin কে alert" (a day after the due day)
//   - "বিল্ডারকে টাকা জমা দেওয়ার deadline reminder" for Admins
//   - "Push Notification for Pending Approval" whenever a member submits a
//     contribution, to every OTHER Admin (never the submitter — mirrors the
//     Maker-Checker rule enforced in Firestore rules / ContributionService)
//
// Deploy with: firebase deploy --only functions (after `npm install` in
// this directory — see README.md "Firebase setup"). Scheduled functions
// require the project to be on the Blaze (pay-as-you-go) plan; the free
// Spark plan can still deploy onContributionCreated.
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

/** Sends a notification to every FCM token registered under users/{uid}/fcmTokens (see lib/services/notification_service.dart). */
async function sendToUser(uid, notification, data = {}) {
  const tokensSnap = await db.collection('users').doc(uid).collection('fcmTokens').get();
  const tokens = tokensSnap.docs.map((d) => d.id);
  if (tokens.length === 0) return;
  await messaging.sendEachForMulticast({ tokens, notification, data });
}

exports.onContributionCreated = onDocumentCreated(
  'groups/{groupId}/contributions/{contributionId}',
  async (event) => {
    const contribution = event.data.data();
    if (contribution.status !== 'pendingConfirmation') return;

    const groupId = event.params.groupId;
    const groupSnap = await db.collection('groups').doc(groupId).get();
    if (!groupSnap.exists) return;
    const group = groupSnap.data();

    // Maker-Checker: never notify the person who submitted it, or the
    // member the entry belongs to (they can't approve their own entry
    // anyway — see firestore.rules and ContributionService.approve).
    const adminIds = (group.adminIds || []).filter(
      (uid) => uid !== contribution.submittedBy && uid !== contribution.memberId,
    );

    await Promise.all(
      adminIds.map((uid) =>
        sendToUser(
          uid,
          {
            title: 'নতুন কিস্তি অনুমোদনের অপেক্ষায়',
            body: `${group.name} — একটি কিস্তির এন্ট্রি আপনার অনুমোদনের অপেক্ষায় আছে।`,
          },
          { groupId, contributionId: event.params.contributionId, type: 'pending_approval' },
        ),
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
          sendToUser(
            m.uid,
            {
              title: 'কিস্তির তারিখ কাছে আসছে',
              body: `${group.name} — আপনার এই মাসের কিস্তি ${dueDay} তারিখের মধ্যে দিন।`,
            },
            { groupId, type: 'due_reminder' },
          ),
        ),
      );
    }

    // ২ দিন আগে: Admin-দের বিল্ডারকে জমা দেওয়ার deadline reminder।
    if (day === dueDay - 2) {
      await Promise.all(
        (group.adminIds || []).map((uid) =>
          sendToUser(
            uid,
            {
              title: 'বিল্ডারকে জমা দেওয়ার সময় কাছে আসছে',
              body: `${group.name} — বিল্ডারকে এই মাসের কিস্তি জমা দেওয়ার তারিখ কাছে আসছে (${dueDay} তারিখ)।`,
            },
            { groupId, type: 'builder_deadline' },
          ),
        ),
      );
    }

    // ১ দিন পর: যারা এখনো দেননি, তাদের তালিকা Admin-দের কাছে alert হিসেবে।
    if (day === dueDay + 1 && unpaidMembers.length > 0) {
      const unpaidUids = unpaidMembers.map((m) => m.uid).join(',');
      await Promise.all(
        (group.adminIds || []).map((uid) =>
          sendToUser(
            uid,
            {
              title: 'কিস্তি বাকি আছে',
              body: `${group.name} — ${unpaidMembers.length} জন সদস্য এখনো এই মাসের কিস্তি দেননি।`,
            },
            { groupId, type: 'missed_payment_alert', memberIds: unpaidUids },
          ),
        ),
      );
    }
  }
});
