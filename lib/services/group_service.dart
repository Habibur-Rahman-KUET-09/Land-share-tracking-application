import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/group_member.dart';
import '../models/land_group.dart';
import '../models/plan_history_entry.dart';
import 'audit_service.dart';

/// FR 2.1 (User & Group Management) + FR 2.2 (Installment Plan Setup) +
/// FR Finalized Decision 4 (plan edits are tracked in history).
class GroupService {
  final FirebaseFirestore _db;
  final AuditService _audit;

  GroupService({FirebaseFirestore? db, AuditService? audit})
      : _db = db ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  CollectionReference<Map<String, dynamic>> get _groups => _db.collection('groups');
  CollectionReference<Map<String, dynamic>> _members(String groupId) =>
      _groups.doc(groupId).collection('members');
  CollectionReference<Map<String, dynamic>> _planHistory(String groupId) =>
      _groups.doc(groupId).collection('planHistory');
  CollectionReference<Map<String, dynamic>> _contributions(String groupId) =>
      _groups.doc(groupId).collection('contributions');
  CollectionReference<Map<String, dynamic>> _builderPayments(String groupId) =>
      _groups.doc(groupId).collection('builderPayments');
  CollectionReference<Map<String, dynamic>> _auditLog(String groupId) =>
      _groups.doc(groupId).collection('auditLog');
  CollectionReference<Map<String, dynamic>> _lotteryDraws(String groupId) =>
      _groups.doc(groupId).collection('lotteryDraws');

  // ---------------------------------------------------------------------
  // Group CRUD
  // ---------------------------------------------------------------------

  /// Creates a new Land Group; the creator gets the [GroupRole.creator] role
  /// (full group management — the other roles are Admin/Collector/Member).
  Future<String> createGroup({
    required String name,
    GroupType groupType = GroupType.installment,
    required String landLocation,
    required double totalLandValue,
    required int totalInstallments,
    required double monthlyTotalToBuilder,
    required int dueDayOfMonth,
    bool singleManager = false,
    required ContributionType contributionType,
    required String creatorUid,
  }) async {
    final ref = _groups.doc();
    final group = LandGroup(
      id: ref.id,
      name: name,
      groupType: groupType,
      landLocation: landLocation,
      totalLandValue: totalLandValue,
      totalInstallments: totalInstallments,
      monthlyTotalToBuilder: monthlyTotalToBuilder,
      dueDayOfMonth: dueDayOfMonth,
      singleManager: singleManager,
      contributionType: contributionType,
      createdBy: creatorUid,
      createdAt: DateTime.now(),
      memberIds: [creatorUid],
    );
    await ref.set(group.toMap());
    final perMember = contributionType == ContributionType.equal ? monthlyTotalToBuilder : 0.0;
    await _members(ref.id).doc(creatorUid).set(
          GroupMember(
            uid: creatorUid,
            groupId: ref.id,
            role: GroupRole.creator,
            monthlyAmount: perMember,
            status: MemberStatus.active,
            joinedAt: DateTime.now(),
          ).toMap(),
        );
    await _audit.log(
      groupId: ref.id,
      actorId: creatorUid,
      action: 'create_group',
      targetType: 'group',
      targetId: ref.id,
      details: '"$name" গ্রুপ তৈরি করা হয়েছে',
    );
    return ref.id;
  }

