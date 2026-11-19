import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../core/services/oasyra_pdf_service.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../health/presentation/providers/health_data_providers.dart';
import '../../../analysis/presentation/providers/analysis_providers.dart';

final pdfServiceProvider = Provider<PdfService>((ref) {
  return OasyraPdfService();
});

class ReportState {
  final AsyncValue<Uint8List?> pdfBytes;
  final String? fileName;

  ReportState({
    this.pdfBytes = const AsyncValue.data(null),
    this.fileName,
  });

  ReportState copyWith({
    AsyncValue<Uint8List?>? pdfBytes,
    String? fileName,
  }) {
    return ReportState(
      pdfBytes: pdfBytes ?? this.pdfBytes,
      fileName: fileName ?? this.fileName,
    );
  }
}

class ReportNotifier extends StateNotifier<ReportState> {
  final Ref _ref;
  final PdfService _pdfService;

  ReportNotifier(this._ref, this._pdfService) : super(ReportState());

  Future<void> generateReport() async {
    state = state.copyWith(pdfBytes: const AsyncValue.loading());
    try {
      final profile = _ref.read(healthProfileProvider);
      final measurements = _ref.read(healthMetricsProvider);
      final analysis = _ref.read(healthAnalysisProvider);
      final activity = _ref.read(healthDataProvider).summary;

      // Format data for PDF
      final Map<String, dynamic> pdfInput = {
        'userName': profile?.name ?? 'OASYRA User',
        'age': profile?.age.toString(),
        'gender': profile?.gender,
        'height': profile?.heightCm.toString(),
        'weight': profile?.currentWeightKg.toString(),
        'targetWeight': profile?.targetWeightKg.toString(),
        'activityLevel': profile?.activityLevel,
        'cuisine': profile?.cuisinePreference,
        'dietType': profile?.dietType,
        'goals': profile?.healthGoals.join(', '),
        'bmi': profile?.bmi.toStringAsFixed(1),
        'bmiCategory': profile?.bmiCategory,
        'bmr': analysis.estimatedBmr?.toStringAsFixed(0),
        'dailyEnergy': analysis.estimatedDailyEnergy?.toStringAsFixed(0),
        'overallConcern': analysis.overallConcern.name.toUpperCase(),
        'behavioralFactors': analysis.behavioralFactors.map((f) => {
          'name': f.name,
          'interpretation': f.interpretation,
        }).toList(),
        'recommendations': analysis.recommendations.map((r) => r.title).toList(),
        'todaySteps': activity?.todaySteps.toString(),
        'todayCaloriesBurned': activity?.todayActiveCalories.toStringAsFixed(0),
        'lastSync': activity?.lastSyncTime != null ? DateFormat('MMM dd, h:mm a').format(activity!.lastSyncTime) : null,
        'measurements': measurements.map((m) => {
          'date': DateFormat('MMM dd, yyyy').format(m.date),
          'weight': m.weightKg.toString(),
          'bmi': m.bmi.toStringAsFixed(1),
        }).toList(),
        'personalizedPlan': analysis.personalizedPlan.map((p) => {
          'domain': p.domain,
          'goal': p.goal,
          'action': p.action,
        }).toList(),
        'nutritionPlan': analysis.nutritionPlan.map((n) => {
          'type': n.mealType,
          'dish': n.dishName,
          'portion': n.portion,
        }).toList(),
      };

      final bytes = await _pdfService.generateHealthReport(pdfInput);
      final name = 'oasyra_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      state = state.copyWith(
        pdfBytes: AsyncValue.data(bytes),
        fileName: name,
      );
    } catch (e, stack) {
      state = state.copyWith(pdfBytes: AsyncValue.error(e, stack));
    }
  }

  void reset() {
    state = ReportState();
  }
}

final reportGenerationProvider = StateNotifierProvider<ReportNotifier, ReportState>((ref) {
  final pdfService = ref.watch(pdfServiceProvider);
  return ReportNotifier(ref, pdfService);
});
