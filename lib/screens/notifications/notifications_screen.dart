import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/app_notification.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/kistify_app_bar.dart';
import '../group/group_detail_screen.dart';

const _typeIcons = {
  'pending_approval': Icons.hourglass_top_outlined,
  'contribution_approved': Icons.check_circle_outline,
  'contribution_rejected': Icons.cancel_outlined,
  'builder_payment': Icons.account_balance_outlined,
  'due_reminder': Icons.event_outlined,
  'builder_deadline': Icons.schedule_outlined,
  'missed_payment_alert': Icons.error_outline,
};

const _typeColors = {
  'pending_approval': (Color(0xFFFFF3E0), Color(0xFF8A5300)),
  'contribution_approved': (Color(0xFFE3F4EC), Color(0xFF1B6B44)),
  'contribution_rejected': (Color(0xFFFCEBEB), Color(0xFF791F1F)),
  'builder_payment': (Color(0xFFE0F2F1), Color(0xFF00695C)),
  'due_reminder': (Color(0xFFE3F2FD), Color(0xFF1565C0)),
  'builder_deadline': (Color(0xFFE3F2FD), Color(0xFF1565C0)),
  'missed_payment_alert': (Color(0xFFFCEBEB), Color(0xFF791F1F)),
};

/// The bell icon's destination — everything functions/index.js has ever
/// written to this user's users/{uid}/notifications inbox (entry
/// submitted/approved/rejected, builder payments, due-date reminders).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AppAuthProvider>().firebaseUser!.uid;
    final service = NotificationService();
    return Scaffold(
      appBar: KistifyAppBar(
        title: S.t(context, 'notifications'),
        actions: [
          IconButton(
            tooltip: S.t(context, 'mark_all_read'),
            icon: const Icon(Icons.done_all),
            onPressed: () => service.markAllRead(uid),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: service.watchNotifications(uid),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return EmptyState(icon: Icons.notifications_none, message: S.t(context, 'no_notifications'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              final (bg, fg) = _typeColors[n.type] ?? AppColors.accentFor(n.type);
              final icon = _typeIcons[n.type] ?? Icons.notifications_outlined;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: n.read ? null : const Color(0xFFF0F7F5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border, width: 0.6),
                ),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: bg, foregroundColor: fg, child: Icon(icon, size: 20)),
                  title: Text(
                    n.title,
                    style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold),
                  ),
                  subtitle: Text(n.body),
                  trailing: n.read ? null : const CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
                  onTap: () {
                    if (!n.read) service.markRead(uid, n.id);
                    if (n.groupId != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: n.groupId!)),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
