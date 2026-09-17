import 'package:cloud_firestore/cloud_firestore.dart';

/// Four roles per group:
/// - [creator]: full group management — edit plan, add/remove members,
///   change roles, delete the group. Also has every other role's abilities.
/// - [admin]: approve/reject entries, cancel an already-approved entry,
///   download reports, view the activity log.
/// - [collector]: approve/reject entries, record builder payments.
/// - [member]: submits their own entries. An entry's status is visible to
///   everyone regardless of role — that's a group-wide read, not gated here.
enum GroupRole { creator, admin, member, collector }

GroupRole groupRoleFromString(String? v) {
  switch (v) {
    case 'creator':
      return GroupRole.creator;
    case 'admin':
      return GroupRole.admin;
    case 'collector':
      return GroupRole.collector;
    default:
      return GroupRole.member;
  }
}

String groupRoleToString(GroupRole role) {
  switch (role) {
    case GroupRole.creator:
      return 'creator';
    case GroupRole.admin:
      return 'admin';
    case GroupRole.collector:
      return 'collector';
    case GroupRole.member:
      return 'member';
  }
}

enum MemberStatus { active, exited }

MemberStatus memberStatusFromString(String? v) =>
    v == 'exited' ? MemberStatus.exited : MemberStatus.active;

/// A group's membership record (groups/{groupId}/members/{uid}).
///
/// [monthlyAmount] is this member's own monthly contribution — for
/// [ContributionType.equal] it's auto-computed (monthlyTotalToBuilder /
/// active member count) and kept in sync on membership changes; for
/// [ContributionType.custom] the Creator sets it directly per member. Stored
/// on the member record (not recomputed on the fly) so past months' due
/// amounts stay correct even after later membership/plan changes (FR
/// "Member Exit/Add Mid-way Handling").
class GroupMember {
  final String uid;
  final String groupId;
  final GroupRole role;
  final double monthlyAmount;
  final MemberStatus status;
  final DateTime joinedAt;
  final DateTime? exitedAt;

  const GroupMember({
    required this.uid,
    required this.groupId,
    required this.role,
    required this.monthlyAmount,
    required this.status,
    required this.joinedAt,
    this.exitedAt,
  });

  bool get isCreator => role == GroupRole.creator;
  bool get isAdmin => role == GroupRole.admin;
  bool get isCollector => role == GroupRole.collector;
  bool get isActive => status == MemberStatus.active;

  /// Edit plan, add/remove members, change roles, delete the group.
  bool get canManageGroup => isCreator;

  /// Approve/reject a pending entry.
  bool get canApproveOrRejectContribution => isCreator || isAdmin || isCollector;

  /// Void an already-approved entry back out.
  bool get canCancelApprovedContribution => isCreator || isAdmin;

  /// Hold a month's lottery draw in a [GroupType.lottery] group. Same
  /// creator/admin bar firestore.rules puts on the lotteryDraws collection.
  bool get canRunLottery => isCreator || isAdmin;

  bool get canDownloadReports => isCreator || isAdmin;
  bool get canViewAuditLog => isCreator || isAdmin;
  bool get canRecordBuilderPayment => isCreator || isCollector;

  /// Correct a member's display name from the Members tab — e.g. one stuck
  /// with the "নতুন ব্যবহারকারী" fallback from a bad sign-up.
  bool get canEditMemberNames => isCreator || isAdmin;

  GroupMember copyWith({
    GroupRole? role,
    double? monthlyAmount,
    MemberStatus? status,
    DateTime? exitedAt,
  }) {
    return GroupMember(
      uid: uid,
      groupId: groupId,
      role: role ?? this.role,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      status: status ?? this.status,
      joinedAt: joinedAt,
      exitedAt: exitedAt ?? this.exitedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': groupRoleToString(role),
      'monthlyAmount': monthlyAmount,
      'status': status == MemberStatus.exited ? 'exited' : 'active',
      'joinedAt': Timestamp.fromDate(joinedAt),
      'exitedAt': exitedAt == null ? null : Timestamp.fromDate(exitedAt!),
    };
  }

  factory GroupMember.fromMap(String groupId, String uid, Map<String, dynamic> map) {
    return GroupMember(
      uid: uid,
      groupId: groupId,
      role: groupRoleFromString(map['role'] as String?),
      monthlyAmount: (map['monthlyAmount'] as num?)?.toDouble() ?? 0,
      status: memberStatusFromString(map['status'] as String?),
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      exitedAt: (map['exitedAt'] as Timestamp?)?.toDate(),
    );
  }
}
