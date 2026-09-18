import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kistify_mark.dart';
import 'register_screen.dart';

/// FR 2.1 "User registration/login (Phone number / Email based)" — phone
/// login is temporarily disabled (kept in the codebase for later); only
/// email/password and Google are shown.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _googleLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // Defence in depth against password guessing. Firebase does the real
  // rate limiting server side — it has to, since nothing stops an attacker
  // calling the API directly instead of using this screen. What this adds
  // is a hard stop in front of the casual case (someone trying passwords on
  // a borrowed phone), and it makes the slowdown visible instead of leaving
  // the user staring at a generic error after Firebase quietly throttles.
  static const _maxAttempts = 5;
  static const _lockout = Duration(minutes: 1);
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  Duration? get _remainingLockout {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  Future<void> _signInWithEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final waiting = _remainingLockout;
    if (waiting != null) {
      setState(() => _error = S.t(context, 'too_many_attempts'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AppAuthProvider>().authService;
      await auth.signInWithEmail(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      _failedAttempts = 0;
      _lockedUntil = null;
      // The exception is deliberately not inspected: every failure reports
      // the same thing, so there is nothing here to read off it.
    } on FirebaseAuthException {
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        _lockedUntil = DateTime.now().add(_lockout);
        _failedAttempts = 0;
        if (mounted) setState(() => _error = S.t(context, 'too_many_attempts'));
        return;
      }
      // Never distinguish "no such account" from "wrong password": telling
      // them apart hands an attacker a way to find out which addresses are
      // registered.
      if (mounted) setState(() => _error = S.t(context, 'sign_in_failed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = S.t(context, 'enter_email_first'));
      return;
    }
    try {
      await context.read<AppAuthProvider>().authService.sendPasswordReset(email);
    } catch (_) {
      // Swallowed on purpose — see the message below. Reporting a failure
      // here would leak whether the address exists.
    }
    if (!mounted) return;
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.t(context, 'reset_link_sent'))),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      final authProvider = context.read<AppAuthProvider>();
      await authProvider.authService.signInWithGoogle();
      // See RegisterScreen._registerWithEmail for why this explicit refresh
      // is needed even though signInWithGoogle already wrote the profile.
      await authProvider.refreshProfile();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Widget _emailForm(BuildContext context) {
    return Form(
      key: _emailFormKey,
      child: Column(
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
            decoration: InputDecoration(labelText: S.t(context, 'password'), border: const OutlineInputBorder()),
            obscureText: true,
            validator: (v) => (v == null || v.isEmpty) ? S.t(context, 'required_field') : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _signInWithEmail,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(S.t(context, 'login')),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _loading ? null : _sendPasswordReset,
            child: Text(S.t(context, 'forgot_password')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            ),
            child: Text(S.t(context, 'no_account')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _HeroHeader(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _emailForm(context),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(S.t(context, 'or')),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _googleLoading ? null : _signInWithGoogle,
                      icon: _googleLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.g_mobiledata, size: 28),
                      label: Text(S.t(context, 'sign_in_with_google')),
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

/// Colorful branded header — matches the app icon's gradient, giving the
/// login screen some visual weight instead of a plain white form on gray.
class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2CB1A3), AppColors.primary],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const KistifyMark(size: 64),
          const SizedBox(height: 14),
          Text(
            S.t(context, 'app_title'),
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(S.t(context, 'app_tagline'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}
