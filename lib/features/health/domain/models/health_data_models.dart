import 'package:equatable/equatable.dart';

enum OasyraHealthDataType {
  steps,
  activeCalories,
  activeMinutes,
  heartRate,
  sleep,
  weight,
}

enum HealthDataSource {
  selfReported,
  healthConnect,
  manual,
}

class HealthDataRecord extends Equatable {
  final String id;
  final String userId;
  final OasyraHealthDataType type;
  final double value;
  final String unit;
  final DateTime startTime;
  final DateTime endTime;
  final HealthDataSource source;
  final String? sourceApp;
  final DateTime synchronizedAt;

  const HealthDataRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.value,
    required this.unit,
    required this.startTime,
    required this.endTime,
    required this.source,
    this.sourceApp,
    required this.synchronizedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        value,
        unit,
        startTime,
        endTime,
        source,
        sourceApp,
        synchronizedAt,
      ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'value': value,
      'unit': unit,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'source': source.name,
      'sourceApp': sourceApp,
      'synchronizedAt': synchronizedAt.toIso8601String(),
    };
  }

  factory HealthDataRecord.fromMap(Map<String, dynamic> map) {
    return HealthDataRecord(
      id: map['id'],
      userId: map['userId'],
      type: OasyraHealthDataType.values.byName(map['type']),
      value: map['value'],
      unit: map['unit'],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      source: HealthDataSource.values.byName(map['source']),
      sourceApp: map['sourceApp'],
      synchronizedAt: DateTime.parse(map['synchronizedAt']),
    );
  }
}

class HealthDataSummary extends Equatable {
  final int todaySteps;
  final double todayActiveCalories;
  final int todayActiveMinutes;
  final double? latestHeartRate;
  final DateTime? heartRateTimestamp;
  final double? lastSleepDurationHours;
  final double? latestConnectedWeight;
  final DateTime lastSyncTime;

  const HealthDataSummary({
    this.todaySteps = 0,
    this.todayActiveCalories = 0,
    this.todayActiveMinutes = 0,
    this.latestHeartRate,
    this.heartRateTimestamp,
    this.lastSleepDurationHours,
    this.latestConnectedWeight,
    required this.lastSyncTime,
  });

  @override
  List<Object?> get props => [
        todaySteps,
        todayActiveCalories,
        todayActiveMinutes,
        latestHeartRate,
        heartRateTimestamp,
        lastSleepDurationHours,
        latestConnectedWeight,
        lastSyncTime,
      ];
}
