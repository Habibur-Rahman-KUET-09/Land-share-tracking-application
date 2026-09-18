import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/monetization.dart';
import '../../l10n/app_strings.dart';
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
              child: Text(S.t(context, 'upgrade_now')),
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

/// The paid-tier screen: what the group has now, what Pro adds, and a
/// purchase button that is honest about the store not being there yet.
class UpgradeScreen extends StatefulWidget {
  final LandGroup group;
  const UpgradeScreen({super.key, required this.group});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _loading = true;
  bool _buying = false;
  bool _storeAvailable = false;
  BillingProduct? _product;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final billing = BillingService.instance;
    final available = await billing.isAvailable();
    final product = available ? await billing.loadProProduct() : null;
    if (!mounted) return;
    setState(() {
      _storeAvailable = available;
      _product = product;
      _loading = false;
    });
  }

  Future<void> _buy() async {
    setState(() => _buying = true);
    final result = await BillingService.instance.purchasePro(widget.group.id);
    if (!mounted) return;
    setState(() => _buying = false);
    final message = switch (result.outcome) {
      // The tier lands on the group doc from the server, so there is
      // nothing to write here — the group stream repaints on its own.
      BillingOutcome.purchased => null,
      BillingOutcome.cancelled => null,
      BillingOutcome.pending => S.t(context, 'upgrade_unavailable'),
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
      queryParameters: {'subject': 'Kistify Pro — ${widget.group.name}'},
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isPro = widget.group.isPro;
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
                child: Icon(isPro ? Icons.workspace_premium : Icons.groups_outlined),
              ),
              title: Text(S.t(context, 'current_tier')),
              subtitle: Text(
                isPro
                    ? (expiry == null
                        ? S.t(context, 'pro_active_forever')
                        : '${S.t(context, 'pro_active_until')} '
                            '${expiry.day}/${expiry.month}/${expiry.year}')
                    : '${S.t(context, 'tier_free')} — ${widget.group.name}',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _TierCard(
            title: S.t(context, 'tier_free'),
            description: S.t(context, 'tier_free_desc'),
            highlighted: !isPro,
            features: [
              (S.t(context, 'feature_core'), true),
              (S.t(context, 'feature_groups_free'), true),
              (S.t(context, 'feature_members_free'), true),
              (S.t(context, 'feature_export'), false),
              (S.t(context, 'feature_import'), false),
            ],
          ),
          const SizedBox(height: 12),
          _TierCard(
            title: S.t(context, 'tier_pro'),
            description: S.t(context, 'tier_pro_desc'),
            highlighted: isPro,
            // The store's own localized price wins; the constant is only a
            // fallback for when no product could be loaded.
            price: _product?.price ?? '৳${Monetization.proYearlyPriceBdt}',
            features: [
              (S.t(context, 'feature_core'), true),
              (S.t(context, 'feature_groups_pro'), true),
              (S.t(context, 'feature_members_pro'), true),
              (S.t(context, 'feature_export'), true),
              (S.t(context, 'feature_import'), true),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              S.t(context, 'tier_price_note'),
              style: const TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.mutedText),
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (isPro)
            const SizedBox.shrink()
          else ...[
            FilledButton.icon(
              onPressed: _storeAvailable && !_buying ? _buy : null,
              icon: _buying
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.workspace_premium_outlined),
              label: Text(
                _product == null
                    ? S.t(context, 'upgrade_now')
                    : '${S.t(context, 'upgrade_now')} — ${_product!.price}${S.t(context, 'per_year')}',
              ),
            ),
            if (!_storeAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  S.t(context, 'upgrade_unavailable'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.mutedText),
                ),
              ),
            if (_storeAvailable)
              TextButton(
                onPressed: BillingService.instance.restorePurchases,
                child: Text(S.t(context, 'restore_purchases')),
              ),
          ],
          const SizedBox(height: 16),
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

class _TierCard extends StatelessWidget {
  final String title;
  final String description;
  final String? price;
  final bool highlighted;

  /// (label, included) — a tier lists everything, so the difference between
  /// the two cards is visible without putting them side by side on a phone.
  final List<(String, bool)> features;

  const _TierCard({
    required this.title,
    required this.description,
    required this.features,
    this.price,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: highlighted ? AppColors.primary : AppColors.border,
          width: highlighted ? 1.4 : 0.6,
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
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.heading),
                ),
                const Spacer(),
                if (price != null)
                  Text(
                    '$price${S.t(context, 'per_year')}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.bodyText)),
            const SizedBox(height: 12),
            for (final (label, included) in features)
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
          ],
        ),
      ),
    );
  }
}
