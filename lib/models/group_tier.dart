/// What a group has paid for. Deliberately *not* called a "plan" — in this
/// app a plan is the installment plan (see `plan_history_entry.dart`), and
/// two meanings for one word in a money feature is how mistakes happen.
///
/// The tier lives on the group doc as `tier`/`tierExpiresAt`, written only
/// by the server (see `lib/config/monetization.dart`). A group doc with
/// neither key — which today is every group — is [GroupTier.free].
///
/// The values are a ladder: each one includes everything below it, and the
/// declaration order is ascending. [GroupTierRank.atLeast] compares by
/// index and relies on that, so a new tier goes in at its price position,
/// never appended at the end for convenience.
enum GroupTier { free, standard, pro }

GroupTier groupTierFromString(String? v) {
  switch (v) {
    case 'pro':
      return GroupTier.pro;
    case 'standard':
      return GroupTier.standard;
    default:
      return GroupTier.free;
  }
}

String groupTierToString(GroupTier tier) => tier.name;

/// l10n key for a tier's display name.
String tierNameKey(GroupTier tier) => switch (tier) {
      GroupTier.free => 'tier_free',
      GroupTier.standard => 'tier_standard',
      GroupTier.pro => 'tier_pro',
    };

extension GroupTierRank on GroupTier {
  bool atLeast(GroupTier other) => index >= other.index;
  bool get isPaid => this != GroupTier.free;
}

/// The limits of one tier, as data rather than scattered `if`s. Adding a
/// tier means adding a constant here and a case in [of]; nothing that
/// *asks* about limits (see `entitlement_service.dart`) changes at all.
///
/// A negative count means unlimited. The free numbers are picked so that a
/// real group can be run end-to-end without paying — a single সমিতি of ten
/// friends is the common case and stays free forever.
///
/// Standard exists because report export is what almost every treasurer
/// eventually wants, while bulk import is only for the few carrying years
/// of old books — and those few will pay more for it.
class TierLimits {
  /// Active members allowed in one group, Creator included.
  final int maxMembers;

  /// Groups one account may *create*. Being added to someone else's group
  /// never counts against this — otherwise a free user could be locked out
  /// of joining by friends who invite them.
  final int maxGroupsCreated;

  /// PDF/Excel report export.
  final bool canExport;

  /// Bulk Excel import of historical contributions and builder payments.
  final bool canImport;

  const TierLimits({
    required this.maxMembers,
    required this.maxGroupsCreated,
    required this.canExport,
    required this.canImport,
  });

  static const free = TierLimits(
    maxMembers: 10,
    maxGroupsCreated: 1,
    canExport: false,
    canImport: false,
  );

  static const standard = TierLimits(
    maxMembers: 25,
    maxGroupsCreated: 3,
    canExport: true,
    canImport: false,
  );

  static const pro = TierLimits(
    maxMembers: -1,
    maxGroupsCreated: -1,
    canExport: true,
    canImport: true,
  );

  static TierLimits of(GroupTier tier) => switch (tier) {
        GroupTier.free => free,
        GroupTier.standard => standard,
        GroupTier.pro => pro,
      };

  bool get membersUnlimited => maxMembers < 0;
  bool get groupsUnlimited => maxGroupsCreated < 0;
}
