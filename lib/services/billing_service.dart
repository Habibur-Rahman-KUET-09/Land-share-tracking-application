import '../config/monetization.dart';

/// Outcome of a purchase attempt, kept deliberately coarse — the UI only
/// needs to know whether to celebrate, stay quiet, or show an error.
enum BillingOutcome { purchased, pending, cancelled, unavailable, failed }

class BillingResult {
  final BillingOutcome outcome;
  final String? message;
  const BillingResult(this.outcome, {this.message});
}

/// A store product, as the store describes it. [price] is the store's own
/// localized string ("৳৪০০.০০"), never a number we formatted ourselves —
/// the price shown to a user must be the one they will actually be charged.
class BillingProduct {
  final String id;
  final String title;
  final String price;
  const BillingProduct({required this.id, required this.title, required this.price});
}

/// The store-facing half of the paid tier.
///
/// Intentionally an interface with only a stub behind it: the
/// `in_app_purchase` package is not a dependency yet, so nothing dead ships
/// in the APK while [Monetization.enabled] is `false`.
///
/// Implementing it later means:
///  * add `in_app_purchase` to pubspec.yaml,
///  * write `PlayBillingService implements BillingService` that queries
///    [Monetization.proProductId] and starts the purchase flow,
///  * send the purchase token to a Cloud Function that verifies it against
///    the Play Developer API and writes `tier`/`tierExpiresAt` on the group
///    doc with the Admin SDK,
///  * return [BillingOutcome.pending] until that write lands — the group
///    doc, not the client, is the source of truth for what was bought.
///
/// Do not let a client-side purchase callback grant the tier directly.
abstract class BillingService {
  Future<bool> isAvailable();

  Future<BillingProduct?> loadProProduct();

  /// [groupId] is what the entitlement attaches to — one paid group, not a
  /// paid account (see [Monetization.perGroupEntitlement]). It travels to
  /// the store as the obfuscated account id so the verifying function knows
  /// which group doc to write.
  Future<BillingResult> purchasePro(String groupId);

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
  Future<BillingProduct?> loadProProduct() async => null;

  @override
  Future<BillingResult> purchasePro(String groupId) async =>
      const BillingResult(BillingOutcome.unavailable);

  @override
  Future<void> restorePurchases() async {}
}
