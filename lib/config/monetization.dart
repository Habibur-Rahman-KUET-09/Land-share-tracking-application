import '../models/group_tier.dart';

/// Paid-tier scaffolding. Everything monetization-related in the app asks
/// [Monetization.enabled] first, and while that is `false` the app behaves
/// exactly as it always has: no limits, no upgrade prompts, nothing about
/// money anywhere in the UI.
///
/// Turning it on is deliberately not just a flag flip. Before setting
/// [enabled] to `true` all of this has to exist:
///
/// 1. A Play Console account with one in-app subscription per paid tier,
///    with the product ids in [productIdFor] (and matching App Store
///    products, if iOS ever ships).
/// 2. A real [BillingService] implementation (the `in_app_purchase`
///    package) replacing the stub in `lib/services/billing_service.dart`.
/// 3. A Cloud Function that verifies the purchase token server-side with
///    the Play Developer API and writes `tier`/`tierExpiresAt` onto the
///    group doc using the Admin SDK — `firestore.rules` refuses those two
///    fields from every client, so a purchase cannot be self-granted.
///
/// Until then the upgrade screen exists and explains itself, but it cannot
/// take money, and no existing group ever loses a feature.
///
/// One-way door worth knowing about: a Play subscription's price and what
/// it includes can be raised or extended later, but a tier cannot be
/// *split* after people have bought it — whoever paid for "unlimited"
/// keeps unlimited. Adding a tier above or below is fine; carving one up
/// is not.
class Monetization {
  const Monetization._();

  /// The master switch. Keep this `false` until items 1-3 above are done.
  static const bool enabled = false;

  /// Indicative yearly prices, shown when the store cannot be reached. The
  /// store's own localized price wins whenever billing is live — never
  /// quote these numbers once real products load.
  static const int standardYearlyPriceBdt = 200;
  static const int proYearlyPriceBdt = 500;

  /// The entitlement is per *group*, not per user: one person (normally
  /// the Creator) pays and every member of that group gets the benefit.
  /// A ten-friend সমিতি therefore has one payer, not ten.
  static const bool perGroupEntitlement = true;

  /// Where a user writes when billing is not available on their device.
  static const String supportEmail = 'veryfew.2018@gmail.com';

  /// Store product id per paid tier. [GroupTier.free] has none — it is the
  /// absence of a purchase, not a product.
  static String? productIdFor(GroupTier tier) => switch (tier) {
        GroupTier.free => null,
        GroupTier.standard => 'kistify_standard_group_yearly',
        GroupTier.pro => 'kistify_pro_group_yearly',
      };

  static int indicativePriceFor(GroupTier tier) => switch (tier) {
        GroupTier.free => 0,
        GroupTier.standard => standardYearlyPriceBdt,
        GroupTier.pro => proYearlyPriceBdt,
      };

  /// The tiers that can actually be bought, cheapest first.
  static const List<GroupTier> purchasableTiers = [
    GroupTier.standard,
    GroupTier.pro,
  ];
}
