import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/password_policy.dart';
import '../../widgets/kistify_app_bar.dart';
import '../help/help_screen.dart';

/// Everything about *you* rather than about a group: who you're signed in
/// as, your password, the app's language, the help pages, and the way out.
///
/// These used to be loose icons in the group-list app bar; collecting them
/// here leaves room for a password entry that only some accounts can use.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final profile = auth.profile;
    final hasPassword = AuthService().hasPasswordSignIn;

    return Scaffold(
      appBar: KistifyAppBar(title: S.t(context, 'account')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A0F6E5C),
                foregroundColor: AppColors.primary,
                child: Icon(Icons.person_outline),
              ),
              title: Text(profile?.name ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(profile?.email ?? auth.firebaseUser?.email ?? ''),
            ),
          ),
          const SizedBox(height: 12),

          // Only email/password accounts get this. A Google account has no
          // Firebase password to change — its credentials live with Google,
          // and showing the form anyway would be a dead end.
          if (hasPassword)
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A0F6E5C),
                  foregroundColor: AppColors.primary,
                  child: Icon(Icons.lock_outline),
                ),
                title: Text(S.t(context, 'change_password')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const _ChangePasswordDialog(),
                ),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1AE5B347),
                  foregroundColor: Color(0xFF8A6100),
                  child: Icon(Icons.g_mobiledata),
                ),
                title: Text(S.t(context, 'google_account')),
                subtitle: Text(
                  S.t(context, 'google_account_desc'),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),

          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A0F6E5C),
                foregroundColor: AppColors.primary,
                child: Icon(Icons.translate),
              ),
              title: Text(S.t(context, 'language')),
              subtitle: Text(context.watch<LocaleProvider>().isBangla ? 'বাংলা' : 'English'),
              trailing: const Icon(Icons.swap_horiz),
              onTap: () => context.read<LocaleProvider>().toggle(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A0F6E5C),
                foregroundColor: AppColors.primary,
                child: Icon(Icons.help_outline),
              ),
              title: Text(S.t(context, 'how_it_works')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text(
                S.t(context, 'logout'),
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.read<AppAuthProvider>().signOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService().changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t(context, 'password_changed'))),
      );
    } catch (e) {
      // Firebase reports a wrong current password as a credential error;
      // saying so plainly beats echoing an SDK error code at the user.
      final message = '$e'.contains('invalid-credential') || '$e'.contains('wrong-password')
          ? S.t(context, 'current_password_wrong')
          : '$e';
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.t(context, 'change_password')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: S.t(context, 'current_password'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? S.t(context, 'required_field') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: S.t(context, 'new_password'),
                  helperText: S.t(context, 'password_rule_hint'),
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final problem = PasswordPolicy.problemKey(v);
                  return problem == null ? null : S.t(context, problem);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: S.t(context, 'confirm_password'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v != _newCtrl.text ? S.t(context, 'passwords_do_not_match') : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(S.t(context, 'cancel'))),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(S.t(context, 'save')),
        ),
      ],
    );
  }
}
