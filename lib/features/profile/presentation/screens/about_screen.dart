import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/premium_components.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'About OASYRA',
            subtitle: 'Application Information',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: OasyraColors.primarySoft,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.spa_rounded,
                            color: OasyraColors.primary,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'OASYRA',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: OasyraColors.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your Personal Health and Nutrition Companion',
                          style: TextStyle(color: OasyraColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Version 1.0.0 (Build 1)',
                          style: TextStyle(color: OasyraColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms),

                  const SizedBox(height: 32),

                  const PremiumSectionHeader(
                    title: 'Overview',
                    subtitle: 'Smart Wellness & Nutrition Management',
                  ),
                  const SizedBox(height: 12),
                  OasyraCard(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'OASYRA brings health insights, nutrition tracking, lifestyle monitoring, and AI-assisted guidance together in one application to empower your daily wellness journey.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: OasyraColors.textSecondary,
                      ),
                    ),
                  ).animate().fadeIn(duration: 600.ms),

                  const SizedBox(height: 24),

                  const PremiumSectionHeader(
                    title: 'Key Capabilities',
                    subtitle: 'Integrated Healthcare & Wellness Features',
                  ),
                  const SizedBox(height: 12),
                  OasyraCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildFeatureRow(Icons.restaurant_rounded, 'Smart Meal Logging', 'Track daily macronutrients and calories'),
                        const Divider(height: 20, color: OasyraColors.border),
                        _buildFeatureRow(Icons.camera_alt_outlined, 'AI Food Recognition', 'Instant food detection and portion estimates'),
                        const Divider(height: 20, color: OasyraColors.border),
                        _buildFeatureRow(Icons.monitor_heart_outlined, 'Metabolic Tracking', 'BMI, BMR, and body composition analytics'),
                        const Divider(height: 20, color: OasyraColors.border),
                        _buildFeatureRow(Icons.smart_toy_outlined, 'Virtual AI Dietitian', 'Interactive personalized health guidance'),
                      ],
                    ),
                  ).animate().fadeIn(duration: 700.ms),

                  const SizedBox(height: 24),

                  OasyraCard(
                    padding: const EdgeInsets.all(16),
                    color: OasyraColors.primarySoft.withValues(alpha: 0.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: OasyraColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Medical Disclaimer: OASYRA provides informational and lifestyle recommendations for general wellness. It does not provide medical diagnosis, treatment, or clinical advice. Always consult a qualified healthcare professional for medical decisions.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: OasyraColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 800.ms),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: OasyraColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: OasyraColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: OasyraColors.textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: OasyraColors.textTertiary)),
            ],
          ),
        ),
      ],
    );
  }
}
