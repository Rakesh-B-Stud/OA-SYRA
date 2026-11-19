import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../../../../shared/widgets/oasyra_button.dart';
import '../providers/health_data_providers.dart';
import '../../domain/models/health_data_models.dart';

class HealthDataScreen extends ConsumerWidget {
  const HealthDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthDataState = ref.watch(healthDataProvider);

    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'Health Data',
            subtitle: 'Real-world activity insights',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectionStatus(context, healthDataState, ref),
                  const SizedBox(height: 32),
                  if (healthDataState.status == HealthSyncStatus.connected || 
                      healthDataState.status == HealthSyncStatus.syncing) ...[
                    _buildTodayActivity(context, healthDataState.summary),
                    const SizedBox(height: 32),
                    _buildVitalMetrics(context, healthDataState.summary),
                    const SizedBox(height: 32),
                    _buildSleepWeight(context, healthDataState.summary),
                  ] else ...[
                    _buildEmptyState(context, healthDataState.status, ref),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context, HealthDataState state, WidgetRef ref) {
    final isConnected = state.status == HealthSyncStatus.connected || state.status == HealthSyncStatus.syncing;
    
    return OasyraCard(
      padding: const EdgeInsets.all(20),
      color: isConnected ? OasyraColors.successLight.withValues(alpha: 0.3) : Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected ? OasyraColors.success : OasyraColors.border,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Health Connect Active' : 'Not Connected',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: OasyraColors.textPrimary),
                ),
                if (isConnected && state.summary != null)
                  Text(
                    'Last synced: ${DateFormat('h:mm a').format(state.summary!.lastSyncTime)}',
                    style: TextStyle(fontSize: 12, color: OasyraColors.textSecondary),
                  )
                else
                  const Text(
                    'Connect Fitbit via Health Connect',
                    style: TextStyle(fontSize: 12, color: OasyraColors.textTertiary),
                  ),
              ],
            ),
          ),
          if (isConnected)
            IconButton(
              onPressed: state.status == HealthSyncStatus.syncing ? null : () => ref.read(healthDataProvider.notifier).sync(),
              icon: state.status == HealthSyncStatus.syncing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded, color: OasyraColors.primary),
            )
          else
            TextButton(
              onPressed: () => ref.read(healthDataProvider.notifier).connect(),
              child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildTodayActivity(BuildContext context, HealthDataSummary? summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader(
          title: 'Today\'s Activity',
          subtitle: 'Daily movement targets',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PremiumMetricCard(
                label: 'STEPS',
                value: summary?.todaySteps.toString() ?? '--',
                unit: 'steps',
                icon: Icons.directions_walk_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PremiumMetricCard(
                label: 'ACTIVE KCAL',
                value: summary?.todayActiveCalories.toStringAsFixed(0) ?? '--',
                unit: 'kcal',
                icon: Icons.local_fire_department_rounded,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OasyraCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: OasyraColors.primary, size: 20),
              const SizedBox(width: 12),
              const Text('Active Minutes', style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                '${summary?.todayActiveMinutes ?? "--"} min',
                style: const TextStyle(fontWeight: FontWeight.bold, color: OasyraColors.primary),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildVitalMetrics(BuildContext context, HealthDataSummary? summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumSectionHeader(title: 'Vital Metrics'),
        const SizedBox(height: 16),
        OasyraCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: OasyraColors.errorLight.withValues(alpha: 0.3), shape: BoxShape.circle),
                child: const Icon(Icons.favorite_rounded, color: OasyraColors.error, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Heart Rate', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    summary?.heartRateTimestamp != null 
                      ? 'Last checked ${DateFormat('h:mm a').format(summary!.heartRateTimestamp!)}'
                      : 'No recent reading',
                    style: TextStyle(fontSize: 12, color: OasyraColors.textTertiary),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                summary?.latestHeartRate != null ? '${summary!.latestHeartRate!.toInt()}' : '--',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: OasyraColors.textPrimary),
              ),
              const SizedBox(width: 4),
              const Text('BPM', style: TextStyle(fontSize: 12, color: OasyraColors.textSecondary)),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildSleepWeight(BuildContext context, HealthDataSummary? summary) {
    return Row(
      children: [
        Expanded(
          child: PremiumMetricCard(
            label: 'LAST SLEEP',
            value: summary?.lastSleepDurationHours?.toStringAsFixed(1) ?? '--',
            unit: 'hrs',
            icon: Icons.nightlight_round_outlined,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: PremiumMetricCard(
            label: 'SYNCED WEIGHT',
            value: summary?.latestConnectedWeight?.toStringAsFixed(1) ?? '--',
            unit: 'kg',
            icon: Icons.monitor_weight_outlined,
            color: Colors.teal,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildEmptyState(BuildContext context, HealthSyncStatus status, WidgetRef ref) {
    String title = 'Ready to Connect?';
    String subtitle = 'Sync your Fitbit or other health apps via Health Connect.';
    IconData icon = Icons.health_and_safety_outlined;

    if (status == HealthSyncStatus.error) {
       title = 'Connection Error';
       subtitle = 'Could not access Health Connect. Please check permissions.';
       icon = Icons.error_outline_rounded;
    }

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(icon, size: 80, color: OasyraColors.border),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: OasyraColors.textPrimary)),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OasyraColors.textTertiary),
          ),
          const SizedBox(height: 40),
          OasyraButton(
            text: 'Configure Connection',
            onPressed: () => ref.read(healthDataProvider.notifier).connect(),
            isFullWidth: false,
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}
