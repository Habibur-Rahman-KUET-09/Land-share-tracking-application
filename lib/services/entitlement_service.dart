import '../config/monetization.dart';
import '../models/group_tier.dart';
import '../models/land_group.dart';

/// The answer to "is this allowed?" — allowed, or refused with the l10n key
/// of a sentence explaining which limit was hit.
class Entitlement {
  final bool allowed;
  final String? reasonKey;

  const Entitlement.allow()
      : allowed = true,
        reasonKey = null;

  const Entitlement.deny(String this.reasonKey) : allowed = false;

  bool get blocked => !allowed;
}

/// The one place that decides what a group's tier lets it do.
///
/// Every check short-circuits to [Entitlement.allow] while
/// [Monetization.enabled] is `false`, so with the switch off this class is
/// a no-op and the app is exactly what it was before paid tiers existed.
///
/// These checks are UI-side. They are a product decision, not a security
/// boundary: what the server actually enforces is that a client can never
/// write `tier`/`tierExpiresAt` (see `firestore.rules`), which is the part
/// that matters — a modified client could exceed a member cap, but it
/// cannot grant itself the paid tier. Caps become server-enforced at the
/// same time billing goes live; the rule for it (a `memberIds.size()`
/// check on the group doc) is straightforward, it just has no business
/// running while the switch is off.
class EntitlementService {
  const EntitlementService._();

  static bool get active => Monetization.enabled;

  static TierLimits limitsOf(LandGroup group) =>
      TierLimits.of(group.activeTier);

  /// [activeMemberCount] is the number of active members *before* the one
  /// being added, Creator included.
  static Entitlement addMember(LandGroup group, int activeMemberCount) {
    if (!active) return const Entitlement.allow();
    final limits = limitsOf(group);
    if (limits.membersUnlimited) return const Entitlement.allow();
    if (activeMemberCount < limits.maxMembers) return const Entitlement.allow();
    return const Entitlement.deny('limit_members_reached');
  }

  /// [createdGroupCount] counts only groups this user *created*; groups they
  /// were added to never count against them, or friends could lock someone
  /// out of their own group by inviting them to theirs.
  ///
  /// The entitlement is per group, so "how many groups may I create" needs a
  /// tie-breaker: having paid for any one group lifts the cap. That keeps
  /// one payment meaning one payer — the person running the সমিতি — rather
  /// than forcing them to buy a second thing to open a second group.
  static Entitlement createGroup({
    required int createdGroupCount,
    required bool hasProGroup,
  }) {
    if (!active || hasProGroup) return const Entitlement.allow();
    const limits = TierLimits.free;
    if (limits.groupsUnlimited) return const Entitlement.allow();
    if (createdGroupCount < limits.maxGroupsCreated) {
      return const Entitlement.allow();
    }
    return const Entitlement.deny('limit_groups_reached');
  }

  static Entitlement export(LandGroup group) {
    if (!active) return const Entitlement.allow();
    return limitsOf(group).canExport
        ? const Entitlement.allow()
        : const Entitlement.deny('limit_export_pro');
  }

  static Entitlement import(LandGroup group) {
    if (!active) return const Entitlement.allow();
    return limitsOf(group).canImport
        ? const Entitlement.allow()
        : const Entitlement.deny('limit_import_pro');
  }
}
