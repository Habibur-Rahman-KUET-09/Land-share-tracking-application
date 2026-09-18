import '../config/monetization.dart';
import '../models/group_tier.dart';

/// Outcome of a purchase attempt, kept deliberately coarse — the UI only
/// needs to know whether to celebrate, stay quiet, or show an error.
enum BillingOutcome { purchased, pending, cancelled, unavailable, failed }

class BillingResult {
  final BillingOutcome outcome;
  final String? message;
  const BillingResult(this.outcome, {this.message});
}

/// A store product, as the store describes it. [price] is the store's own
/// localized string ("৳২০০.০০"), never a number we formatted ourselves —
/// the price shown to a user must be the one they will actually be charged.
class BillingProduct {
  final String id;
  final String title;
  final String price;
  const BillingProduct({required this.id, required this.title, required this.price});
}

/// The store-facing half of the paid tiers.
///
/// Intentionally an interface with only a stub behind it: the
/// `in_app_purchase` package is not a dependency yet, so nothing dead ships
/// in the APK while [Monetization.enabled] is `false`.
///
/// Implementing it later means:
///  * add `in_app_purchase` to pubspec.yaml,
///  * write `PlayBillingService implements BillingService` that queries the
///    product ids from [Monetization.productIdFor] and starts the purchase
///    flow,
///  * send the purchase token to a Cloud Function that verifies it against
///    the Play Developer API and writes `tier`/`tierExpiresAt` on the group
///    doc with the Admin SDK,
///  * return [BillingOutcome.pending] until that write lands — the group
///    doc, not the client, is the source of truth for what was bought.
///
/// Do not let a client-side purchase callback grant the tier directly.
abstract class BillingService {
  Future<bool> isAvailable();

  /// Every purchasable tier the store could price, keyed by tier. A tier
  /// missing from the map is one the store didn't return — show it, but
  /// don't let it be bought.
  Future<Map<GroupTier, BillingProduct>> loadProducts();

  /// [groupId] is what the entitlement attaches to — a paid group, not a
  /// paid account (see [Monetization.perGroupEntitlement]). It travels to
  /// the store as the obfuscated account id so the verifying function knows
  /// which group doc to write.
  ///
  /// Upgrading from one paid tier to a higher one is the same call: Play
  /// handles the proration itself when both products are in one
  /// subscription group, which is how they must be configured.
  Future<BillingResult> purchase({required String groupId, required GroupTier tier});

  /// Re-delivers purchases the store knows about but this install doesn't
  /// (reinstall, new device). Also a store review requirement on iOS.
  Future<void> restorePurchases();

  static BillingService instance = const UnavailableBillingService();
}

/// What ships today: billing that politely says it isn't there. Keeps every
/// call site honest — the upgrade screen already handles "no store" because
/// that is the only answer it has ever gotten.
class UnavailableBillingService implements BillingService {
  const UnavailableBillingService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<Map<GroupTier, BillingProduct>> loadProducts() async => const {};

  @override
  Future<BillingResult> purchase({required String groupId, required GroupTier tier}) async =>
      const BillingResult(BillingOutcome.unavailable);

  @override
  Future<void> restorePurchases() async {}
}
