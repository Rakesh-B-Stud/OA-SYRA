import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../providers/analysis_providers.dart';
import '../../domain/models/analysis_models.dart';

class HealthAnalysisScreen extends ConsumerWidget {
  const HealthAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(healthAnalysisProvider);

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'Health Analysis',
            subtitle: 'Your personalized health insights',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverallScreening(context, analysis.overallConcern),
                  const SizedBox(height: 32),
                  
                  const PremiumSectionHeader(
                    title: 'Metabolic Estimation',
                    subtitle: 'Personalized energy expenditure targets',
                  ),
                  const SizedBox(height: 16),
                  _buildMetabolicCards(context, analysis),
                  const SizedBox(height: 32),

                  if (analysis.behavioralFactors.isNotEmpty) ...[
                    const PremiumSectionHeader(
                      title: 'Behavioral Analysis',
                      subtitle: 'Evidence-backed lifestyle drivers',
                    ),
                    const SizedBox(height: 16),
                    ...analysis.behavioralFactors.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildFactorCard(context, f),
                    )),
                    const SizedBox(height: 16),
                  ],

                  const PremiumSectionHeader(
                    title: 'Personalized Nutrition',
                    subtitle: 'Indian-cuisine meal strategy',
                  ),
                  const SizedBox(height: 16),
                  _buildNutritionPlan(context, analysis.nutritionPlan),
                  const SizedBox(height: 32),

                  const PremiumSectionHeader(
                    title: 'Health Action Plan',
                    subtitle: 'Multi-domain intervention roadmap',
                  ),
                  const SizedBox(height: 16),
                  _buildPlanList(context, analysis.personalizedPlan),
                  
                  const SizedBox(height: 48),
                  _buildSafetyNote(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallScreening(BuildContext context, ScreeningConcern concern) {
    Color color;
    String label;
    String desc;

    switch (concern) {
      case ScreeningConcern.lower:
        color = OasyraColors.success;
        label = 'LOWER SCREENING CONCERN';
        desc = 'Your indicators are currently within optimal ranges.';
        break;
      case ScreeningConcern.moderate:
        color = OasyraColors.warning;
        label = 'MODERATE SCREENING CONCERN';
        desc = 'Some patterns suggest areas for behavioral improvement.';
        break;
      case ScreeningConcern.elevated:
        color = OasyraColors.error;
        label = 'ELEVATED SCREENING CONCERN';
        desc = 'Multiple risk factors suggest prioritizing weight management.';
        break;
    }

    return OasyraCard(
      color: color.withValues(alpha: 0.05),
      border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontWeight: FontWeight.w500, color: OasyraColors.textPrimary, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildMetabolicCards(BuildContext context, HealthAnalysis analysis) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: PremiumMetricCard(
                label: 'EST. BMR',
                value: analysis.estimatedBmr?.toStringAsFixed(0) ?? '--',
                unit: 'kcal',
                icon: Icons.flash_on_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: PremiumMetricCard(
                label: 'DAILY NEEDS',
                value: analysis.estimatedDailyEnergy?.toStringAsFixed(0) ?? '--',
                unit: 'kcal',
                icon: Icons.restaurant_rounded,
                color: Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFactorCard(BuildContext context, ContributingFactor factor) {
    return OasyraCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: OasyraColors.primarySoft, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.psychology_outlined, color: OasyraColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(factor.name, style: const TextStyle(fontWeight: FontWeight.w600, color: OasyraColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Evidence', factor.evidence, Icons.search_rounded),
          const Divider(height: 24),
          _buildInfoRow('Analysis', factor.interpretation, Icons.lightbulb_outline_rounded),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OasyraColors.successLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OasyraColors.success.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: OasyraColors.success, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    factor.recommendation,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: OasyraColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: OasyraColors.textTertiary),
            const SizedBox(width: 6),
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: OasyraColors.textTertiary, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, color: OasyraColors.textSecondary, height: 1.5)),
      ],
    );
  }

  Widget _buildNutritionPlan(BuildContext context, List<MealOption> nutrition) {
    if (nutrition.isEmpty) return const Text('Complete profile to generate meal plan.');
    
    return Column(
      children: nutrition.map((meal) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OasyraCard(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: OasyraColors.accentLavender.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getMealIcon(meal.mealType), color: OasyraColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(meal.mealType, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: OasyraColors.primary, letterSpacing: 0.5)),
                        Text(meal.portion, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: OasyraColors.textTertiary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(meal.dishName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: OasyraColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(meal.description, style: TextStyle(fontSize: 12, color: OasyraColors.textSecondary, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  IconData _getMealIcon(String type) {
    switch (type) {
      case 'Breakfast': return Icons.wb_sunny_outlined;
      case 'Lunch': return Icons.lunch_dining_rounded;
      case 'Evening Snack': return Icons.bakery_dining_rounded;
      case 'Dinner': return Icons.nightlight_round_outlined;
      default: return Icons.restaurant_rounded;
    }
  }

  Widget _buildPlanList(BuildContext context, List<HealthPlanItem> plan) {
    if (plan.isEmpty) return const Text('Assessments required to build action plan.');
    
    return Column(
      children: plan.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OasyraCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _getDomainColor(item.domain).withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Icon(_getDomainIcon(item.domain), size: 16, color: _getDomainColor(item.domain)),
                    const SizedBox(width: 10),
                    Text(
                      item.domain.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _getDomainColor(item.domain), letterSpacing: 1),
                    ),
                    const Spacer(),
                    Text(item.frequency, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: OasyraColors.textTertiary)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.goal, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: OasyraColors.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: OasyraColors.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item.action, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildInfoRow('Rationale', item.rationale, Icons.help_outline_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Color _getDomainColor(String domain) {
    switch (domain) {
      case 'Nutrition': return Colors.orange;
      case 'Activity': return Colors.blue;
      case 'Behavioral': return Colors.purple;
      case 'Habit': return Colors.teal;
      case 'Monitoring': return Colors.indigo;
      default: return OasyraColors.primary;
    }
  }

  IconData _getDomainIcon(String domain) {
    switch (domain) {
      case 'Nutrition': return Icons.restaurant_rounded;
      case 'Activity': return Icons.directions_run_rounded;
      case 'Behavioral': return Icons.psychology_rounded;
      case 'Habit': return Icons.repeat_rounded;
      case 'Monitoring': return Icons.monitor_heart_rounded;
      default: return Icons.check_circle_outline_rounded;
    }
  }

  Widget _buildSafetyNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OasyraColors.errorLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OasyraColors.error.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security_rounded, color: OasyraColors.error, size: 18),
              SizedBox(width: 10),
              Text('Medical Safety Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: OasyraColors.error)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'This report provides AI-generated screening indicators and wellness suggestions. It is NOT a clinical diagnosis or medical prescription. If you have pre-existing conditions like diabetes or hypertension, please consult your physician before following this plan.',
            style: TextStyle(fontSize: 11, color: OasyraColors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}
