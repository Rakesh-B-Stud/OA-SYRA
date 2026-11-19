import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import '../../features/health/domain/models/health_models.dart';
import '../../features/nutrition/domain/models/nutrition_models.dart';
import '../../features/chatbot/domain/models/chat_models.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';

final localMigrationServiceProvider = Provider<LocalMigrationService>((ref) {
  final db = AppDatabase();
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalMigrationService(db, prefs);
});

class MigrationCategoryResult {
  final String category;
  final int totalFound;
  final int migratedCount;
  final int skippedCount;
  final int failedCount;
  final List<String> diagnostics;

  const MigrationCategoryResult({
    required this.category,
    required this.totalFound,
    required this.migratedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.diagnostics,
  });
}

class UserMigrationReport {
  final String userId;
  final Map<String, MigrationCategoryResult> categoryResults;

  const UserMigrationReport({
    required this.userId,
    required this.categoryResults,
  });

  bool get isFullySuccessful => categoryResults.values.every((r) => r.failedCount == 0);
}

class LocalMigrationService {
  final AppDatabase _appDatabase;
  final SharedPreferences _prefs;

  static final Set<String> _activeMigrations = {};

  LocalMigrationService(this._appDatabase, this._prefs);

  static String profileMarkerKey(String userId) => 'sqlite_migrated_profile_$userId';
  static String measurementsMarkerKey(String userId) => 'sqlite_migrated_measurements_$userId';
  static String assessmentsMarkerKey(String userId) => 'sqlite_migrated_assessments_$userId';
  static String mealsMarkerKey(String userId) => 'sqlite_migrated_meals_$userId';
  static String chatsMarkerKey(String userId) => 'sqlite_migrated_chats_$userId';

  String _cleanUserId(String userId) => userId.trim().replaceAll('.', '_');

  Future<UserMigrationReport> migrateUser(String userId) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    final cleanId = userId.trim();

    if (_activeMigrations.contains(cleanId)) {
      return UserMigrationReport(userId: cleanId, categoryResults: {});
    }

    _activeMigrations.add(cleanId);

