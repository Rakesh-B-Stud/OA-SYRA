import '../../../health/domain/models/health_models.dart';
import '../../../health/domain/models/health_data_models.dart';
import '../../../analysis/domain/models/analysis_models.dart';
import '../../../nutrition/domain/models/nutrition_models.dart';

class ReportData {
  final HealthProfile? profile;
  final List<HealthMeasurement> measurements;
  final HealthAnalysis? analysis;
  final HealthDataSummary? activitySummary;
  final DailyNutritionRollup? nutritionRollup;

  ReportData({
    this.profile,
    required this.measurements,
    this.analysis,
    this.activitySummary,
    this.nutritionRollup,
  });
}

class ReportDataCollector {
  /// Aggregates all real health data for the PDF report.
  ReportData collect({
    required HealthProfile? profile,
    required List<HealthMeasurement> measurements,
    required HealthAnalysis? analysis,
    required HealthDataSummary? activitySummary,
    required DailyNutritionRollup? nutritionRollup,
  }) {
    return ReportData(
      profile: profile,
      measurements: measurements,
      analysis: analysis,
      activitySummary: activitySummary,
      nutritionRollup: nutritionRollup,
    );
  }
}
