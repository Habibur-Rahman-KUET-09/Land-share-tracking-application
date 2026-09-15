import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/auth_provider.dart';
import 'phone_otp_screen.dart';
import 'register_screen.dart';

/// FR 2.1 "User registration/login (Phone number / Email based)" — both
/// methods are first-class, switchable via the tabs below.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _emailFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AppAuthProvider>().authService;
      await auth.signInWithEmail(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.t(context, 'app_title')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: S.t(context, 'sign_in_with_phone')),
            Tab(text: S.t(context, 'sign_in_with_email')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const PhoneOtpScreen(mode: PhoneAuthMode.login),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _emailFormKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(labelText: S.t(context, 'email'), border: const OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty) ? S.t(context, 'required_field') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration:
                        InputDecoration(labelText: S.t(context, 'password'), border: const OutlineInputBorder()),
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty) ? S.t(context, 'required_field') : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _signInWithEmail,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(S.t(context, 'login')),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: Text(S.t(context, 'no_account')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
