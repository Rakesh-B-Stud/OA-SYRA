import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/oasyra_button.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 1) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      }
    });
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isChecking = true);
    final verified = await ref.read(authProvider.notifier).checkEmailVerified();
    if (mounted) {
      setState(() => _isChecking = false);
      if (verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully! Welcome to OASYRA.'),
            backgroundColor: OasyraColors.success,
          ),
        );
        context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification pending. Please check your inbox and click the verification link.'),
            backgroundColor: OasyraColors.warning,
          ),
        );
      }
    }
  }

  Future<void> _resendVerification() async {
    if (_resendCooldown > 0) return;
    setState(() => _isResending = true);
    await ref.read(authProvider.notifier).sendEmailVerification();
    if (mounted) {
      setState(() => _isResending = false);
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification link has been sent to your email.'),
          backgroundColor: OasyraColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final email = authState.email ?? 'your registered email';

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: OasyraColors.primarySoft,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: OasyraColors.primary,
                    size: 44,
                  ),
                ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
                
                const SizedBox(height: 36),
                
                Text(
                  'Verify Your Email',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: OasyraColors.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'We sent a verification link to:\n$email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: OasyraColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: OasyraColors.primaryLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: OasyraColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: OasyraColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please click the link in your email inbox to verify your account, then tap below.',
                          style: TextStyle(fontSize: 13, color: OasyraColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                OasyraButton(
                  text: "I've Verified My Email",
                  isLoading: _isChecking,
                  onPressed: _checkVerificationStatus,
                ),
                
                const SizedBox(height: 16),
                
                OutlinedButton(
                  onPressed: (_resendCooldown > 0 || _isResending) ? null : _resendVerification,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: OasyraColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _resendCooldown > 0
                        ? 'Resend Email in ${_resendCooldown}s'
                        : _isResending
                            ? 'Resending...'
                            : 'Resend Verification Email',
                    style: const TextStyle(
                      color: OasyraColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                TextButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text(
                    'Change Email / Log Out',
                    style: TextStyle(
                      color: OasyraColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