    try {
      final db = await _appDatabase.database;
      final results = <String, MigrationCategoryResult>{};

      results['profile'] = await _migrateProfile(db, cleanId);
      results['measurements'] = await _migrateMeasurements(db, cleanId);
      results['assessments'] = await _migrateAssessments(db, cleanId);
      results['meals'] = await _migrateMeals(db, cleanId);
      results['chats'] = await _migrateChats(db, cleanId);

      return UserMigrationReport(userId: cleanId, categoryResults: results);
    } finally {
      _activeMigrations.remove(cleanId);
    }
  }

  Future<MigrationCategoryResult> _migrateProfile(Database db, String userId) async {
    final markerKey = profileMarkerKey(userId);
    final isAlreadyMigrated = _prefs.getBool(markerKey) ?? false;

    final primaryKey = 'health_profile_$userId';
    final cleanKey = 'health_profile_${_cleanUserId(userId)}';

    final rawJson = _prefs.getString(primaryKey) ?? _prefs.getString(cleanKey);

    if (rawJson == null || rawJson.trim().isEmpty) {
      return MigrationCategoryResult(
        category: 'profile',
        totalFound: 0,
        migratedCount: 0,
        skippedCount: isAlreadyMigrated ? 1 : 0,
        failedCount: 0,
        diagnostics: const [],
      );
    }

    if (isAlreadyMigrated) {
      return MigrationCategoryResult(
        category: 'profile',
        totalFound: 1,
        migratedCount: 0,
        skippedCount: 1,
        failedCount: 0,
        diagnostics: const [],
      );
    }

    final diagnostics = <String>[];
    int migrated = 0;
    int failed = 0;

    try {
      final map = json.decode(rawJson) as Map<String, dynamic>;
      final profile = HealthProfile.fromMap(map);

      if (profile.name.isEmpty) {
        throw FormatException('HealthProfile name is empty');
      }

      await db.transaction((txn) async {
        await txn.rawInsert('''
          INSERT INTO health_profiles (
            user_id, name, date_of_birth, gender, height_cm, current_weight_kg,
            target_weight_kg, activity_level, stress_level, dietary_restrictions,
            health_goals, medical_conditions, waist_circumference_cm, cuisine_preference,
            diet_type, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(user_id) DO UPDATE SET
            name = excluded.name,
            date_of_birth = excluded.date_of_birth,
            gender = excluded.gender,
            height_cm = excluded.height_cm,
            current_weight_kg = excluded.current_weight_kg,
            target_weight_kg = excluded.target_weight_kg,
            activity_level = excluded.activity_level,
            stress_level = excluded.stress_level,
            dietary_restrictions = excluded.dietary_restrictions,
            health_goals = excluded.health_goals,
            medical_conditions = excluded.medical_conditions,
            waist_circumference_cm = excluded.waist_circumference_cm,
            cuisine_preference = excluded.cuisine_preference,
            diet_type = excluded.diet_type,
            updated_at = excluded.updated_at
        ''', [
          userId,
          profile.name,
          profile.dateOfBirth.toIso8601String(),
          profile.gender,
          profile.heightCm,
          profile.currentWeightKg,
          profile.targetWeightKg,
          profile.activityLevel,
          profile.stressLevel,
          json.encode(profile.dietaryRestrictions),
          json.encode(profile.healthGoals),
          json.encode(profile.medicalConditions),
          profile.waistCircumferenceCm,
          profile.cuisinePreference ?? 'General Indian',
          profile.dietType ?? 'Vegetarian',
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ]);
      });

      migrated = 1;
      await _prefs.setBool(markerKey, true);
    } catch (e) {
      failed = 1;
      diagnostics.add('Profile migration failed for user $userId: $e');
    }

    return MigrationCategoryResult(
      category: 'profile',
      totalFound: 1,
      migratedCount: migrated,
      skippedCount: 0,
      failedCount: failed,
      diagnostics: diagnostics,
    );
  }

  Future<MigrationCategoryResult> _migrateMeasurements(Database db, String userId) async {
    final markerKey = measurementsMarkerKey(userId);
    final isAlreadyMigrated = _prefs.getBool(markerKey) ?? false;

    final primaryKey = 'health_measurements_$userId';
    final cleanKey = 'health_measurements_${_cleanUserId(userId)}';

    final rawList = _prefs.getStringList(primaryKey) ?? _prefs.getStringList(cleanKey);

    if (rawList == null || rawList.isEmpty) {
      return MigrationCategoryResult(
        category: 'measurements',
        totalFound: 0,
        migratedCount: 0,
        skippedCount: isAlreadyMigrated ? 1 : 0,
        failedCount: 0,
        diagnostics: const [],
      );
    }

    if (isAlreadyMigrated) {
      return MigrationCategoryResult(
        category: 'measurements',
        totalFound: rawList.length,
        migratedCount: 0,
        skippedCount: rawList.length,
        failedCount: 0,
        diagnostics: const [],
      );
    }

    final diagnostics = <String>[];
    int migrated = 0;
    int failed = 0;

    try {
      await db.transaction((txn) async {
        for (var i = 0; i < rawList.length; i++) {
          try {
            final map = json.decode(rawList[i]) as Map<String, dynamic>;
            final measurement = HealthMeasurement.fromMap(map);

            if (measurement.id.isEmpty || measurement.weightKg <= 0 || measurement.heightCm <= 0) {
              throw FormatException('Invalid measurement properties at index $i');
            }

            final count = await txn.rawInsert('''
              INSERT OR IGNORE INTO health_measurements (
                id, user_id, date, weight_kg, height_cm, waist_circumference_cm
              ) VALUES (?, ?, ?, ?, ?, ?)
            ''', [
              measurement.id,
              userId,
              measurement.date.toIso8601String(),
              measurement.weightKg,
              measurement.heightCm,
              measurement.waistCircumferenceCm,
            ]);

            if (count > 0) migrated++;
          } catch (e) {
            failed++;
            diagnostics.add('Measurement index $i failed: $e');
          }
        }
      });

      if (failed == 0 || migrated > 0) {
        await _prefs.setBool(markerKey, true);
      }
    } catch (e) {
      diagnostics.add('Measurements transaction failed: $e');
    }

    return MigrationCategoryResult(
      category: 'measurements',
      totalFound: rawList.length,
      migratedCount: migrated,
      skippedCount: 0,
      failedCount: failed,
      diagnostics: diagnostics,
    );
  }

  Future<MigrationCategoryResult> _migrateAssessments(Database db, String userId) async {
    final markerKey = assessmentsMarkerKey(userId);
    final isAlreadyMigrated = _prefs.getBool(markerKey) ?? false;

    final primaryKey = 'health_assessment_$userId';
    final cleanKey = 'health_assessment_${_cleanUserId(userId)}';

    final rawJson = _prefs.getString(primaryKey) ?? _prefs.getString(cleanKey);

    if (rawJson == null || rawJson.trim().isEmpty) {
      return MigrationCategoryResult(
        category: 'assessments',
        totalFound: 0,
        migratedCount: 0,
        skippedCount: isAlreadyMigrated ? 1 : 0,
        failedCount: 0,
        diagnostics: const [],
      );
    }

    if (isAlreadyMigrated) {
      return MigrationCategoryResult(
        category: 'assessments',
        totalFound: 1,
        migratedCount: 0,
        skippedCount: 1,
        failedCount: 0,
        diagnostics: const [],
      );
    }

    final diagnostics = <String>[];
    int migrated = 0;
    int failed = 0;

    try {
      final map = json.decode(rawJson) as Map<String, dynamic>;
      final assessment = HealthAssessment.fromMap(map);

      if (assessment.id.isEmpty || assessment.responses.isEmpty) {
        throw FormatException('Assessment missing ID or responses');
      }

      await db.transaction((txn) async {
        await txn.rawInsert('''
          INSERT OR IGNORE INTO health_assessments (
            id, user_id, date, responses_json
          ) VALUES (?, ?, ?, ?)
        ''', [
          assessment.id,
          userId,
          assessment.date.toIso8601String(),
          json.encode(assessment.responses.map((r) => r.toMap()).toList()),
        ]);
      });

      migrated = 1;
      await _prefs.setBool(markerKey, true);
    } catch (e) {
      failed = 1;
      diagnostics.add('Assessment migration failed for user $userId: $e');
    }

    return MigrationCategoryResult(
      category: 'assessments',
      totalFound: 1,
      migratedCount: migrated,
      skippedCount: 0,
      failedCount: failed,
      diagnostics: diagnostics,
    );
  }

  Future<MigrationCategoryResult> _migrateMeals(Database db, String userId) async {
    final markerKey = mealsMarkerKey(userId);
    final isAlreadyMigrated = _prefs.getBool(markerKey) ?? false;

    final primaryKey = 'nutrition_meals_$userId';
    final cleanKey = 'nutrition_meals_${_cleanUserId(userId)}';

    final rawList = _prefs.getStringList(primaryKey) ?? _prefs.getStringList(cleanKey);

    if (rawList == null || rawList.isEmpty) {
      return MigrationCategoryResult(
        category: 'meals',
        totalFound: 0,
        migratedCount: 0,
        skippedCount: isAlreadyMigrated ? 1 : 0,
        failedCount: 0,
        diagnostics: const [],
      );
    }

    if (isAlreadyMigrated) {
      return MigrationCategoryResult(
        category: 'meals',
        totalFound: rawList.length,
        migratedCount: 0,
        skippedCount: rawList.length,
        failedCount: 0,
        diagnostics: const [],
      );
    }

    final diagnostics = <String>[];
    int migrated = 0;
    int failed = 0;

    try {
      await db.transaction((txn) async {
        for (var i = 0; i < rawList.length; i++) {
          try {
            final map = json.decode(rawList[i]) as Map<String, dynamic>;
            final record = MealRecord.fromMap(map);

            if (record.id.isEmpty) {
              throw FormatException('MealRecord missing ID at index $i');
            }

            final totalNut = record.totalNutrition;

            await txn.rawInsert('''
              INSERT OR IGNORE INTO meal_records (
                id, user_id, timestamp, meal_type, image_path,
                total_calories, total_protein, total_carbs, total_fat, items_json
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              record.id,
              userId,
              record.timestamp.toIso8601String(),
              record.type.name,
              record.imagePath,
              totalNut.calories,
              totalNut.protein,
              totalNut.carbohydrates,
              totalNut.fat,
              json.encode(record.items.map((it) => it.toMap()).toList()),
            ]);

            for (var itemIndex = 0; itemIndex < record.items.length; itemIndex++) {
              final item = record.items[itemIndex];
              final itemId = '${record.id}_item_$itemIndex';
              await txn.rawInsert('''
                INSERT OR IGNORE INTO meal_items (
                  id, meal_id, user_id, food_id, food_name, cuisine, diet_types_json, category,
                  calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g,
                  estimated_mass_g, confidence, portion_method, detection_label, has_disagreement, is_uncertain
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ''', [
                itemId,
                record.id,
                userId,
                item.food.id,
                item.food.name,
                item.food.cuisine,
                json.encode(item.food.dietTypes),
                item.food.category,
                item.food.nutritionPer100g.calories,
                item.food.nutritionPer100g.protein,
                item.food.nutritionPer100g.carbohydrates,
                item.food.nutritionPer100g.fat,
                item.food.nutritionPer100g.fiber,
                item.portion.estimatedMassG,
                item.portion.confidence,
                item.portion.method,
                item.food.name,
                0,
                0,
              ]);
            }

            migrated++;
          } catch (e) {
            failed++;
            diagnostics.add('MealRecord index $i failed: $e');
          }
        }
      });

      if (failed == 0 || migrated > 0) {
        await _prefs.setBool(markerKey, true);
      }
    } catch (e) {
      diagnostics.add('Meals transaction failed: $e');
    }

    return MigrationCategoryResult(
      category: 'meals',
      totalFound: rawList.length,
      migratedCount: migrated,
      skippedCount: 0,
      failedCount: failed,
      diagnostics: diagnostics,
    );
  }

  Future<MigrationCategoryResult> _migrateChats(Database db, String userId) async {
    final markerKey = chatsMarkerKey(userId);
    final isAlreadyMigrated = _prefs.getBool(markerKey) ?? false;

    final primaryKey = 'chatbot_conversations_$userId';
    final cleanKey = 'chatbot_conversations_${_cleanUserId(userId)}';

    final rawList = _prefs.getStringList(primaryKey) ?? _prefs.getStringList(cleanKey);

    if (rawList == null || rawList.isEmpty) {
      return MigrationCategoryResult(
        category: 'chats',
        totalFound: 0,
        migratedCount: 0,
        skippedCount: isAlreadyMigrated ? 1 : 0,
        failedCount: 0,
        diagnostics: const [],
      );
    }

    if (isAlreadyMigrated) {
      return MigrationCategoryResult(
        category: 'chats',
        totalFound: rawList.length,
        migratedCount: 0,
        skippedCount: rawList.length,
        failedCount: 0,
        diagnostics: const [],
      );
    }

    final diagnostics = <String>[];
    int migrated = 0;
    int failed = 0;

    try {
      await db.transaction((txn) async {
        for (var i = 0; i < rawList.length; i++) {
          try {
            final map = json.decode(rawList[i]) as Map<String, dynamic>;
            final conv = ChatConversation.fromMap(map);

            if (conv.id.isEmpty || conv.title.isEmpty) {
              throw FormatException('ChatConversation missing ID or title at index $i');
            }

            await txn.rawInsert('''
              INSERT OR IGNORE INTO chat_conversations (
                id, user_id, title, created_at, last_updated
              ) VALUES (?, ?, ?, ?, ?)
            ''', [
              conv.id,
              userId,
              conv.title,
              conv.lastUpdated.toIso8601String(),
              conv.lastUpdated.toIso8601String(),
            ]);

            for (var msgIndex = 0; msgIndex < conv.messages.length; msgIndex++) {
              final msg = conv.messages[msgIndex];
              final msgId = '${conv.id}_msg_$msgIndex';
              await txn.rawInsert('''
                INSERT OR IGNORE INTO chat_messages (
                  id, conversation_id, user_id, role, text, timestamp
                ) VALUES (?, ?, ?, ?, ?, ?)
              ''', [
                msgId,
                conv.id,
                userId,
                msg.role.name,
                msg.text,
                msg.timestamp.toIso8601String(),
              ]);
            }

            migrated++;
          } catch (e) {
            failed++;
            diagnostics.add('ChatConversation index $i failed: $e');
          }
        }
      });

      if (failed == 0 || migrated > 0) {
        await _prefs.setBool(markerKey, true);
      }
    } catch (e) {
      diagnostics.add('Chats transaction failed: $e');
    }

    return MigrationCategoryResult(
      category: 'chats',
      totalFound: rawList.length,
      migratedCount: migrated,
      skippedCount: 0,
      failedCount: failed,
      diagnostics: diagnostics,
    );
  }
}
