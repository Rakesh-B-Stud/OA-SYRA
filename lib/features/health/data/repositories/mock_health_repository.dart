import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/health_models.dart';
import '../../domain/repositories/health_repository.dart';

class MockHealthRepository implements HealthProfileRepository, HealthMetricsRepository, HealthAssessmentRepository {
  final SharedPreferences _prefs;
  FirebaseFirestore? _firestore;

  MockHealthRepository(this._prefs) {
    try {
      _firestore = FirebaseFirestore.instance;
    } catch (_) {}
  }

  String _cleanUserId(String userId) => userId.trim().replaceAll('.', '_');
  String _profileKey(String userId) => 'health_profile_${_cleanUserId(userId)}';
  String _measurementsKey(String userId) => 'health_measurements_${_cleanUserId(userId)}';
  String _assessmentKey(String userId) => 'health_assessment_${_cleanUserId(userId)}';

  @override
  Future<HealthProfile?> getProfile(String userId) async {
    final primaryData = _prefs.getString(_profileKey(userId));
    if (primaryData != null) {
      return HealthProfile.fromJson(primaryData);
    }

    // Check legacy uncleaned key if different
    final legacyKey = 'health_profile_$userId';
    final legacyData = _prefs.getString(legacyKey);
    if (legacyData != null) {
      final p = HealthProfile.fromJson(legacyData);
      await _prefs.setString(_profileKey(userId), p.toJson());
      return p;
    }

    if (_firestore != null) {
      try {
        final doc = await _firestore!
            .collection('users')
            .doc(_cleanUserId(userId))
            .collection('health')
            .doc('profile')
            .get();

        if (doc.exists && doc.data() != null) {
          final profile = HealthProfile.fromMap(doc.data()!);
          await _prefs.setString(_profileKey(userId), profile.toJson());
          return profile;
        }
      } catch (_) {}
    }

    return null;
  }

  @override
  Future<void> saveProfile(HealthProfile profile) async {
    await _prefs.setString(_profileKey(profile.userId), profile.toJson());

    if (_firestore != null) {
      try {
        await _firestore!
            .collection('users')
            .doc(_cleanUserId(profile.userId))
            .collection('health')
            .doc('profile')
            .set(profile.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }

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

  @override
  Future<List<HealthMeasurement>> getMeasurements(String userId) async {
    final data = _prefs.getStringList(_measurementsKey(userId)) ?? _prefs.getStringList('health_measurements_$userId');
    List<HealthMeasurement> localList = [];
    if (data != null) {
      localList = data.map((e) => HealthMeasurement.fromMap(json.decode(e))).toList();
    }

    if (_firestore != null && localList.isEmpty) {
      try {
        final querySnapshot = await _firestore!
            .collection('users')
            .doc(_cleanUserId(userId))
            .collection('measurements')
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final cloudMeasurements = querySnapshot.docs
              .map((doc) => HealthMeasurement.fromMap(doc.data()))
              .toList();

          final updatedData = cloudMeasurements.map((e) => json.encode(e.toMap())).toList();
          await _prefs.setStringList(_measurementsKey(userId), updatedData);
          return cloudMeasurements;
        }
      } catch (_) {}
    }

    return localList;
  }

  @override
  Future<void> addMeasurement(HealthMeasurement measurement) async {
    final List<HealthMeasurement> current = await getMeasurements(measurement.userId);
    current.add(measurement);

    final data = current.map((e) => json.encode(e.toMap())).toList();
    await _prefs.setStringList(_measurementsKey(measurement.userId), data);

    if (_firestore != null) {
      try {
        await _firestore!
            .collection('users')
            .doc(_cleanUserId(measurement.userId))
            .collection('measurements')
            .doc(measurement.id)
            .set(measurement.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }

    final profile = await getProfile(measurement.userId);
    if (profile != null) {
      final updatedProfile = HealthProfile(
        userId: profile.userId,
        name: profile.name,
        dateOfBirth: profile.dateOfBirth,
        gender: profile.gender,
        heightCm: measurement.heightCm,
        currentWeightKg: measurement.weightKg,
        targetWeightKg: profile.targetWeightKg,
        activityLevel: profile.activityLevel,
        stressLevel: profile.stressLevel,
        dietaryRestrictions: profile.dietaryRestrictions,
        healthGoals: profile.healthGoals,
        medicalConditions: profile.medicalConditions,
        waistCircumferenceCm: measurement.waistCircumferenceCm,
      );
      await saveProfile(updatedProfile);
    }
  }

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
    await _prefs.setString(_assessmentKey(assessment.userId), json.encode(assessment.toMap()));

    if (_firestore != null) {
      try {
        await _firestore!
            .collection('users')
            .doc(_cleanUserId(assessment.userId))
            .collection('assessments')
            .doc(assessment.id)
            .set(assessment.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  @override
  Future<HealthAssessment?> getLatestAssessment(String userId) async {
    final data = _prefs.getString(_assessmentKey(userId)) ?? _prefs.getString('health_assessment_$userId');
    if (data != null) {
      return HealthAssessment.fromMap(json.decode(data));
    }

    if (_firestore != null) {
      try {
        final querySnapshot = await _firestore!
            .collection('users')
            .doc(_cleanUserId(userId))
            .collection('assessments')
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final assessments = querySnapshot.docs
              .map((doc) => HealthAssessment.fromMap(doc.data()))
              .toList();

          assessments.sort((a, b) => b.date.compareTo(a.date));
          final latest = assessments.first;
          await _prefs.setString(_assessmentKey(userId), json.encode(latest.toMap()));
          return latest;
        }
      } catch (_) {}
    }

    return null;
  }
}
