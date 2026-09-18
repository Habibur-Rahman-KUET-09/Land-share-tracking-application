import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../utils/password_policy.dart';
import '../../widgets/kistify_app_bar.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authProvider = context.read<AppAuthProvider>();
      await authProvider.authService.registerWithEmail(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // The auth-state listener may have run (and skipped itself, since
      // registerWithEmail above was still bootstrapping) before this
      // profile write landed — pull the now-correct profile in explicitly
      // rather than rely on another auth-state event that may not come.
      await authProvider.refreshProfile();
      // This screen was pushed on top of LoginScreen, which is itself just
      // AuthGate's *content* while signed out — not a separate route. Once
      // sign-up flips firebaseUser non-null, AuthGate rebuilds to show
      // GroupListScreen underneath, but this pushed route still covers it;
      // nothing pops it automatically, so the user was stuck looking at a
      // stale register form after a successful sign-up. Pop back to the
      // root route so AuthGate's now-current content is what's visible.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KistifyAppBar(title: S.t(context, 'register')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: S.t(context, 'name'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Form(
              key: _emailFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    decoration:
                        InputDecoration(labelText: S.t(context, 'email'), border: const OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty) ? S.t(context, 'required_field') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: S.t(context, 'password'),
                      helperText: S.t(context, 'password_rule_hint'),
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) {
                      final problem = PasswordPolicy.problemKey(v);
                      return problem == null ? null : S.t(context, problem);
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _registerWithEmail,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(S.t(context, 'register')),
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
