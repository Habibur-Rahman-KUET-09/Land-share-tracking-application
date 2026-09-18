/// Paid-tier scaffolding. Everything monetization-related in the app asks
/// [Monetization.enabled] first, and while that is `false` the app behaves
/// exactly as it always has: no limits, no upgrade prompts, nothing about
/// money anywhere in the UI.
///
/// Turning it on is deliberately not just a flag flip. Before setting
/// [enabled] to `true` all of this has to exist:
///
/// 1. A Play Console account with an in-app subscription whose product id
///    matches [proProductId] (and the matching App Store product, if iOS
///    ever ships).
/// 2. A real [BillingService] implementation (the `in_app_purchase`
///    package) replacing the stub in `lib/services/billing_service.dart`.
/// 3. A Cloud Function that verifies the purchase token server-side with
///    the Play Developer API and writes `tier`/`tierExpiresAt` onto the
///    group doc using the Admin SDK — `firestore.rules` refuses those two
///    fields from every client, so a purchase cannot be self-granted.
///
/// Until then the upgrade screen exists and explains itself, but it cannot
/// take money, and no existing group ever loses a feature.
library;

class Monetization {
  const Monetization._();

  /// The master switch. Keep this `false` until items 1-3 above are done.
  static const bool enabled = false;

  /// Play/App Store product id for the per-group yearly subscription.
  static const String proProductId = 'kistify_pro_group_yearly';

  /// Indicative price, shown on the upgrade screen when the store cannot
  /// be reached. The store's own localized price wins whenever billing is
  /// live — never quote this number once real products load.
  static const int proYearlyPriceBdt = 400;

  /// The entitlement is per *group*, not per user: one person (normally
  /// the Creator) pays and every member of that group gets the benefit.
  /// A ten-friend সমিতি therefore has one payer, not ten.
  static const bool perGroupEntitlement = true;

  /// Where a user writes when billing is not available on their device.
  static const String supportEmail = 'veryfew.2018@gmail.com';
}
