import '../models/health_models.dart';

abstract class HealthProfileRepository {
  Future<HealthProfile?> getProfile(String userId);
  Future<void> saveProfile(HealthProfile profile);
}

abstract class HealthMetricsRepository {
  Future<List<HealthMeasurement>> getMeasurements(String userId);
  Future<void> addMeasurement(HealthMeasurement measurement);
}

abstract class HealthAssessmentRepository {
  Future<List<AssessmentQuestion>> getQuestionBank();
  Future<void> saveAssessment(HealthAssessment assessment);
  Future<HealthAssessment?> getLatestAssessment(String userId);
}
