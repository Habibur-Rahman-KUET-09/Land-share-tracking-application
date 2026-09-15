import 'package:cloud_firestore/cloud_firestore.dart';

/// FR 2.1: Admin/Collector (money collection + remitting to builder) vs
/// Member (views/pays only their own contribution). Multiple Admins allowed
/// (FR 6.2) — Maker-Checker enforced at the contribution-approval layer.
enum GroupRole { admin, member }

GroupRole groupRoleFromString(String? v) => v == 'admin' ? GroupRole.admin : GroupRole.member;

enum MemberStatus { active, exited }

MemberStatus memberStatusFromString(String? v) =>
    v == 'exited' ? MemberStatus.exited : MemberStatus.active;

/// A group's membership record (groups/{groupId}/members/{uid}).
///
/// [monthlyAmount] is this member's own monthly contribution — for
/// [ContributionType.equal] it's auto-computed (monthlyTotalToBuilder /
/// active member count) and kept in sync on membership changes; for
/// [ContributionType.custom] the Admin sets it directly per member. Stored
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

  bool get isAdmin => role == GroupRole.admin;
  bool get isActive => status == MemberStatus.active;

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
      'role': role == GroupRole.admin ? 'admin' : 'member',
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
