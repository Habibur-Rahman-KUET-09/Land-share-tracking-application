import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/kistify_app_bar.dart';

/// Lets the signed-in user fix their own display name — needed because a
/// name can end up wrong (e.g. the "নতুন ব্যবহারকারী" fallback from an old
/// sign-up bug) with no other way to correct it after the fact.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppAuthProvider>().profile;
    _nameCtrl = TextEditingController(text: profile?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final authProvider = context.read<AppAuthProvider>();
      await authProvider.authService.updateProfile(
        uid: authProvider.firebaseUser!.uid,
        name: _nameCtrl.text.trim(),
      );
      await authProvider.refreshProfile();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppAuthProvider>().profile;
    return Scaffold(
      appBar: KistifyAppBar(title: S.t(context, 'my_profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: S.t(context, 'name'), border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? S.t(context, 'required_field') : null,
            ),
            if (profile?.email != null) ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: profile!.email,
                enabled: false,
                decoration: InputDecoration(labelText: S.t(context, 'email'), border: const OutlineInputBorder()),
              ),
            ],
            if (profile?.phone != null) ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: profile!.phone,
                enabled: false,
                decoration: InputDecoration(labelText: S.t(context, 'phone'), border: const OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(S.t(context, 'save')),
            ),
          ],
        ),
      ),
    );
  }
}
