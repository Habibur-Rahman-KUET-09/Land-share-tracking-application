import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/auth_provider.dart';
import 'phone_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _usePhone = true;
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
      final auth = context.read<AppAuthProvider>().authService;
      await auth.registerWithEmail(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.t(context, 'register'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: S.t(context, 'name'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(S.t(context, 'phone'))),
                ButtonSegment(value: false, label: Text(S.t(context, 'email'))),
              ],
              selected: {_usePhone},
              onSelectionChanged: (s) => setState(() => _usePhone = s.first),
            ),
            const SizedBox(height: 16),
            if (_usePhone)
              PhoneOtpScreen(mode: PhoneAuthMode.register, name: _nameCtrl.text.trim())
            else
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
                      decoration:
                          InputDecoration(labelText: S.t(context, 'password'), border: const OutlineInputBorder()),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 6) ? S.t(context, 'required_field') : null,
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
