import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton SQLite Database Manager for OASYRA Local Storage Architecture.
///
/// Serves as the single source of truth for all local application data,
/// enforcing user isolation using Firebase Auth UID (`user_id`).
class AppDatabase {
  static const String _dbName = 'oasyra_local.db';
  static const int _dbVersion = 1;

  static AppDatabase? _instance;
  static Database? _database;

  AppDatabase._internal();

  factory AppDatabase() {
    _instance ??= AppDatabase._internal();
    return _instance!;
  }

  /// Constructor for injecting in-memory test database instances during unit testing.
  AppDatabase.forTesting(Database db) {
    _database = db;
    _instance = this;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enforce SQLite Foreign Key constraints for cascades and relationships
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. health_profiles
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

    // 2. health_measurements
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
    batch.execute('CREATE INDEX idx_measurements_user ON health_measurements(user_id);');
    batch.execute('CREATE INDEX idx_measurements_date ON health_measurements(date);');

    // 3. health_assessments
    batch.execute('''
      CREATE TABLE health_assessments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        responses_json TEXT NOT NULL
      );
    ''');
    batch.execute('CREATE INDEX idx_assessments_user ON health_assessments(user_id);');
    batch.execute('CREATE INDEX idx_assessments_date ON health_assessments(date);');

    // 4. meal_records
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
    batch.execute('CREATE INDEX idx_meals_user ON meal_records(user_id);');
    batch.execute('CREATE INDEX idx_meals_timestamp ON meal_records(timestamp);');

    // 5. meal_items
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
    batch.execute('CREATE INDEX idx_items_meal ON meal_items(meal_id);');
    batch.execute('CREATE INDEX idx_items_user ON meal_items(user_id);');

    // 6. food_catalog
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
    batch.execute('CREATE INDEX idx_food_name ON food_catalog(name);');

    // 7. chat_conversations
    batch.execute('''
      CREATE TABLE chat_conversations (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_updated TEXT NOT NULL
      );
    ''');
    batch.execute('CREATE INDEX idx_conversations_user ON chat_conversations(user_id);');

    // 8. chat_messages
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
    batch.execute('CREATE INDEX idx_messages_conversation ON chat_messages(conversation_id);');
    batch.execute('CREATE INDEX idx_messages_user ON chat_messages(user_id);');

    // 9. activity_records
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
    batch.execute('CREATE INDEX idx_activity_user ON activity_records(user_id);');
    batch.execute('CREATE INDEX idx_activity_date ON activity_records(date);');

    // 10. sleep_records
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
    batch.execute('CREATE INDEX idx_sleep_user ON sleep_records(user_id);');
    batch.execute('CREATE INDEX idx_sleep_date ON sleep_records(date);');

    // 11. hydration_records
    batch.execute('''
      CREATE TABLE hydration_records (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        intake_ml INTEGER NOT NULL,
        target_ml INTEGER NOT NULL
      );
    ''');
    batch.execute('CREATE INDEX idx_hydration_user ON hydration_records(user_id);');

    // 12. nutrition_goals
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
    batch.execute('CREATE INDEX idx_goals_user ON nutrition_goals(user_id);');

    // 13. recommendation_history
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
    batch.execute('CREATE INDEX idx_recommendations_user ON recommendation_history(user_id);');

    await batch.commit();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations for future versions cleanly
  }

  /// Close database connection safely
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  /// Reset singleton for testing or clean setup
  static void resetForTesting() {
    _database = null;
    _instance = null;
  }
}
