import 'dart:convert';
import '../../../../core/database/app_database.dart';
import '../../domain/models/health_models.dart';
import '../../domain/repositories/health_repository.dart';

class SQLiteHealthRepository implements HealthProfileRepository, HealthMetricsRepository, HealthAssessmentRepository {
  final AppDatabase _appDatabase;

  SQLiteHealthRepository(this._appDatabase);

  String _cleanUserId(String userId) => userId.trim().replaceAll('.', '_');

  // --- HealthProfileRepository ---

  @override
  Future<HealthProfile?> getProfile(String userId) async {
    final cleanId = _cleanUserId(userId);
    final db = await _appDatabase.database;

    final rows = await db.query(
      'health_profiles',
      where: 'user_id = ?',
      whereArgs: [cleanId],
    );

    if (rows.isNotEmpty) {
      return _profileFromRow(rows.first);
    }

    if (userId != cleanId) {
      final rawRows = await db.query(
        'health_profiles',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (rawRows.isNotEmpty) {
        return _profileFromRow(rawRows.first);
      }
    }

    return null;
  }

  @override
  Future<void> saveProfile(HealthProfile profile) async {
    final cleanId = _cleanUserId(profile.userId);
    final db = await _appDatabase.database;
    final now = DateTime.now().toIso8601String();

    await db.rawInsert('''
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
      cleanId,
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
      now,
      now,
    ]);

    final measurements = await getMeasurements(profile.userId);
    bool shouldAddMeasurement = false;

    if (measurements.isEmpty) {
      shouldAddMeasurement = true;
    } else {
      final latest = measurements.last;
      if (latest.weightKg != profile.currentWeightKg || latest.heightCm != profile.heightCm) {
        shouldAddMeasurement = true;
      }
    }

    if (shouldAddMeasurement) {
      await addMeasurement(HealthMeasurement(
        id: DateTime.now().toIso8601String(),
        userId: profile.userId,
        date: DateTime.now(),
        weightKg: profile.currentWeightKg,
        heightCm: profile.heightCm,
        waistCircumferenceCm: profile.waistCircumferenceCm,
      ));
    }
  }

  HealthProfile _profileFromRow(Map<String, dynamic> row) {
    return HealthProfile(
      userId: row['user_id'] as String,
      name: row['name'] as String,
      dateOfBirth: DateTime.parse(row['date_of_birth'] as String),
      gender: row['gender'] as String,
      heightCm: (row['height_cm'] as num).toDouble(),
      currentWeightKg: (row['current_weight_kg'] as num).toDouble(),
      targetWeightKg: (row['target_weight_kg'] as num).toDouble(),
      activityLevel: row['activity_level'] as String,
      stressLevel: row['stress_level'] as String,
      dietaryRestrictions: List<String>.from(json.decode(row['dietary_restrictions'] as String? ?? '[]')),
      healthGoals: List<String>.from(json.decode(row['health_goals'] as String? ?? '[]')),
      medicalConditions: List<String>.from(json.decode(row['medical_conditions'] as String? ?? '[]')),
      waistCircumferenceCm: row['waist_circumference_cm'] != null ? (row['waist_circumference_cm'] as num).toDouble() : null,
      cuisinePreference: row['cuisine_preference'] as String? ?? 'General Indian',
      dietType: row['diet_type'] as String? ?? 'Vegetarian',
    );
  }

  // --- HealthMetricsRepository ---

  @override
  Future<List<HealthMeasurement>> getMeasurements(String userId) async {
    final cleanId = _cleanUserId(userId);
    final db = await _appDatabase.database;

    final rows = await db.query(
      'health_measurements',
      where: 'user_id = ? OR user_id = ?',
      whereArgs: [cleanId, userId],
      orderBy: 'date ASC',
    );

    return rows.map((r) => HealthMeasurement(
      id: r['id'] as String,
      userId: r['user_id'] as String,
      date: DateTime.parse(r['date'] as String),
      weightKg: (r['weight_kg'] as num).toDouble(),
      heightCm: (r['height_cm'] as num).toDouble(),
      waistCircumferenceCm: r['waist_circumference_cm'] != null ? (r['waist_circumference_cm'] as num).toDouble() : null,
    )).toList();
  }

  @override
  Future<void> addMeasurement(HealthMeasurement measurement) async {
    final cleanId = _cleanUserId(measurement.userId);
    final db = await _appDatabase.database;

    await db.rawInsert('''
      INSERT OR IGNORE INTO health_measurements (
        id, user_id, date, weight_kg, height_cm, waist_circumference_cm
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      measurement.id,
      cleanId,
      measurement.date.toIso8601String(),
      measurement.weightKg,
      measurement.heightCm,
      measurement.waistCircumferenceCm,
    ]);
  }

  Future<void> deleteMeasurement(String userId, String id) async {
    final db = await _appDatabase.database;
    await db.delete(
      'health_measurements',
      where: 'id = ? AND (user_id = ? OR user_id = ?)',
      whereArgs: [id, userId, _cleanUserId(userId)],
    );
  }

  // --- HealthAssessmentRepository ---

  @override
  Future<List<AssessmentQuestion>> getQuestionBank() async {
    return [
      AssessmentQuestion(
        id: 'q1',
        text: 'Has your weight changed significantly during the past 6–12 months?',
        category: AssessmentCategory.weightHistory,
        options: ['No significant change', 'Significant gain', 'Significant loss', 'Fluctuating'],
      ),
      AssessmentQuestion(
        id: 'q2',
        text: 'Have you previously tried to lose weight? If yes, what was the outcome?',
        category: AssessmentCategory.weightHistory,
        options: ['Never tried', 'Successful (maintained)', 'Successful (regained)', 'Unsuccessful'],
      ),
      AssessmentQuestion(
        id: 'q3',
        text: 'On average, how many days per week do you engage in moderate or vigorous physical activity?',
        category: AssessmentCategory.physicalActivity,
        options: ['0 days', '1-2 days', '3-4 days', '5+ days'],
      ),
      AssessmentQuestion(
        id: 'q4',
        text: 'On a typical day, approximately how many hours do you spend sitting or otherwise physically inactive?',
        category: AssessmentCategory.sedentaryBehavior,
        options: ['Less than 4 hours', '4-6 hours', '6-8 hours', 'More than 8 hours'],
      ),
      AssessmentQuestion(
        id: 'q5',
        text: 'How frequently do you consume sugar-sweetened beverages or highly processed/high-calorie foods?',
        category: AssessmentCategory.dietaryPatterns,
        options: ['Rarely/Never', '1-2 times per week', '3-5 times per week', 'Daily'],
      ),
      AssessmentQuestion(
        id: 'q6',
        text: 'Do you sometimes experience episodes of eating unusually large amounts of food accompanied by a feeling that you cannot control the eating?',
        category: AssessmentCategory.eatingBehavior,
        options: ['Never', 'Rarely', 'Sometimes', 'Often'],
      ),
      AssessmentQuestion(
        id: 'q7',
        text: 'Does your immediate family have a history of obesity, type 2 diabetes, high blood pressure, or cardiovascular disease?',
        category: AssessmentCategory.familyHistory,
        options: ['No history', 'One parent/sibling', 'Both parents', 'Extended family only'],
      ),
      AssessmentQuestion(
        id: 'q8',
        text: 'Have you ever been diagnosed by a healthcare professional with conditions such as type 2 diabetes, hypertension, fatty liver disease, etc?',
        category: AssessmentCategory.comorbidities,
        options: ['None', 'One condition', 'Multiple conditions', 'Prefer not to say'],
      ),
      AssessmentQuestion(
        id: 'q9',
        text: 'Are you currently taking any medications that a healthcare professional has told you may affect your weight?',
        category: AssessmentCategory.medications,
        options: ['No', 'Yes', 'Not sure', 'Prefer not to say'],
      ),
      AssessmentQuestion(
        id: 'q10',
        text: 'How many hours do you usually sleep per night, and do you experience symptoms such as loud snoring?',
        category: AssessmentCategory.sleep,
        options: ['7-9 hours (Good quality)', 'Less than 6 hours', 'More than 9 hours', 'Poor quality/Snoring'],
      ),
      AssessmentQuestion(
        id: 'q11',
        text: 'How often do you prepare meals at home versus eating out or ordering takeout?',
        category: AssessmentCategory.dietaryPatterns,
        options: ['Mostly home-cooked', 'Half and half', 'Mostly eating out', 'Exclusively eating out'],
      ),
      AssessmentQuestion(
        id: 'q12',
        text: 'How would you rate your typical stress levels on a daily basis?',
        category: AssessmentCategory.lifestyle,
        options: ['Low', 'Moderate', 'High', 'Very High'],
      ),
    ];
  }

  @override
  Future<void> saveAssessment(HealthAssessment assessment) async {
    final cleanId = _cleanUserId(assessment.userId);
    final db = await _appDatabase.database;

    await db.rawInsert('''
      INSERT OR IGNORE INTO health_assessments (
        id, user_id, date, responses_json
      ) VALUES (?, ?, ?, ?)
    ''', [
      assessment.id,
      cleanId,
      assessment.date.toIso8601String(),
      json.encode(assessment.responses.map((r) => r.toMap()).toList()),
    ]);
  }

  @override
  Future<HealthAssessment?> getLatestAssessment(String userId) async {
    final cleanId = _cleanUserId(userId);
    final db = await _appDatabase.database;

    final rows = await db.query(
      'health_assessments',
      where: 'user_id = ? OR user_id = ?',
      whereArgs: [cleanId, userId],
      orderBy: 'date DESC',
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final r = rows.first;
      final responsesRaw = json.decode(r['responses_json'] as String) as List;
      return HealthAssessment(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        date: DateTime.parse(r['date'] as String),
        responses: responsesRaw.map((x) => AssessmentResponse.fromMap(x as Map<String, dynamic>)).toList(),
      );
    }

    return null;
  }
}