  Stream<List<LandGroup>> watchUserGroups(String uid) {
    return _groups.where('memberIds', arrayContains: uid).snapshots().map(
          (snap) => snap.docs.map((d) => LandGroup.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<LandGroup?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map(
          (snap) => snap.exists ? LandGroup.fromMap(snap.id, snap.data()!) : null,
        );
  }

  Future<LandGroup?> getGroup(String groupId) async {
    final snap = await _groups.doc(groupId).get();
    return snap.exists ? LandGroup.fromMap(snap.id, snap.data()!) : null;
  }

  /// Creator-only, enforced by firestore.rules (group document update is
  /// gated on request.auth.uid == createdBy).
  Future<void> renameGroup({
    required String groupId,
    required String name,
    required String editedBy,
  }) async {
    await _groups.doc(groupId).update({'name': name.trim()});
    await _audit.log(
      groupId: groupId,
      actorId: editedBy,
      action: 'rename_group',
      targetType: 'group',
      targetId: groupId,
      details: 'গ্রুপের নাম পরিবর্তন করে "${name.trim()}" করা হয়েছে',
    );
  }

  /// Turns "one man army" mode on or off after the fact — a group can start
  /// with a single manager and later grow into a Maker-Checker one, or the
  /// other way round. Already-recorded entries keep whatever status they
  /// were written with; this only affects new ones. Creator-only, enforced
  /// by firestore.rules.
  Future<void> setSingleManager({
    required String groupId,
    required bool singleManager,
    required String editedBy,
  }) async {
    await _groups.doc(groupId).update({'singleManager': singleManager});
    await _audit.log(
      groupId: groupId,
      actorId: editedBy,
      action: 'edit_plan',
      targetType: 'group',
      targetId: groupId,
      details: singleManager
          ? 'একক ম্যানেজার মোড চালু করা হয়েছে (অনুমোদনের ধাপ নেই)'
          : 'একক ম্যানেজার মোড বন্ধ করা হয়েছে (অনুমোদনের ধাপ ফিরে এসেছে)',
    );
  }

  /// FR Finalized Decision 4: edits are snapshotted to planHistory first, so
  /// the previous plan is always recoverable/visible (FR 2.8 transparency).
  Future<void> editPlan({
    required String groupId,
    required int totalInstallments,
    required double monthlyTotalToBuilder,
    required int dueDayOfMonth,
    required ContributionType contributionType,
    required String editedBy,
  }) async {
    final current = await getGroup(groupId);
    if (current == null) return;

    await _planHistory(groupId).add(
      PlanHistoryEntry(
        id: '',
        groupId: groupId,
        totalInstallments: current.totalInstallments,
        monthlyTotalToBuilder: current.monthlyTotalToBuilder,
        dueDayOfMonth: current.dueDayOfMonth,
        contributionType: current.contributionType == ContributionType.custom ? 'custom' : 'equal',
        editedBy: editedBy,
        editedAt: DateTime.now(),
      ).toMap(),
    );

    await _groups.doc(groupId).update({
      'totalInstallments': totalInstallments,
      'monthlyTotalToBuilder': monthlyTotalToBuilder,
      'dueDayOfMonth': dueDayOfMonth,
      'contributionType': contributionType == ContributionType.custom ? 'custom' : 'equal',
    });

    if (contributionType == ContributionType.equal) {
      await _applyEqualSplit(groupId, monthlyTotalToBuilder);
    }

    await _audit.log(
      groupId: groupId,
      actorId: editedBy,
      action: 'edit_plan',
      targetType: 'plan',
      targetId: groupId,
      details: 'কিস্তি পরিকল্পনা সম্পাদনা করা হয়েছে',
    );
  }

  Stream<List<PlanHistoryEntry>> watchPlanHistory(String groupId) {
    return _planHistory(groupId).orderBy('editedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => PlanHistoryEntry.fromMap(groupId, d.id, d.data())).toList(),
        );
  }

  /// Permanently deletes the group and everything under it (members,
  /// contributions, builder payments, lottery draws, plan history, audit
  /// log). Creator-only
  /// — enforced both by the caller (GroupManagementScreen only shows this to
  /// a creator) and by firestore.rules. Firestore doesn't cascade-delete
  /// subcollections on its own, so each is cleared explicitly first.
  ///
  /// [_members] must be cleared LAST: every other subcollection's delete
  /// rule checks the caller's own role via their members/{uid} doc, so that
  /// doc (the creator's) has to still exist while those deletes run.
  Future<void> deleteGroup(String groupId) async {
    for (final col in [
      _contributions(groupId),
      _builderPayments(groupId),
      _lotteryDraws(groupId),
      _planHistory(groupId),
      _auditLog(groupId),
      _members(groupId),
    ]) {
      final snap = await col.get();
      if (snap.docs.isEmpty) continue;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _groups.doc(groupId).delete();
  }

  // ---------------------------------------------------------------------
  // Members
  // ---------------------------------------------------------------------

  Stream<List<GroupMember>> watchMembers(String groupId) {
    return _members(groupId).snapshots().map(
          (snap) => snap.docs.map((d) => GroupMember.fromMap(groupId, d.id, d.data())).toList(),
        );
  }

  Future<GroupMember?> getMember(String groupId, String uid) async {
    final snap = await _members(groupId).doc(uid).get();
    if (!snap.exists) return null;
    return GroupMember.fromMap(groupId, uid, snap.data()!);
  }

  /// FR "Member Exit/Add Mid-way Handling": joining doesn't touch past
  /// months' contribution records, only re-splits future equal-mode shares.
  Future<void> addMember({
    required String groupId,
    required String uid,
    required GroupRole role,
    double customMonthlyAmount = 0,
    required String invitedBy,
  }) async {
    if (role == GroupRole.creator) {
      throw StateError('একটি গ্রুপে একজনই Creator থাকতে পারে');
    }
    final group = await getGroup(groupId);
    if (group == null) return;

    await _members(groupId).doc(uid).set(
          GroupMember(
            uid: uid,
            groupId: groupId,
            role: role,
            monthlyAmount: group.contributionType == ContributionType.custom
                ? customMonthlyAmount
                : group.monthlyTotalToBuilder,
            status: MemberStatus.active,
            joinedAt: DateTime.now(),
          ).toMap(),
        );
    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([uid]),
    });

    if (group.contributionType == ContributionType.equal) {
      await _applyEqualSplit(groupId, group.monthlyTotalToBuilder);
    }

    await _audit.log(
      groupId: groupId,
      actorId: invitedBy,
      action: 'add_member',
      targetType: 'member',
      targetId: uid,
      details: 'নতুন সদস্য যোগ করা হয়েছে',
    );
  }

  Future<void> updateMemberRole({
    required String groupId,
    required String uid,
    required GroupRole role,
    required String actorId,
  }) async {
    final current = await getMember(groupId, uid);
    if (current?.isCreator ?? false) {
      throw StateError('Creator এর ভূমিকা পরিবর্তন করা যাবে না');
    }
    if (role == GroupRole.creator) {
      throw StateError('একটি গ্রুপে একজনই Creator থাকতে পারে');
    }
    // Nobody promotes or demotes themselves, whatever role they hold. Today
    // only the creator can reach this method at all and their own role is
    // already frozen above, so this changes no behaviour — it states the
    // invariant where it belongs instead of leaving it as a side effect of
    // who happens to have the button.
    if (uid == actorId) {
      throw StateError('নিজের ভূমিকা নিজে পরিবর্তন করা যাবে না');
    }
    await _members(groupId).doc(uid).update({'role': groupRoleToString(role)});
    await _audit.log(
      groupId: groupId,
      actorId: actorId,
      action: 'update_role',
      targetType: 'member',
      targetId: uid,
      details: '${_roleLabelBn(role)} করা হয়েছে',
    );
  }

  static String _roleLabelBn(GroupRole role) {
    switch (role) {
      case GroupRole.creator:
        return 'Creator';
      case GroupRole.admin:
        return 'Admin';
      case GroupRole.collector:
        return 'Collector';
      case GroupRole.member:
        return 'Member';
    }
  }

  /// FR 2.2: custom-mode per-member amount, set directly by the Creator.
  Future<void> updateMemberAmount({
    required String groupId,
    required String uid,
    required double monthlyAmount,
    required String actorId,
  }) async {
    await _members(groupId).doc(uid).update({'monthlyAmount': monthlyAmount});
    await _audit.log(
      groupId: groupId,
      actorId: actorId,
      action: 'update_member_amount',
      targetType: 'member',
      targetId: uid,
      details: 'মাসিক কিস্তির পরিমাণ পরিবর্তন করা হয়েছে',
    );
  }

  /// FR "Member Exit/Add Mid-way Handling" — keeps the member's own past
  /// contribution history intact; only re-splits the remaining active
  /// members' equal shares going forward.
  Future<void> exitMember({required String groupId, required String uid, required String actorId}) async {
    final group = await getGroup(groupId);
    if (group == null) return;
    final current = await getMember(groupId, uid);
    if (current?.isCreator ?? false) {
      throw StateError('Creator কে গ্রুপ থেকে বের করা যাবে না — পুরো গ্রুপ delete করতে হবে');
    }

    await _members(groupId).doc(uid).update({
      'status': 'exited',
      'exitedAt': Timestamp.now(),
    });

    if (group.contributionType == ContributionType.equal) {
      await _applyEqualSplit(groupId, group.monthlyTotalToBuilder);
    }

    await _audit.log(
      groupId: groupId,
      actorId: actorId,
      action: 'exit_member',
      targetType: 'member',
      targetId: uid,
      details: 'সদস্য গ্রুপ থেকে বের হয়ে গেছে',
    );
  }

  Future<void> _applyEqualSplit(String groupId, double monthlyTotalToBuilder) async {
    final snap = await _members(groupId).where('status', isEqualTo: 'active').get();
    if (snap.docs.isEmpty) return;
    final perMember = monthlyTotalToBuilder / snap.docs.length;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'monthlyAmount': perMember});
    }
    await batch.commit();
  }
}
