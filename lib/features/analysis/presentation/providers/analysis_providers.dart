import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../domain/models/analysis_models.dart';
import '../../domain/services/analysis_engine.dart';

final analysisEngineProvider = Provider((ref) => AnalysisEngine());

final healthAnalysisProvider = Provider<HealthAnalysis>((ref) {
  final engine = ref.watch(analysisEngineProvider);
  final profile = ref.watch(healthProfileProvider);
  final measurements = ref.watch(healthMetricsProvider);
  final assessment = ref.watch(healthAssessmentProvider);

  return engine.analyze(
    profile: profile,
    measurements: measurements,
    assessment: assessment,
  );
});
