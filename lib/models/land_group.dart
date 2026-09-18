import 'package:cloud_firestore/cloud_firestore.dart';

import 'group_tier.dart';

/// FR 2.2: Flexible contribution — সবাই সমান (equal) নাকি প্রতিটি সদস্যের
/// জন্য আলাদা amount (custom), Creator এটা group creation/edit-এ টগল করে।
enum ContributionType { equal, custom }

ContributionType contributionTypeFromString(String? v) =>
    v == 'custom' ? ContributionType.custom : ContributionType.equal;

/// What a group is actually for. All three share the same "members pay a
/// monthly share into a pool" spine — they differ in where the pool goes:
///
/// - [installment]: out to a builder/seller against a land purchase plan
///   (the app's original concept).
/// - [savings]: nowhere yet — it accumulates as a group fund, with
///   deposits to a bank/holding account tracked the same way builder
///   payments are.
/// - [lottery]: to one member each month, drawn by lot (a ROSCA/সমিতি) —
///   an interest-free loan repaid by that member continuing to pay their
///   monthly share for the rest of the cycle. Each member wins exactly
///   once per cycle, so past winners drop out of later draws.
enum GroupType { installment, savings, lottery }

GroupType groupTypeFromString(String? v) {
  switch (v) {
    case 'savings':
      return GroupType.savings;
    case 'lottery':
      return GroupType.lottery;
    default:
      return GroupType.installment;
  }
}

String groupTypeToString(GroupType type) => type.name;

/// A "Land Group" (groups/{id}) — one jointly-purchased land, its
/// installment plan, and the friends sharing it.
///
/// Per-member permissions (manage group, approve entries, record builder
/// payments, ...) come from each member's own role field in the `members`
/// subcollection (see [GroupMember]) — not tracked redundantly here.
/// [memberIds] stays denormalized on the group doc only because it's what
/// GroupListScreen's "my groups" query filters on.
/// Field names here still read "land"/"builder" because real groups are
/// already storing them under those Firestore keys — renaming them would
/// orphan live data. For savings/lottery groups they carry the analogous
/// value instead ([totalLandValue] a savings target, [monthlyTotalToBuilder]
/// the monthly pool/pot), and the UI labels them per [groupType] — see
/// `lib/utils/group_type_labels.dart`.
class LandGroup {
  final String id;
  final String name;
  final GroupType groupType;
  final String landLocation;
  final double totalLandValue;
  final int totalInstallments;
  final double monthlyTotalToBuilder;
  final int dueDayOfMonth; // 1-28, day of month the builder payment is due

  /// "One man army" — one person records everything themselves, so there's
  /// no second party to satisfy Maker-Checker. Entries save as approved on
  /// the spot and the manager may record them on any member's behalf.
  final bool singleManager;
  final ContributionType contributionType;

  /// What this group has paid for. Server-owned: it is written only by the
  /// purchase-verification Cloud Function via the Admin SDK, never by the
  /// app — `firestore.rules` rejects any client write that touches `tier`
  /// or `tierExpiresAt`, and [toMap] deliberately omits both so creating a
  /// group can't smuggle one in. Absent on the doc means [GroupTier.free],
  /// which is every group that exists today.
  final GroupTier tier;

  /// When a paid tier lapses. `null` on a [GroupTier.pro] group means it
  /// doesn't expire (a grant, not a subscription).
  final DateTime? tierExpiresAt;

  final String createdBy;
  final DateTime createdAt;
  final List<String> memberIds;

  const LandGroup({
    required this.id,
    required this.name,
    this.groupType = GroupType.installment,
    required this.landLocation,
    required this.totalLandValue,
    required this.totalInstallments,
    required this.monthlyTotalToBuilder,
    required this.dueDayOfMonth,
    this.singleManager = false,
    required this.contributionType,
    this.tier = GroupTier.free,
    this.tierExpiresAt,
    required this.createdBy,
    required this.createdAt,
    required this.memberIds,
  });

  LandGroup copyWith({
    String? name,
    GroupType? groupType,
    String? landLocation,
    double? totalLandValue,
    int? totalInstallments,
    double? monthlyTotalToBuilder,
    int? dueDayOfMonth,
    bool? singleManager,
    ContributionType? contributionType,
    List<String>? memberIds,
  }) {
    return LandGroup(
      id: id,
      name: name ?? this.name,
      groupType: groupType ?? this.groupType,
      landLocation: landLocation ?? this.landLocation,
      totalLandValue: totalLandValue ?? this.totalLandValue,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      monthlyTotalToBuilder: monthlyTotalToBuilder ?? this.monthlyTotalToBuilder,
      dueDayOfMonth: dueDayOfMonth ?? this.dueDayOfMonth,
      singleManager: singleManager ?? this.singleManager,
      contributionType: contributionType ?? this.contributionType,
      tier: tier,
      tierExpiresAt: tierExpiresAt,
      createdBy: createdBy,
      createdAt: createdAt,
      memberIds: memberIds ?? this.memberIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'groupType': groupTypeToString(groupType),
      'landLocation': landLocation,
      'totalLandValue': totalLandValue,
      'totalInstallments': totalInstallments,
      'monthlyTotalToBuilder': monthlyTotalToBuilder,
      'dueDayOfMonth': dueDayOfMonth,
      'singleManager': singleManager,
      'contributionType': contributionType == ContributionType.custom ? 'custom' : 'equal',
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'memberIds': memberIds,
    };
  }

  /// Groups created before group types existed have neither key — they're
  /// all the original installment concept, managed by more than one person.
  factory LandGroup.fromMap(String id, Map<String, dynamic> map) {
    return LandGroup(
      id: id,
      name: (map['name'] as String?) ?? '',
      groupType: groupTypeFromString(map['groupType'] as String?),
      landLocation: (map['landLocation'] as String?) ?? '',
      totalLandValue: (map['totalLandValue'] as num?)?.toDouble() ?? 0,
      totalInstallments: (map['totalInstallments'] as num?)?.toInt() ?? 0,
      monthlyTotalToBuilder: (map['monthlyTotalToBuilder'] as num?)?.toDouble() ?? 0,
      dueDayOfMonth: (map['dueDayOfMonth'] as num?)?.toInt() ?? 5,
      singleManager: (map['singleManager'] as bool?) ?? false,
      contributionType: contributionTypeFromString(map['contributionType'] as String?),
      tier: groupTierFromString(map['tier'] as String?),
      tierExpiresAt: (map['tierExpiresAt'] as Timestamp?)?.toDate(),
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberIds: List<String>.from((map['memberIds'] as List?) ?? const []),
    );
  }

  /// The tier actually in force right now — a paid group whose period has
  /// run out reads as free again until it is renewed, without anything
  /// having to rewrite the doc at the moment it lapses.
  GroupTier get activeTier {
    if (tier == GroupTier.free) return GroupTier.free;
    final until = tierExpiresAt;
    if (until != null && until.isBefore(DateTime.now())) return GroupTier.free;
    return tier;
  }

  /// Convenience for "is this group on a paid tier right now" — the tier
  /// itself answers which one (`group.activeTier`).
  bool get isPaid => activeTier.isPaid;
}
