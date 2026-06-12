import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../shared/wall_ui.dart';

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
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              const Spacer(),
              const BrickMark(size: 64),
              const SizedBox(height: 24),
              Text('The Wall', style: AppTheme.display(size: 38))
                  .animate()
                  .fadeIn(delay: 350.ms, duration: WallMotion.slow)
                  .slideY(begin: 0.15, end: 0, delay: 350.ms),
              const SizedBox(height: 8),
              Text(
                'Honest feedback, brick by brick —\non your terms.',
                style: AppTheme.body(
                    size: 16.5, color: AppTheme.ink300, height: 1.45),
              )
                  .animate()
                  .fadeIn(delay: 480.ms, duration: WallMotion.slow)
                  .slideY(begin: 0.15, end: 0, delay: 480.ms),
              const SizedBox(height: 44),
              AnimatedSwitcher(
                duration: WallMotion.med,
                switchInCurve: WallMotion.ease,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: otpStage ? _otpStage() : _phoneStage(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.rose, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!,
                          style: AppTheme.body(
                              size: 13, color: AppTheme.rose)),
                    ),
                  ],
                ).animate().shake(hz: 4, offset: const Offset(2, 0)),
              ],
              const Spacer(),
              Text(
                'By continuing you confirm you are 18+ and agree to our consent terms on the next screen.',
                style: AppTheme.body(
                    size: 12, color: AppTheme.ink400, height: 1.5),
              ).animate().fadeIn(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneStage() => Column(
        key: const ValueKey('phone'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: AppTheme.body(size: 16, color: AppTheme.paper),
            decoration: const InputDecoration(
              prefixText: '+91  ',
              hintText: 'Mobile number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _sending ? null : _sendOtp,
            child: _sending ? const _Spin() : const Text('Send OTP'),
          ),
        ],
      );

  Widget _otpStage() => Column(
        key: const ValueKey('otp'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter the code sent to $_e164',
              style: AppTheme.body(size: 14, color: AppTheme.ink300)),
          const SizedBox(height: 16),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: AppTheme.display(size: 22, letterSpacing: 6),
            decoration: const InputDecoration(
              hintText: '••••••',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _verifying ? null : _verifyOtp,
            child:
                _verifying ? const _Spin() : const Text('Verify & continue'),
          ),
          const SizedBox(height: 4),
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
      );
}

class _Spin extends StatelessWidget {
  const _Spin();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppTheme.ink950),
      );
}
