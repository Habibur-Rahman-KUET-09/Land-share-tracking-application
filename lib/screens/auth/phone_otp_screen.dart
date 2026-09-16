import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/auth_provider.dart';

enum PhoneAuthMode { login, register }

/// FR 2.1 phone-based auth: send OTP -> confirm code. Used both standalone
/// (register flow, name collected first) and embedded as a login tab.
class PhoneOtpScreen extends StatefulWidget {
  final PhoneAuthMode mode;
  final String? name; // required when mode == register
  const PhoneOtpScreen({super.key, required this.mode, this.name});

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String? _verificationId;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = S.t(context, 'required_field'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AppAuthProvider>().authService;
    try {
      await auth.startPhoneVerification(
        phoneNumber: phone,
        onCodeSent: (id) {
          if (!mounted) return;
          setState(() {
            _verificationId = id;
            _loading = false;
          });
        },
        onAutoVerified: (_) {
          // Android may skip typing entirely: startPhoneVerification already
          // signed the user in internally, so AppAuthProvider's authStateChanges
          // listener fires and swaps this whole screen out for GroupListScreen
          // (it also creates the users/{uid} profile document, same as confirmOtp).
        },
        onFailed: (e) {
          if (!mounted) return;
          setState(() {
            _error = e.message ?? e.code;
            _loading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _confirmOtp() async {
    if (_verificationId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AppAuthProvider>().authService;
    try {
      await auth.confirmPhoneCode(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
        nameIfNewUser: widget.name,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _phoneCtrl,
            enabled: _verificationId == null,
            decoration: InputDecoration(
              labelText: S.t(context, 'phone'),
              hintText: '+8801XXXXXXXXX',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          if (_verificationId != null) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _otpCtrl,
              decoration: InputDecoration(labelText: S.t(context, 'otp_code'), border: const OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : (_verificationId == null ? _sendOtp : _confirmOtp),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(S.t(context, _verificationId == null ? 'send_otp' : 'verify_otp')),
          ),
        ],
      ),
    );
  }
}
