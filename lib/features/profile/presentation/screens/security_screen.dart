import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log Out?', style: TextStyle(fontWeight: FontWeight.w600, color: OasyraColors.textPrimary)),
        content: const Text('Are you sure you want to log out of your OASYRA account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: OasyraColors.textTertiary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/logout-splash');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OasyraColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final email = authState.email ?? 'Connected Account';

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'Security',
            subtitle: 'Account authentication & privacy',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PremiumSectionHeader(
                    title: 'Authentication Status',
                    subtitle: 'Your active account security method',
                  ),
                  const SizedBox(height: 16),
                  OasyraCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: OasyraColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.verified_user_outlined, color: OasyraColors.primary),
                          ),
                          title: const Text('Account Identity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Text(email, style: TextStyle(color: OasyraColors.textSecondary, fontSize: 13)),
                        ),
                        const Divider(height: 24, color: OasyraColors.border),
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: OasyraColors.success, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Firebase Identity Verified',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: OasyraColors.success),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  
                  const SizedBox(height: 32),
                  const PremiumSectionHeader(
                    title: 'Security Actions',
                    subtitle: 'Manage passwords and access',
                  ),
                  const SizedBox(height: 16),
                  OasyraCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: OasyraColors.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.lock_reset_rounded, color: OasyraColors.primary, size: 20),
                          ),
                          title: const Text('Reset Account Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Send recovery email & re-authenticate', style: TextStyle(fontSize: 11, color: OasyraColors.textTertiary)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: OasyraColors.border),
                          onTap: () async {
                            if (authState.email != null) {
                              try {
                                await ref.read(authProvider.notifier).sendPasswordResetEmail(authState.email!);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Password reset link sent to ${authState.email}. Please sign in with your new password.'),
                                      backgroundColor: OasyraColors.success,
                                    ),
                                  );
                                  await ref.read(authProvider.notifier).logout();
                                  if (context.mounted) context.go('/login');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e'), backgroundColor: OasyraColors.error),
                                  );
                                }
                              }
                            }
                          },
                        ),
                        const Divider(height: 1, indent: 68, color: OasyraColors.border),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: OasyraColors.errorLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.logout_rounded, color: OasyraColors.error, size: 20),
                          ),
                          title: const Text('Log Out Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: OasyraColors.error)),
                          subtitle: const Text('Sign out from this device', style: TextStyle(fontSize: 11, color: OasyraColors.textTertiary)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: OasyraColors.border),
                          onTap: () => _showLogoutConfirmation(context, ref),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
