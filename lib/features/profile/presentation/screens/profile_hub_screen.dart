import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../providers/report_providers.dart';

class ProfileHubScreen extends ConsumerWidget {
  const ProfileHubScreen({super.key});

  void _showLogoutConfirmation(BuildContext context) {
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
    ref.listen(reportGenerationProvider, (previous, next) {
      next.pdfBytes.when(
        data: (bytes) {
          if (bytes != null) {
            context.push('/report-preview', extra: {
              'bytes': bytes,
              'name': next.fileName ?? 'oasyra_report.pdf',
            });
            ref.read(reportGenerationProvider.notifier).reset();
          }
        },
        loading: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Generating health report...'), duration: Duration(seconds: 1)),
          );
        },
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error generating report: $e')),
          );
        },
      );
    });

    final authState = ref.watch(authProvider);
    final profile = ref.watch(healthProfileProvider);
    
    final name = profile?.name ?? authState.email?.split('@')[0] ?? 'User';

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          PremiumPageHeader(
            title: 'Account Hub',
            subtitle: 'Manage your OASYRA journey',
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () => _showLogoutConfirmation(context),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserHeader(context, name, authState.email ?? ''),
                  const SizedBox(height: 32),
                  
                  const PremiumSectionHeader(title: 'Health & Analysis'),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    context,
                    items: [
                      _MenuItem(
                        icon: Icons.person_outline_rounded,
                        title: 'Health Profile',
                        subtitle: 'Vitals, goals, and restrictions',
                        onTap: () => context.push('/health-setup'),
                      ),
                      _MenuItem(
                        icon: Icons.assignment_outlined,
                        title: 'Health Assessment',
                        subtitle: 'Lifestyle and OB-Risk screening',
                        onTap: () => context.push('/health-assessment'),
                      ),
                      _MenuItem(
                        icon: Icons.monitor_heart_outlined,
                        title: 'Synced Health Data',
                        subtitle: 'Metrics from Fitbit & Health Connect',
                        onTap: () => context.push('/health-data'),
                      ),
                      _MenuItem(
                        icon: Icons.analytics_outlined,
                        title: 'Metabolic Analysis',
                        subtitle: 'BMR, BMI, and risk factors',
                        onTap: () => context.push('/health-analysis'),
                      ),
                      _MenuItem(
                        icon: Icons.picture_as_pdf_rounded,
                        title: 'Health Report',
                        subtitle: 'Professional analysis PDF',
                        onTap: () => ref.read(reportGenerationProvider.notifier).generateReport(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  const PremiumSectionHeader(title: 'Account Settings'),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    context,
                    items: [
                      _MenuItem(
                        icon: Icons.badge_outlined,
                        title: 'Edit Display Name',
                        subtitle: 'Update how OASYRA addresses you',
                        onTap: () => context.push('/edit-name'),
                      ),
                      _MenuItem(
                        icon: Icons.security_rounded,
                        title: 'Security',
                        subtitle: 'Password & account security',
                        onTap: () => context.push('/security'),
                      ),
                      _MenuItem(
                        icon: Icons.info_outline_rounded,
                        title: 'About OASYRA',
                        subtitle: 'Version 1.0.0 • Major Project Build',
                        onTap: () => context.push('/about'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, String name, String email) {
    return OasyraCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: OasyraColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: OasyraColors.textPrimary),
                ),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: OasyraColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/edit-name'),
            icon: const Icon(Icons.edit_outlined, color: OasyraColors.primary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required List<_MenuItem> items}) {
    return OasyraCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          final item = e.value;
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OasyraColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: OasyraColors.primary, size: 20),
                ),
                title: Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(item.subtitle, style: TextStyle(fontSize: 11, color: OasyraColors.textTertiary)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: OasyraColors.border),
                onTap: item.onTap,
              ),
              if (!isLast) const Divider(height: 1, indent: 68, color: OasyraColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
