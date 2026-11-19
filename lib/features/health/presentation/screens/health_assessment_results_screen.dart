import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/oasyra_button.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../providers/health_providers.dart';

class HealthAssessmentResultsScreen extends ConsumerWidget {
  const HealthAssessmentResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurements = ref.watch(healthMetricsProvider);
    final latestMeasurement = measurements.isNotEmpty ? measurements.last : null;

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'Assessment Results',
            subtitle: 'Your assessment insights',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PremiumSectionHeader(
                    title: 'Summary',
                    subtitle: 'Assessment completed successfully.',
                  ),
                  const SizedBox(height: 32),

                  if (latestMeasurement != null)
                    _buildResultCard(
                      context,
                      title: 'BMI SCREENING INDICATOR',
                      value: latestMeasurement.bmi.toStringAsFixed(1),
                      category: latestMeasurement.bmiCategory,
                    ),
                  
                  const SizedBox(height: 24),
                  
                  _buildSafetyNote(context),

                  const SizedBox(height: 32),
                  const PremiumSectionHeader(title: 'What\'s next?'),
                  const SizedBox(height: 16),
                  OasyraCard(
                    child: Column(
                      children: [
                        _buildStep(context, 'Monitor trends weekly'),
                        const Divider(height: 32),
                        _buildStep(context, 'Discuss with your doctor'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),
                  OasyraButton(
                    text: 'Return to Dashboard',
                    onPressed: () => context.go('/dashboard'),
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

  Widget _buildResultCard(BuildContext context, {
    required String title,
    required String value,
    required String category,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OasyraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 48,
                ),
              ),
              const SizedBox(width: 20),
              PremiumHealthBadge(label: category.toUpperCase(), color: OasyraColors.primary),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildSafetyNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: OasyraColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OasyraColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: OasyraColors.primary, size: 20),
              SizedBox(width: 10),
              Text('Screening Note', style: TextStyle(fontWeight: FontWeight.w600, color: OasyraColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your responses indicate factors relevant to metabolic health. This is an informational screening and not a diagnosis.',
            style: TextStyle(color: OasyraColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline_rounded, color: OasyraColors.primary, size: 20),
        const SizedBox(width: 16),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
