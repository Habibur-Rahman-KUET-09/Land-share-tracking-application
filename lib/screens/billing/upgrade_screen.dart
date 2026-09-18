import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/monetization.dart';
import '../../l10n/app_strings.dart';
import '../../models/group_tier.dart';
import '../../models/land_group.dart';
import '../../services/billing_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kistify_app_bar.dart';

/// Shows why something was blocked and offers the way out. Returns `true`
/// if the user went to the upgrade screen, so a caller can re-check.
///
/// With [Monetization.enabled] false nothing ever calls this, because every
/// EntitlementService check answers "allowed".
Future<bool> showUpgradePrompt(
  BuildContext context, {
  required LandGroup group,
  required String reasonKey,
}) async {
  final go = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                S.t(context, 'upgrade_title'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.heading),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            S.t(context, reasonKey),
            style: const TextStyle(fontSize: 13.5, height: 1.6, color: AppColors.bodyText),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(S.t(context, 'see_packages')),
            ),
          ),
        ],
      ),
    ),
  );
  if (go != true || !context.mounted) return false;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => UpgradeScreen(group: group)),
  );
  return true;
}

/// The paid-tier screen: what the group has now, what each tier adds, and
/// purchase buttons that are honest about the store not being there yet.
class UpgradeScreen extends StatefulWidget {
  final LandGroup group;
  const UpgradeScreen({super.key, required this.group});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _loading = true;
  bool _storeAvailable = false;
  GroupTier? _buying;
  Map<GroupTier, BillingProduct> _products = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final billing = BillingService.instance;
    final available = await billing.isAvailable();
    final products = available ? await billing.loadProducts() : const <GroupTier, BillingProduct>{};
    if (!mounted) return;
    setState(() {
      _storeAvailable = available;
      _products = products;
      _loading = false;
    });
  }

  Future<void> _buy(GroupTier tier) async {
    setState(() => _buying = tier);
    final result = await BillingService.instance.purchase(
      groupId: widget.group.id,
      tier: tier,
    );
    if (!mounted) return;
    setState(() => _buying = null);
    final message = switch (result.outcome) {
      // The tier lands on the group doc from the server, so there is
      // nothing to write here — the group stream repaints on its own.
      BillingOutcome.purchased => null,
      BillingOutcome.cancelled => null,
      BillingOutcome.pending => S.t(context, 'purchase_pending'),
      BillingOutcome.unavailable => S.t(context, 'upgrade_unavailable'),
      BillingOutcome.failed => result.message ?? S.t(context, 'upgrade_unavailable'),
    };
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _mailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: Monetization.supportEmail,
      queryParameters: {'subject': 'Kistify — ${widget.group.name}'},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// The store's own localized price when it has one, the indicative
  /// constant otherwise — never a number formatted over a real product.
  String _priceOf(GroupTier tier) =>
      _products[tier]?.price ?? '৳${Monetization.indicativePriceFor(tier)}';

  @override
  Widget build(BuildContext context) {
    final current = widget.group.activeTier;
    final expiry = widget.group.tierExpiresAt;
    return Scaffold(
      appBar: KistifyAppBar(title: S.t(context, 'upgrade_title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0x1A0F6E5C),
                foregroundColor: AppColors.primary,
                child: Icon(current.isPaid ? Icons.workspace_premium : Icons.groups_outlined),
              ),
              title: Text(S.t(context, 'current_tier')),
              subtitle: Text(
                current.isPaid && expiry != null
                    ? '${S.t(context, tierNameKey(current))} — '
                        '${S.t(context, 'active_until')} ${expiry.day}/${expiry.month}/${expiry.year}'
                    : '${S.t(context, tierNameKey(current))} — ${widget.group.name}',
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final tier in GroupTier.values) ...[
            _TierCard(
              tier: tier,
              current: current,
              price: tier.isPaid ? _priceOf(tier) : null,
              // Only a tier above the current one can be bought, and only
              // once the store has answered. Downgrades go through Play's
              // own subscription settings, not through this screen.
              onBuy: !_loading && _storeAvailable && tier.isPaid && !current.atLeast(tier)
                  ? () => _buy(tier)
                  : null,
              busy: _buying == tier,
            ),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (!_storeAvailable && !current.atLeast(GroupTier.pro))
            Text(
              S.t(context, 'upgrade_unavailable'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.mutedText),
            ),
          if (_storeAvailable)
            Center(
              child: TextButton(
                onPressed: BillingService.instance.restorePurchases,
                child: Text(S.t(context, 'restore_purchases')),
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              S.t(context, 'tier_price_note'),
              style: const TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.mutedText),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _mailSupport,
              icon: const Icon(Icons.mail_outline, size: 18),
              label: Text('${S.t(context, 'upgrade_contact')}: ${Monetization.supportEmail}',
                  style: const TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tier, with every feature listed rather than only its differences —
/// on a phone the cards can't sit side by side, so each has to stand alone.
class _TierCard extends StatelessWidget {
  final GroupTier tier;
  final GroupTier current;
  final String? price;
  final VoidCallback? onBuy;
  final bool busy;

  const _TierCard({
    required this.tier,
    required this.current,
    this.price,
    this.onBuy,
    this.busy = false,
  });

  /// Built from TierLimits so the card can never drift from what the app
  /// actually enforces.
  List<(String, bool)> _features(BuildContext context) {
    final limits = TierLimits.of(tier);
    return [
      (S.t(context, 'feature_core'), true),
      (
        limits.groupsUnlimited
            ? S.t(context, 'feature_groups_unlimited')
            : '${limits.maxGroupsCreated} ${S.t(context, 'feature_groups_count')}',
        true
      ),
      (
        limits.membersUnlimited
            ? S.t(context, 'feature_members_unlimited')
            : '${S.t(context, 'feature_members_upto')} ${limits.maxMembers} ${S.t(context, 'feature_members_count')}',
        true
      ),
      (S.t(context, 'feature_export'), limits.canExport),
      (S.t(context, 'feature_import'), limits.canImport),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = tier == current;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? AppColors.primary : AppColors.border,
          width: isCurrent ? 1.4 : 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  S.t(context, tierNameKey(tier)),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.heading),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x1A0F6E5C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      S.t(context, 'tier_current_badge'),
                      style: const TextStyle(fontSize: 11, color: AppColors.primary),
                    ),
                  ),
                ],
                const Spacer(),
                if (price != null)
                  Text(
                    '$price${S.t(context, 'per_year')}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final (label, included) in _features(context))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      included ? Icons.check_circle : Icons.remove_circle_outline,
                      size: 17,
                      color: included ? AppColors.primary : AppColors.mutedText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          color: included ? AppColors.bodyText : AppColors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (onBuy != null || busy) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : onBuy,
                  child: busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('${S.t(context, 'upgrade_now')} — ${S.t(context, tierNameKey(tier))}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
