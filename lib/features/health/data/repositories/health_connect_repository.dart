import 'dart:convert';
import 'package:health/health.dart' as h;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/health_data_models.dart';
import '../../domain/repositories/health_data_repository.dart';

class HealthConnectRepository implements HealthDataRepository {
  final SharedPreferences _prefs;
  final h.Health _health = h.Health();

  HealthConnectRepository(this._prefs) {
    // Basic configuration
  }

  static const List<h.HealthDataType> _types = [
    h.HealthDataType.STEPS,
    h.HealthDataType.ACTIVE_ENERGY_BURNED,
    h.HealthDataType.WORKOUT,
    h.HealthDataType.HEART_RATE,
    h.HealthDataType.SLEEP_SESSION,
    h.HealthDataType.WEIGHT,
  ];

  String _summaryKey(String userId) => 'health_summary_$userId';

  @override
  Future<bool> isHealthConnectAvailable() async {
    return await h.Health().isHealthConnectAvailable();
  }

  @override
  Future<bool> hasPermissions() async {
    return await _health.hasPermissions(_types) ?? false;
  }

  @override
  Future<bool> requestPermissions() async {
    return await _health.requestAuthorization(_types);
  }

  @override
  Future<void> synchronizeData(String userId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    // Fetch steps
    int steps = 0;
    try {
      steps = await _health.getTotalStepsInInterval(todayStart, now) ?? 0;
    } catch (_) {}

    // Fetch other data
    List<h.HealthDataPoint> dataPoints = [];
    try {
      dataPoints = await _health.getHealthDataFromTypes(
        startTime: todayStart.subtract(const Duration(days: 1)),
        endTime: now,
        types: _types,
      );
    } catch (_) {}

    double activeCalories = 0;
    int activeMinutes = 0;
    double? latestHR;
    DateTime? hrTime;
    double? lastSleep;
    double? latestWeight;

    for (var point in dataPoints) {
      final value = point.value;
      if (point.type == h.HealthDataType.ACTIVE_ENERGY_BURNED) {
        if (point.dateFrom.isAfter(todayStart) && value is h.NumericHealthValue) {
          activeCalories += value.numericValue;
        }
      } else if (point.type == h.HealthDataType.WORKOUT) {
        if (point.dateFrom.isAfter(todayStart)) {
          // Calculate duration from the workout session
          activeMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
        }
      } else if (point.type == h.HealthDataType.HEART_RATE) {
        if (value is h.NumericHealthValue) {
          final val = value.numericValue.toDouble();
          if (hrTime == null || point.dateTo.isAfter(hrTime)) {
            latestHR = val;
            hrTime = point.dateTo;
          }
        }
      } else if (point.type == h.HealthDataType.SLEEP_SESSION) {
        final duration = point.dateTo.difference(point.dateFrom).inMinutes / 60.0;
        lastSleep = duration;
      } else if (point.type == h.HealthDataType.WEIGHT) {
        if (value is h.NumericHealthValue) {
          latestWeight = value.numericValue.toDouble();
        }
      }
    }

    final summary = HealthDataSummary(
      todaySteps: steps,
      todayActiveCalories: activeCalories,
      todayActiveMinutes: activeMinutes,
      latestHeartRate: latestHR,
      heartRateTimestamp: hrTime,
      lastSleepDurationHours: lastSleep,
      latestConnectedWeight: latestWeight,
      lastSyncTime: now,
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
