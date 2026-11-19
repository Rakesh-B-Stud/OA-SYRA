import 'package:flutter_test/flutter_test.dart';
import 'package:oasyara_1/features/health/domain/models/health_data_models.dart';
import 'package:oasyara_1/features/health/data/repositories/mock_health_data_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('HealthDataRecord Model', () {
    test('toMap and fromMap should be consistent', () {
      final record = HealthDataRecord(
        id: '1',
        userId: 'test@example.com',
        type: OasyraHealthDataType.steps,
        value: 5000,
        unit: 'count',
        startTime: DateTime(2026, 8, 21, 10, 0),
        endTime: DateTime(2026, 8, 21, 11, 0),
        source: HealthDataSource.healthConnect,
        sourceApp: 'Fitbit',
        synchronizedAt: DateTime(2026, 8, 21, 12, 0),
      );

      final map = record.toMap();
      final fromMap = HealthDataRecord.fromMap(map);

      expect(fromMap, record);
    });
  });

  group('MockHealthDataRepository', () {
    late SharedPreferences prefs;
    late MockHealthDataRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = MockHealthDataRepository(prefs);
    });

    test('should initially be disconnected', () async {
      final hasPerms = await repository.hasPermissions();
      expect(hasPerms, false);
    });

    test('should connect and synchronize data', () async {
      await repository.requestPermissions();
      expect(await repository.hasPermissions(), true);

      await repository.synchronizeData('user1');
      final summary = await repository.getLatestSummary('user1');

      expect(summary, isNotNull);
      expect(summary!.todaySteps, 8421);
      expect(summary.todayActiveCalories, 452.5);
    });

    test('should maintain user isolation', () async {
      await repository.requestPermissions();
      
      await repository.synchronizeData('user1');
      final summary1 = await repository.getLatestSummary('user1');
      
      final summary2 = await repository.getLatestSummary('user2');
      expect(summary2, isNull);
      
      expect(summary1, isNotNull);
    });
  });
}
