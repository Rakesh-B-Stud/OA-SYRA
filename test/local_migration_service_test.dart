import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:oasyara_1/core/database/app_database.dart';
import 'package:oasyara_1/core/database/local_migration_service.dart';
import 'package:oasyara_1/features/health/domain/models/health_models.dart';
import 'package:oasyara_1/features/nutrition/domain/models/nutrition_models.dart';
import 'package:oasyara_1/features/chatbot/domain/models/chat_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late AppDatabase appDb;
  late SharedPreferences prefs;
  late LocalMigrationService migrationService;

  setUp(() async {
    AppDatabase.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

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

        batch.execute('''
          CREATE TABLE meal_records (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            meal_type TEXT NOT NULL,
            image_path TEXT,
            total_calories REAL NOT NULL,
            total_protein REAL NOT NULL,
            total_carbs REAL NOT NULL,
            total_fat REAL NOT NULL,
            items_json TEXT NOT NULL
          );
        ''');

        batch.execute('''
          CREATE TABLE meal_items (
            id TEXT PRIMARY KEY,
            meal_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            food_id TEXT NOT NULL,
            food_name TEXT NOT NULL,
            cuisine TEXT,
            diet_types_json TEXT,
            category TEXT,
            calories_per_100g REAL NOT NULL,
            protein_per_100g REAL NOT NULL,
            carbs_per_100g REAL NOT NULL,
            fat_per_100g REAL NOT NULL,
            fiber_per_100g REAL NOT NULL,
            estimated_mass_g REAL NOT NULL,
            confidence REAL NOT NULL,
            portion_method TEXT NOT NULL,
            detection_label TEXT,
            has_disagreement INTEGER DEFAULT 0,
            is_uncertain INTEGER DEFAULT 0,
            FOREIGN KEY (meal_id) REFERENCES meal_records (id) ON DELETE CASCADE
          );
        ''');

        batch.execute('''
          CREATE TABLE chat_conversations (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_updated TEXT NOT NULL
          );
        ''');

        batch.execute('''
          CREATE TABLE chat_messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            role TEXT NOT NULL,
            text TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (conversation_id) REFERENCES chat_conversations (id) ON DELETE CASCADE
          );
        ''');

        await batch.commit();
      },
    );

    appDb = AppDatabase.forTesting(db);
    migrationService = LocalMigrationService(appDb, prefs);
  });

  tearDown(() async {
    await appDb.close();
  });

  test('1. First-time migration creates SQLite records for all categories', () async {
    const userId = 'user_100';

    final profile = HealthProfile(
      userId: userId,
      name: 'Alice Smith',
      dateOfBirth: DateTime(1994, 3, 15),
      gender: 'Female',
      heightCm: 165,
      currentWeightKg: 62,
      targetWeightKg: 58,
      activityLevel: 'Moderate',
      stressLevel: 'Low',
      dietaryRestrictions: const ['Gluten-Free'],
      healthGoals: const ['Weight Loss'],
      medicalConditions: const [],
    );
    await prefs.setString('health_profile_$userId', profile.toJson());

    final measurement = HealthMeasurement(
      id: 'm_1',
      userId: userId,
      date: DateTime(2026, 1, 1),
      weightKg: 62,
      heightCm: 165,
    );
    await prefs.setStringList('health_measurements_$userId', [json.encode(measurement.toMap())]);

    final assessment = HealthAssessment(
      id: 'a_1',
      userId: userId,
      date: DateTime(2026, 1, 1),
      responses: const [AssessmentResponse(questionId: 'q1', response: 'No significant change')],
    );
    await prefs.setString('health_assessment_$userId', json.encode(assessment.toMap()));

    final food = const FoodItem(
      id: 'f_1',
      name: 'Roti',
      cuisine: 'Indian',
      dietTypes: ['Vegetarian'],
      category: 'Grain',
      nutritionPer100g: NutritionData(calories: 250, protein: 8, carbohydrates: 50, fat: 3, fiber: 4),
      source: 'IFCT',
      sourceReference: 'IFCT-2017',
    );
    final portion = const PortionEstimate(estimatedMassG: 100, confidence: 0.9, method: 'AI');
    final meal = MealRecord(
      id: 'meal_1',
      userId: userId,
      timestamp: DateTime(2026, 1, 1, 8, 30),
      type: OasyraMealType.breakfast,
      items: [LoggedFoodItem(food: food, portion: portion)],
    );
    await prefs.setStringList('nutrition_meals_$userId', [json.encode(meal.toMap())]);

    final conversation = ChatConversation(
      id: 'conv_1',
      userId: userId,
      title: 'Diet Questions',
      messages: [
        ChatMessage(role: ChatRole.user, text: 'Hi', timestamp: DateTime.now()),
      ],
      lastUpdated: DateTime.now(),
    );
    await prefs.setStringList('chatbot_conversations_$userId', [json.encode(conversation.toMap())]);

    final report = await migrationService.migrateUser(userId);

    expect(report.isFullySuccessful, true);
    expect(report.categoryResults['profile']!.migratedCount, 1);
    expect(report.categoryResults['measurements']!.migratedCount, 1);
    expect(report.categoryResults['assessments']!.migratedCount, 1);
    expect(report.categoryResults['meals']!.migratedCount, 1);
    expect(report.categoryResults['chats']!.migratedCount, 1);

    final activeDb = await appDb.database;
    final pRes = await activeDb.query('health_profiles', where: 'user_id = ?', whereArgs: [userId]);
    expect(pRes.first['name'], 'Alice Smith');

    final mRes = await activeDb.query('health_measurements', where: 'user_id = ?', whereArgs: [userId]);
    expect(mRes.length, 1);

    final itemsRes = await activeDb.query('meal_items', where: 'user_id = ?', whereArgs: [userId]);
    expect(itemsRes.length, 1);
    expect(itemsRes.first['food_name'], 'Roti');

    final msgRes = await activeDb.query('chat_messages', where: 'user_id = ?', whereArgs: [userId]);
    expect(msgRes.length, 1);
    expect(msgRes.first['text'], 'Hi');
  });

  test('2. Repeated migration is idempotent and does not create duplicate records', () async {
    const userId = 'user_100';

    final profile = HealthProfile(
      userId: userId,
      name: 'Alice Smith',
      dateOfBirth: DateTime(1994, 3, 15),
      gender: 'Female',
      heightCm: 165,
      currentWeightKg: 62,
      targetWeightKg: 58,
      activityLevel: 'Moderate',
      stressLevel: 'Low',
      dietaryRestrictions: const [],
      healthGoals: const [],
      medicalConditions: const [],
    );
    await prefs.setString('health_profile_$userId', profile.toJson());

    await migrationService.migrateUser(userId);
    final report2 = await migrationService.migrateUser(userId);

    expect(report2.categoryResults['profile']!.skippedCount, 1);
    expect(report2.categoryResults['profile']!.migratedCount, 0);

    final activeDb = await appDb.database;
    final pRes = await activeDb.query('health_profiles', where: 'user_id = ?', whereArgs: [userId]);
    expect(pRes.length, 1);
  });

  test('3. Migration preserves user isolation between user_1 and user_2', () async {
    const user1 = 'user_1';
    const user2 = 'user_2';

    await prefs.setString('health_profile_$user1', HealthProfile(
      userId: user1, name: 'User One', dateOfBirth: DateTime(1990), gender: 'Male',
      heightCm: 170, currentWeightKg: 70, targetWeightKg: 65, activityLevel: 'Low', stressLevel: 'Low',
      dietaryRestrictions: const [], healthGoals: const [], medicalConditions: const [],
    ).toJson());

    await prefs.setString('health_profile_$user2', HealthProfile(
      userId: user2, name: 'User Two', dateOfBirth: DateTime(1992), gender: 'Female',
      heightCm: 160, currentWeightKg: 55, targetWeightKg: 52, activityLevel: 'Low', stressLevel: 'Low',
      dietaryRestrictions: const [], healthGoals: const [], medicalConditions: const [],
    ).toJson());

    await migrationService.migrateUser(user1);
    await migrationService.migrateUser(user2);

    final activeDb = await appDb.database;
    final r1 = await activeDb.query('health_profiles', where: 'user_id = ?', whereArgs: [user1]);
    final r2 = await activeDb.query('health_profiles', where: 'user_id = ?', whereArgs: [user2]);

    expect(r1.first['name'], 'User One');
    expect(r2.first['name'], 'User Two');
  });

  test('4. Legacy SharedPreferences data remains completely untouched after migration', () async {
    const userId = 'user_300';
    final profile = HealthProfile(
      userId: userId, name: 'Legacy User', dateOfBirth: DateTime(1991), gender: 'Male',
      heightCm: 180, currentWeightKg: 80, targetWeightKg: 75, activityLevel: 'High', stressLevel: 'Low',
      dietaryRestrictions: const [], healthGoals: const [], medicalConditions: const [],
    );
    final rawJson = profile.toJson();
    await prefs.setString('health_profile_$userId', rawJson);

    await migrationService.migrateUser(userId);

    final remainingPref = prefs.getString('health_profile_$userId');
    expect(remainingPref, rawJson);
  });

  test('5. Handles empty SharedPreferences categories gracefully', () async {
    const userId = 'user_empty';
    final report = await migrationService.migrateUser(userId);

    expect(report.isFullySuccessful, true);
    expect(report.categoryResults['profile']!.totalFound, 0);
    expect(report.categoryResults['meals']!.totalFound, 0);
  });

  test('6. Handles malformed JSON safely without throwing unhandled exceptions', () async {
    const userId = 'user_bad_json';
    await prefs.setString('health_profile_$userId', 'INVALID_JSON_CONTENT{{{');

    final report = await migrationService.migrateUser(userId);

    expect(report.categoryResults['profile']!.failedCount, 1);
    expect(report.categoryResults['profile']!.diagnostics.isNotEmpty, true);
    expect(prefs.getBool(LocalMigrationService.profileMarkerKey(userId)), null);
  });
}
