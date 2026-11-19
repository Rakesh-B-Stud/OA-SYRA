import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../health/domain/models/health_models.dart';
import '../../../health/presentation/providers/health_data_providers.dart';
import '../../../../features/profile/presentation/providers/report_providers.dart';
import '../../../../features/analysis/presentation/providers/analysis_providers.dart';
import '../../../../features/analysis/domain/models/analysis_models.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../../../../core/config/ai_config.dart';
import '../../../chatbot/presentation/providers/chatbot_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

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
            const SnackBar(content: Text('Generating report...'), duration: Duration(seconds: 1)),
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
    final measurements = ref.watch(healthMetricsProvider);
    final assessment = ref.watch(healthAssessmentProvider);
    final analysis = ref.watch(healthAnalysisProvider);
    final healthDataState = ref.watch(healthDataProvider);

    final name = profile?.name ?? authState.email?.split('@')[0] ?? 'User';
    final greeting = getGreeting(DateTime.now());

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          PremiumPageHeader(
            title: '$greeting, $name',
            subtitle: 'Your health overview',
            actions: [
              IconButton(
                onPressed: () => context.push('/profile-hub'),
                icon: const Icon(Icons.account_circle_outlined, color: Colors.white, size: 24),
              ),
              IconButton(
                onPressed: () => _showLogoutConfirmation(context, ref),
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {},
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // const Text(
                    //   "BUILD_AUG28_V4",
                    //   style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                    // ),
                    const SizedBox(height: 8),
                    if (profile == null)
                      _buildProfileSetupCard(context)
                    else ...[
                      _buildHealthDataSummary(context, healthDataState),
                      const SizedBox(height: 32),
                      _buildHealthInsightCard(context, analysis),
                      const SizedBox(height: 32),
                      _buildBmiSummaryCard(context, profile),
                      const SizedBox(height: 32),
                      const PremiumSectionHeader(
                        title: 'BMI Trend', 
                        subtitle: 'Your progress journey',
                      ),
                      const SizedBox(height: 16),
                      _buildBmiChartCard(context, measurements),
                      const SizedBox(height: 32),
                      const PremiumSectionHeader(title: 'Health Status'),
                      const SizedBox(height: 16),
                      _buildAssessmentStatusCard(context, assessment),
                      const SizedBox(height: 32),
                      const PremiumSectionHeader(title: 'Quick Actions'),
                      const SizedBox(height: 16),
                      _buildQuickActionList(context, ref),
                      const SizedBox(height: 16),
                      _buildQuickActionGrid(context, ref),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSetupCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: OasyraColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: OasyraColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 24),
          const Text(
            'Complete Your Profile',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'Unlock personalized insights by completing your physical health data.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.push('/health-setup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: OasyraColors.primary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Start Setup'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildHealthInsightCard(BuildContext context, HealthAnalysis analysis) {
    return OasyraCard(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OasyraColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_outlined, color: OasyraColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Health Insight',
                style: TextStyle(fontWeight: FontWeight.w600, color: OasyraColors.textPrimary),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/health-analysis'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Details →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            analysis.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: OasyraColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildHealthDataSummary(BuildContext context, HealthDataState state) {
    final isConnected = state.status == HealthSyncStatus.connected || state.status == HealthSyncStatus.syncing;
    final summary = state.summary;

    return OasyraCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              const Text('Today\'s Activity', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (isConnected)
                TextButton(
                  onPressed: () => context.push('/health-data'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('View All →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (isConnected && summary != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActivityItem(Icons.directions_walk_rounded, '${summary.todaySteps}', 'steps'),
                _buildActivityItem(Icons.local_fire_department_rounded, '${summary.todayActiveCalories.toInt()}', 'kcal'),
                _buildActivityItem(Icons.timer_outlined, '${summary.todayActiveMinutes}', 'min'),
              ],
            )
          else if (state.status == HealthSyncStatus.connecting || state.status == HealthSyncStatus.syncing)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(),
            ))
          else
            Center(
              child: TextButton.icon(
                onPressed: () => context.push('/health-data'),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Connect Health Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String value, String unit) {
    return Column(
      children: [
        Icon(icon, color: OasyraColors.primary, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(unit, style: const TextStyle(fontSize: 10, color: OasyraColors.textTertiary)),
      ],
    );
  }

  Widget _buildBmiSummaryCard(BuildContext context, HealthProfile profile) {
    return OasyraCard(
      color: OasyraColors.primarySoft,
      border: Border.all(color: OasyraColors.primary.withValues(alpha: 0.1), width: 1.5),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current BMI', style: TextStyle(color: OasyraColors.textSecondary, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(
                    profile.bmi.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w500, color: OasyraColors.primary),
                  ),
                ],
              ),
              PremiumHealthBadge(
                label: profile.bmiCategory.toUpperCase(),
                color: _getBmiColor(profile.bmiCategory),
              ),
            ],
          ),
          const Divider(height: 48, color: OasyraColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric(context, 'Weight', '${profile.currentWeightKg}', 'kg'),
              _buildMetric(context, 'Height', '${profile.heightCm}', 'cm'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildMetric(BuildContext context, String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: OasyraColors.textTertiary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: OasyraColors.textPrimary)),
            const SizedBox(width: 2),
            Text(unit, style: const TextStyle(fontSize: 12, color: OasyraColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildAssessmentStatusCard(BuildContext context, dynamic assessment) {
    final completed = assessment != null;
    final statusColor = completed ? OasyraColors.success : OasyraColors.warning;
    final bgColor = completed ? OasyraColors.successLight : OasyraColors.warningLight;

    return OasyraCard(
      padding: EdgeInsets.zero, // Remove padding from card to avoid inner overflow
      color: bgColor,
      border: Border.all(color: statusColor.withValues(alpha: 0.1), width: 1.5),
      child: InkWell(
        onTap: () => context.push(completed ? '/health-results' : '/health-assessment'),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(
                  completed ? Icons.check_circle_rounded : Icons.pending_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Ensure minimal vertical space
                  children: [
                    Text(
                      completed ? 'Health Secure' : 'Assessment Pending', 
                      style: const TextStyle(fontWeight: FontWeight.w600, color: OasyraColors.textPrimary),
                    ),
                    Text(
                      completed ? 'Your latest screening is active' : 'Lifestyle screening pending',
                      style: const TextStyle(fontSize: 12, color: OasyraColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: statusColor),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms);
  }

  Widget _buildBmiChartCard(BuildContext context, List measurements) {
    final bool hasData = measurements.isNotEmpty;

    return OasyraCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasData)
             _buildEmptyState(Icons.show_chart_rounded, 'No BMI history yet', 'Add measurements to track progress')
          else
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 2,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: OasyraColors.border.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: OasyraColors.border.withValues(alpha: 0.3),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < measurements.length) {
                            final date = measurements[value.toInt()].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Text(
                                DateFormat('MMM d').format(date),
                                style: TextStyle(color: OasyraColors.textTertiary, fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(color: OasyraColors.textTertiary, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: OasyraColors.border.withValues(alpha: 0.2)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: measurements.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.bmi);
                      }).toList(),
                      isCurved: true,
                      color: OasyraColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: OasyraColors.primary,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            OasyraColors.primary.withValues(alpha: 0.2),
                            OasyraColors.primary.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => OasyraColors.primary,
                      getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                        'BMI: ${s.y.toStringAsFixed(1)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      )).toList(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 100.ms);
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: OasyraColors.border),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: OasyraColors.textSecondary)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: OasyraColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionList(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: AIConfig.quickActions.map((action) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              label: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              side: const BorderSide(color: OasyraColors.border),
              onPressed: () {
                ref.read(chatbotNotifierProvider.notifier).sendMessage(action);
                context.push('/chatbot');
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActionGrid(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildActionCard(
              context, 
              'AI Dietitian', 
              'Health Assistant', 
              Icons.psychology_outlined, 
              OasyraColors.infoLight, 
              cardWidth,
              () => context.push('/chatbot'),
            ),
            _buildActionCard(
              context, 
              'Assessment', 
              'Risk screening', 
              Icons.assignment_outlined, 
              OasyraColors.accentLavender, 
              cardWidth,
              () => context.push('/health-assessment'),
            ),
            _buildActionCard(
              context, 
              'Add Measurements', 
              'Track progress', 
              Icons.add_chart_rounded, 
              OasyraColors.successLight.withValues(alpha: 0.3), 
              cardWidth,
              () => context.push('/add-measurement'),
            ),
            _buildActionCard(
              context, 
              'Report', 
              'Download PDF', 
              Icons.picture_as_pdf_rounded, 
              OasyraColors.surfaceSoft, 
              cardWidth,
              () => ref.read(reportGenerationProvider.notifier).generateReport(),
            ),
            _buildActionCard(
              context, 
              'Nutrition', 
              'Log meals & macros', 
              Icons.restaurant_menu_rounded, 
              OasyraColors.primarySoft, 
              constraints.maxWidth,
              () => context.push('/nutrition-dashboard'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, double width, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: OasyraColors.primary, size: 24),
            const SizedBox(height: 12),
            Text(
              title, 
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: OasyraColors.textPrimary),
            ),
            Text(
              subtitle, 
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: OasyraColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBmiColor(String category) {
    switch (category) {
      case 'Healthy weight': return OasyraColors.success;
      case 'Underweight': return Colors.blue;
      case 'Overweight': return OasyraColors.warning;
      default: return OasyraColors.error;
    }
  }
}
