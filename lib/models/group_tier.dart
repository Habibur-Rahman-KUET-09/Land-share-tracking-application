/// What a group has paid for. Deliberately *not* called a "plan" — in this
/// app a plan is the installment plan (see `plan_history_entry.dart`), and
/// two meanings for one word in a money feature is how mistakes happen.
///
/// The tier lives on the group doc as `tier`/`tierExpiresAt`, written only
/// by the server (see `lib/config/monetization.dart`). A group doc with
/// neither key — which today is every group — is [GroupTier.free].
enum GroupTier { free, pro }

GroupTier groupTierFromString(String? v) =>
    v == 'pro' ? GroupTier.pro : GroupTier.free;

String groupTierToString(GroupTier tier) => tier.name;

/// The limits of one tier, as data rather than scattered `if`s.
///
/// A negative count means unlimited. The free numbers are picked so that a
/// real group can be run end-to-end without paying — a single সমিতি of ten
/// friends is the common case and stays free forever; paying buys more
/// groups, bigger groups, and the bulk data features (export/import) that
/// only a group treasurer keeping formal books actually needs.
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

  static const pro = TierLimits(
    maxMembers: -1,
    maxGroupsCreated: -1,
    canExport: true,
    canImport: true,
  );

  static TierLimits of(GroupTier tier) => tier == GroupTier.pro ? pro : free;

  bool get membersUnlimited => maxMembers < 0;
  bool get groupsUnlimited => maxGroupsCreated < 0;
}
