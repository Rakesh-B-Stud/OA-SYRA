import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:oasyara_1/core/database/app_database.dart';
import 'package:oasyara_1/features/health/data/repositories/sqlite_health_repository.dart';
import 'package:oasyara_1/features/health/domain/models/health_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late AppDatabase appDb;
  late SQLiteHealthRepository repository;

  setUp(() async {
    AppDatabase.resetForTesting();
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute('''
          CREATE TABLE health_profiles (
            user_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            date_of_birth TEXT NOT NULL,
            gender TEXT NOT NULL,
            height_cm REAL NOT NULL,
            current_weight_kg REAL NOT NULL,
            target_weight_kg REAL NOT NULL,
            activity_level TEXT NOT NULL,
            stress_level TEXT NOT NULL,
            dietary_restrictions TEXT,
            health_goals TEXT,
            medical_conditions TEXT,
            waist_circumference_cm REAL,
            cuisine_preference TEXT,
            diet_type TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');

        batch.execute('''
          CREATE TABLE health_measurements (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            weight_kg REAL NOT NULL,
            height_cm REAL NOT NULL,
            waist_circumference_cm REAL
          );
        ''');

        batch.execute('''
          CREATE TABLE health_assessments (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            responses_json TEXT NOT NULL
          );
        ''');

        await batch.commit();
      },
    );

    appDb = AppDatabase.forTesting(db);
    repository = SQLiteHealthRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  test('Save and retrieve HealthProfile from SQLite', () async {
    const userId = 'user_sqflite_1';
    final profile = HealthProfile(
      userId: userId,
      name: 'John Doe',
      dateOfBirth: DateTime(1990, 5, 20),
      gender: 'Male',
      heightCm: 178,
      currentWeightKg: 75,
      targetWeightKg: 70,
      activityLevel: 'Moderate',
      stressLevel: 'Low',
      dietaryRestrictions: const ['Dairy-Free'],
      healthGoals: const ['Muscle Gain'],
      medicalConditions: const [],
    );

    await repository.saveProfile(profile);

    final retrieved = await repository.getProfile(userId);
    expect(retrieved, isNotNull);
    expect(retrieved!.name, 'John Doe');
    expect(retrieved.heightCm, 178);
    expect(retrieved.dietaryRestrictions, contains('Dairy-Free'));
  });

  test('Add, retrieve and delete HealthMeasurement in SQLite', () async {
    const userId = 'user_sqflite_1';
    final m1 = HealthMeasurement(
      id: 'm_101',
      userId: userId,
      date: DateTime(2026, 2, 1),
      weightKg: 75,
      heightCm: 178,
    );

    await repository.addMeasurement(m1);

    final list = await repository.getMeasurements(userId);
    expect(list.length, 1);
    expect(list.first.weightKg, 75);

    await repository.deleteMeasurement(userId, 'm_101');
    final emptyList = await repository.getMeasurements(userId);
    expect(emptyList.isEmpty, true);
  });

  test('Save and retrieve latest HealthAssessment in SQLite', () async {
    const userId = 'user_sqflite_1';
    final assessment = HealthAssessment(
      id: 'a_101',
      userId: userId,
      date: DateTime(2026, 2, 1),
      responses: const [
        AssessmentResponse(questionId: 'q1', response: 'No significant change'),
      ],
    );

    await repository.saveAssessment(assessment);

    final latest = await repository.getLatestAssessment(userId);
    expect(latest, isNotNull);
    expect(latest!.id, 'a_101');
    expect(latest.responses.first.response, 'No significant change');
  });
}
