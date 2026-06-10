import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';

/// Phone OTP login. Truecaller One-Tap is a later enhancement (hook left below).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String? _verificationId;
  bool _sending = false;
  bool _verifying = false;
  String? _error;

  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  String get _e164 {
    final raw = _phoneCtrl.text.trim();
    return raw.startsWith('+') ? raw : '+91$raw';
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _e164,
        verificationCompleted: (cred) async {
          await FirebaseAuth.instance.signInWithCredential(cred);
        },
        verificationFailed: (e) =>
            setState(() => _error = e.message ?? 'Verification failed'),
        codeSent: (id, _) {
          setState(() => _verificationId = id);
          _startResendCountdown();
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      // Router redirects onward once auth state updates.
    } catch (e) {
      setState(() => _error = 'Invalid code. Try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpStage = _verificationId != null;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(Icons.dashboard_customize, color: AppTheme.teal, size: 56),
              const SizedBox(height: 16),
              const Text('The Wall',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Honest, structured feedback — on your terms.',
                style: TextStyle(color: AppTheme.slate300, fontSize: 16),
              ),
              const SizedBox(height: 40),
              if (!otpStage) ...[
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    prefixText: '+91  ',
                    hintText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _sending ? null : _sendOtp,
                  child: _sending
                      ? const _Spin()
                      : const Text('Send OTP'),
                ),
              ] else ...[
                Text('Enter the code sent to $_e164',
                    style: const TextStyle(color: AppTheme.slate300)),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '6-digit code',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _verifying ? null : _verifyOtp,
                  child: _verifying ? const _Spin() : const Text('Verify & continue'),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _verificationId = null),
                      child: const Text('Change number'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: (_resendIn > 0 || _sending) ? null : _sendOtp,
                      child: Text(_resendIn > 0
                          ? 'Resend in ${_resendIn}s'
                          : 'Resend code'),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.rose)),
              ],
              const Spacer(),
              const Text(
                'By continuing you confirm you are 18+ and agree to our '
                'consent terms on the next screen.',
                style: TextStyle(color: AppTheme.slate500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Spin extends StatelessWidget {
  const _Spin();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.slate900),
      );
}
