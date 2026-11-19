import '../models/health_data_models.dart';

abstract class HealthDataRepository {
  Future<bool> isHealthConnectAvailable();
  Future<bool> hasPermissions();
  Future<bool> requestPermissions();
  
  Future<void> synchronizeData(String userId);
  
  Future<HealthDataSummary?> getLatestSummary(String userId);
  Future<List<HealthDataRecord>> getHistoricalData(String userId, OasyraHealthDataType type, DateTime start, DateTime end);
}
