import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/health_data_models.dart';
import '../../domain/repositories/health_data_repository.dart';

class MockHealthDataRepository implements HealthDataRepository {
  final SharedPreferences _prefs;
  bool _isConnected = false;

  MockHealthDataRepository(this._prefs) {
    _isConnected = _prefs.getBool('health_connect_connected') ?? false;
  }

  String _summaryKey(String userId) => 'health_summary_$userId';

  @override
  Future<bool> isHealthConnectAvailable() async => true;

  @override
  Future<bool> hasPermissions() async => _isConnected;

  @override
  Future<bool> requestPermissions() async {
    await Future.delayed(const Duration(seconds: 1));
    _isConnected = true;
    await _prefs.setBool('health_connect_connected', true);
    return true;
  }

  @override
  Future<void> synchronizeData(String userId) async {
    if (!_isConnected) return;
    
    await Future.delayed(const Duration(seconds: 2));
    
    // Generate some mock dynamic data (simulating Fitbit sync)
    final summary = HealthDataSummary(
      todaySteps: 8421,
      todayActiveCalories: 452.5,
      todayActiveMinutes: 38,
      latestHeartRate: 72,
      heartRateTimestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      lastSleepDurationHours: 7.5,
      latestConnectedWeight: 88.2,
      lastSyncTime: DateTime.now(),
    );
    
    await _prefs.setString(_summaryKey(userId), json.encode({
      'todaySteps': summary.todaySteps,
      'todayActiveCalories': summary.todayActiveCalories,
      'todayActiveMinutes': summary.todayActiveMinutes,
      'latestHeartRate': summary.latestHeartRate,
      'heartRateTimestamp': summary.heartRateTimestamp?.toIso8601String(),
      'lastSleepDurationHours': summary.lastSleepDurationHours,
      'latestConnectedWeight': summary.latestConnectedWeight,
      'lastSyncTime': summary.lastSyncTime.toIso8601String(),
    }));
  }

  @override
  Future<HealthDataSummary?> getLatestSummary(String userId) async {
    final data = _prefs.getString(_summaryKey(userId));
    if (data == null) return null;
    
    final map = json.decode(data);
    return HealthDataSummary(
      todaySteps: map['todaySteps'] ?? 0,
      todayActiveCalories: (map['todayActiveCalories'] as num?)?.toDouble() ?? 0.0,
      todayActiveMinutes: map['todayActiveMinutes'] ?? 0,
      latestHeartRate: (map['latestHeartRate'] as num?)?.toDouble(),
      heartRateTimestamp: map['heartRateTimestamp'] != null ? DateTime.parse(map['heartRateTimestamp']) : null,
      lastSleepDurationHours: (map['lastSleepDurationHours'] as num?)?.toDouble(),
      latestConnectedWeight: (map['latestConnectedWeight'] as num?)?.toDouble(),
      lastSyncTime: DateTime.parse(map['lastSyncTime']),
    );
  }

  @override
  Future<List<HealthDataRecord>> getHistoricalData(String userId, OasyraHealthDataType type, DateTime start, DateTime end) async {
    return [];
  }
}
