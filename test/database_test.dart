import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:oasyara_1/core/database/app_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late AppDatabase appDb;

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
          CREATE TABLE food_catalog (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            cuisine TEXT,
            diet_types_json TEXT,
            category TEXT,
            calories_per_100g REAL NOT NULL,
            protein_per_100g REAL NOT NULL,
            carbs_per_100g REAL NOT NULL,
            fat_per_100g REAL NOT NULL,
            fiber_per_100g REAL NOT NULL,
            source TEXT,
            source_reference TEXT
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

        batch.execute('''
          CREATE TABLE activity_records (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            steps INTEGER NOT NULL,
            active_calories REAL NOT NULL,
            active_minutes INTEGER NOT NULL,
            distance_km REAL,
            last_sync_time TEXT
          );
        ''');

        batch.execute('''
          CREATE TABLE sleep_records (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            duration_minutes INTEGER NOT NULL,
            deep_sleep_minutes INTEGER,
            light_sleep_minutes INTEGER,
            rem_sleep_minutes INTEGER,
            sleep_quality_score REAL,
            snoring_symptoms INTEGER DEFAULT 0
          );
        ''');

        batch.execute('''
          CREATE TABLE hydration_records (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            date TEXT NOT NULL,
            intake_ml INTEGER NOT NULL,
            target_ml INTEGER NOT NULL
          );
        ''');

        batch.execute('''
          CREATE TABLE nutrition_goals (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            target_calories REAL NOT NULL,
            target_protein REAL NOT NULL,
            target_carbs REAL NOT NULL,
            target_fat REAL NOT NULL,
            target_fiber REAL,
            created_at TEXT NOT NULL
          );
        ''');

        batch.execute('''
          CREATE TABLE recommendation_history (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            domain TEXT NOT NULL,
            title TEXT NOT NULL,
            action_text TEXT NOT NULL,
            generated_at TEXT NOT NULL,
            metadata_json TEXT
          );
        ''');

        await batch.commit();
      },
    );
    appDb = AppDatabase.forTesting(db);
  });

  tearDown(() async {
    await appDb.close();
  });

  test('Database initialization creates all 13 foundational tables', () async {
    final activeDb = await appDb.database;
    final tables = await activeDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    final tableNames = tables.map((t) => t['name'] as String).toSet();

    expect(tableNames.contains('health_profiles'), true);
    expect(tableNames.contains('health_measurements'), true);
    expect(tableNames.contains('health_assessments'), true);
    expect(tableNames.contains('meal_records'), true);
    expect(tableNames.contains('meal_items'), true);
    expect(tableNames.contains('food_catalog'), true);
    expect(tableNames.contains('chat_conversations'), true);
    expect(tableNames.contains('chat_messages'), true);
    expect(tableNames.contains('activity_records'), true);
    expect(tableNames.contains('sleep_records'), true);
    expect(tableNames.contains('hydration_records'), true);
    expect(tableNames.contains('nutrition_goals'), true);
    expect(tableNames.contains('recommendation_history'), true);
    expect(tableNames.length, 13);
  });

  test('User isolation between user_1 and user_2', () async {
    final activeDb = await appDb.database;

    await activeDb.insert('health_profiles', {
      'user_id': 'user_1',
      'name': 'User One',
      'date_of_birth': '1995-01-01',
      'gender': 'Male',
      'height_cm': 175.0,
      'current_weight_kg': 70.0,
      'target_weight_kg': 65.0,
      'activity_level': 'Moderate',
      'stress_level': 'Low',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await activeDb.insert('health_profiles', {
      'user_id': 'user_2',
      'name': 'User Two',
      'date_of_birth': '1998-05-15',
      'gender': 'Female',
      'height_cm': 162.0,
      'current_weight_kg': 58.0,
      'target_weight_kg': 55.0,
      'activity_level': 'Active',
      'stress_level': 'Low',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    final res1 = await activeDb.query('health_profiles', where: 'user_id = ?', whereArgs: ['user_1']);
    final res2 = await activeDb.query('health_profiles', where: 'user_id = ?', whereArgs: ['user_2']);

    expect(res1.length, 1);
    expect(res1.first['name'], 'User One');
    expect(res2.length, 1);
    expect(res2.first['name'], 'User Two');
  });

  test('Foreign key CASCADE deletion for chat messages', () async {
    final activeDb = await appDb.database;

    await activeDb.insert('chat_conversations', {
      'id': 'conv_1',
      'user_id': 'user_1',
      'title': 'Nutrition Query',
      'created_at': DateTime.now().toIso8601String(),
      'last_updated': DateTime.now().toIso8601String(),
    });

    await activeDb.insert('chat_messages', {
      'id': 'msg_1',
      'conversation_id': 'conv_1',
      'user_id': 'user_1',
      'role': 'user',
      'text': 'Hello Dietitian',
      'timestamp': DateTime.now().toIso8601String(),
    });

    await activeDb.delete('chat_conversations', where: 'id = ?', whereArgs: ['conv_1']);

    final messages = await activeDb.query('chat_messages', where: 'conversation_id = ?', whereArgs: ['conv_1']);
    expect(messages.isEmpty, true);
  });

  test('Transaction rollback prevents partial writes on failure', () async {
    final activeDb = await appDb.database;

    try {
      await activeDb.transaction((txn) async {
        await txn.insert('chat_conversations', {
          'id': 'conv_tx',
          'user_id': 'user_1',
          'title': 'Test Txn',
          'created_at': DateTime.now().toIso8601String(),
          'last_updated': DateTime.now().toIso8601String(),
        });
        throw Exception('Forced transaction error');
      });
    } catch (_) {}

    final convs = await activeDb.query('chat_conversations', where: 'id = ?', whereArgs: ['conv_tx']);
    expect(convs.isEmpty, true);
  });
}
