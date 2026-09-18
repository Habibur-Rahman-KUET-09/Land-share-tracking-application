import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/contribution.dart';
import '../../models/group_member.dart';
import '../../models/land_group.dart';
import '../../models/lottery_draw.dart';
import '../../services/contribution_service.dart';
import '../../services/group_service.dart';
import '../../services/lottery_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/member_name.dart';

/// The সমিতি/ROSCA tab of a [GroupType.lottery] group: this month's pot, who
/// is still in the running, and every past month's result.
///
/// The three streams are nested rather than combined because each one feeds
/// the next: members decide who's eligible, contributions decide the pot, and
/// past draws remove members from both.
class LotteryScreen extends StatelessWidget {
  final LandGroup group;
  final bool canDraw;
  final String currentUid;
  const LotteryScreen({
    super.key,
    required this.group,
    required this.canDraw,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupMember>>(
      stream: GroupService().watchMembers(group.id),
      builder: (context, memberSnap) {
        if (!memberSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = memberSnap.data!;
        return StreamBuilder<List<LotteryDraw>>(
          stream: LotteryService().watch(group.id),
          builder: (context, drawSnap) {
            final draws = drawSnap.data ?? const <LotteryDraw>[];
            // Only this month's entries: the pot is this month's collection,
            // so streaming the group's entire history to add up one month of
            // it was paying for every read twice over.
            final now = DateTime.now();
            return StreamBuilder<List<Contribution>>(
              stream: ContributionService().watchMonth(group.id, now.month, now.year),
              builder: (context, contribSnap) {
                final approved = (contribSnap.data ?? const <Contribution>[])
                    .where((c) => c.status == ContributionStatus.approved)
                    .toList();
                return _LotteryBody(
                  group: group,
                  canDraw: canDraw,
                  currentUid: currentUid,
                  members: members,
                  draws: draws,
                  approved: approved,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LotteryBody extends StatelessWidget {
  final LandGroup group;
  final bool canDraw;
  final String currentUid;
  final List<GroupMember> members;
  final List<LotteryDraw> draws;
  final List<Contribution> approved;

  const _LotteryBody({
    required this.group,
    required this.canDraw,
    required this.currentUid,
    required this.members,
    required this.draws,
    required this.approved,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final pot = LotteryService.potFor(approved, now.month, now.year);
    final eligible = LotteryService.eligibleMembers(members, draws);
    final thisMonth = LotteryService.drawFor(draws, now.month, now.year);
    final cycleDone = LotteryService.isCycleComplete(members, draws);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PotCard(month: now.month, year: now.year, amount: pot),
          const SizedBox(height: 12),
          if (thisMonth != null)
            _WinnerCard(draw: thisMonth, caption: S.t(context, 'already_drawn_this_month'))
          else if (cycleDone)
            _NoticeCard(icon: Icons.emoji_events_outlined, message: S.t(context, 'cycle_complete'))
          else ...[
            _EligibleCard(eligible: eligible),
            if (canDraw) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: eligible.isEmpty
                      ? null
                      : () => showDialog(
                            context: context,
                            builder: (_) => _DrawDialog(
                              group: group,
                              month: now.month,
                              year: now.year,
                              pot: pot,
                              eligible: eligible,
                              drawnBy: currentUid,
                            ),
                          ),
                  icon: const Icon(Icons.casino_outlined),
                  label: Text(S.t(context, 'draw_now')),
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          Text(S.t(context, 'lottery_history'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (draws.isEmpty)
            EmptyState(icon: Icons.history, message: S.t(context, 'no_draws_yet'))
          else
            for (final d in draws) _DrawTile(draw: d),
        ],
      ),
    );
  }
}

class _PotCard extends StatelessWidget {
  final int month;
  final int year;
  final double amount;
  const _PotCard({required this.month, required this.year, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Color(0x1A0F6E5C), shape: BoxShape.circle),
                  child: const Icon(Icons.savings_outlined, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.t(context, 'this_month_pot')),
                    Text('$month/$year', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ],
            ),
            Text(
              CurrencyFormatter.format(amount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _EligibleCard extends StatelessWidget {
  final List<GroupMember> eligible;
  const _EligibleCard({required this.eligible});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${S.t(context, 'eligible_members')} (${eligible.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in eligible)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: MemberName(uid: m.uid, style: const TextStyle(fontSize: 12.5)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _NoticeCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(message, style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  final LotteryDraw draw;
  final String caption;
  const _WinnerCard({required this.draw, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caption, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.approvedBg,
                  foregroundColor: AppColors.approvedFg,
                  child: Icon(Icons.emoji_events_outlined, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.t(context, 'winner'), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      MemberName(uid: draw.winnerUid, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(draw.collectedAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawTile extends StatelessWidget {
  final LotteryDraw draw;
  const _DrawTile({required this.draw});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = AppColors.accentFor(draw.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bg,
          foregroundColor: fg,
          child: const Icon(Icons.emoji_events_outlined, size: 18),
        ),
        title: MemberName(uid: draw.winnerUid, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${draw.month}/${draw.year} • '
          '${S.t(context, draw.wasRandom ? 'app_drawn' : 'manually_recorded')}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: Text(
          CurrencyFormatter.format(draw.collectedAmount),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Both draw methods the group asked for: the app picks at random, or an
/// admin records the winner of a draw that happened in the room.
class _DrawDialog extends StatefulWidget {
  final LandGroup group;
  final int month;
  final int year;
  final double pot;
  final List<GroupMember> eligible;
  final String drawnBy;

  const _DrawDialog({
    required this.group,
    required this.month,
    required this.year,
    required this.pot,
    required this.eligible,
    required this.drawnBy,
  });

  @override
  State<_DrawDialog> createState() => _DrawDialogState();
}

class _DrawDialogState extends State<_DrawDialog> {
  bool _random = true;
  String? _winnerUid;
  bool _saving = false;
  String? _error;

  Future<void> _run() async {
    if (!_random && _winnerUid == null) {
      setState(() => _error = S.t(context, 'required_field'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await LotteryService().recordDraw(
        groupId: widget.group.id,
        month: widget.month,
        year: widget.year,
        eligible: widget.eligible,
        collectedAmount: widget.pot,
        drawnBy: widget.drawnBy,
        winnerUid: _random ? null : _winnerUid,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.t(context, 'draw_now')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.month}/${widget.year} — ${CurrencyFormatter.format(widget.pot)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(S.t(context, 'random_draw'))),
                ButtonSegment(value: false, label: Text(S.t(context, 'manual_draw'))),
              ],
              selected: {_random},
              onSelectionChanged: (s) => setState(() => _random = s.first),
            ),
            if (!_random) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _winnerUid,
                isExpanded: true,
                decoration: InputDecoration(labelText: S.t(context, 'winner')),
                items: [
                  for (final m in widget.eligible)
                    DropdownMenuItem(value: m.uid, child: MemberName(uid: m.uid)),
                ],
                onChanged: (v) => setState(() => _winnerUid = v),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(S.t(context, 'cancel'))),
        FilledButton(
          onPressed: _saving ? null : _run,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(S.t(context, 'draw_now')),
        ),
      ],
    );
  }
}
