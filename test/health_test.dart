import 'package:flutter_test/flutter_test.dart';
import 'package:oasyara_1/features/health/domain/models/health_models.dart';
import 'package:oasyara_1/features/health/presentation/providers/health_providers.dart';
import 'package:oasyara_1/features/health/data/repositories/mock_health_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Health Models - BMI Tests', () {
    test('BMI calculation is correct', () {
      final measurement = HealthMeasurement(
        id: '1',
        userId: 'test@example.com',
        date: DateTime.now(),
        weightKg: 70,
        heightCm: 175,
      );
      // 70 / (1.75 * 1.75) = 22.857...
      expect(measurement.bmi, closeTo(22.86, 0.1));
    });

    test('BMI categories are correct', () {
      HealthMeasurement createM(double weight) => HealthMeasurement(
            id: '1',
            userId: 't',
            date: DateTime.now(),
            weightKg: weight,
            heightCm: 175,
          );

      expect(createM(50).bmiCategory, 'Underweight');
      expect(createM(70).bmiCategory, 'Healthy weight');
      expect(createM(85).bmiCategory, 'Overweight');
      expect(createM(100).bmiCategory, 'Obesity Class I');
      expect(createM(115).bmiCategory, 'Obesity Class II');
      expect(createM(130).bmiCategory, 'Obesity Class III');
    });

    group('Health Profile Model - Serialization', () {
      test('toMap/fromMap works with all fields', () {
        final profile = HealthProfile(
          userId: 'u1',
          name: 'Test User',
          dateOfBirth: DateTime(1990, 1, 1),
          gender: 'Male',
          heightCm: 180,
          currentWeightKg: 80,
          targetWeightKg: 75,
          activityLevel: 'Active',
          stressLevel: 'Low',
          dietaryRestrictions: const ['Vegan'],
          healthGoals: const ['Muscle Gain'],
          medicalConditions: const ['None'],
          waistCircumferenceCm: 90,
        );

        final map = profile.toMap();
        final fromMap = HealthProfile.fromMap(map);

        expect(fromMap.name, 'Test User');
        expect(fromMap.gender, 'Male');
        expect(fromMap.targetWeightKg, 75);
        expect(fromMap.dietaryRestrictions, contains('Vegan'));
      });
    });
  });

  group('Health Repository - Persistence & Synchronization', () {
    late SharedPreferences prefs;
    late MockHealthRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = MockHealthRepository(prefs);
    });

    test('Saving and retrieving profile works', () async {
      final profile = HealthProfile(
        userId: 'u1',
        name: 'Persistence Test',
        dateOfBirth: DateTime(1995, 5, 5),
        gender: 'Female',
        heightCm: 165,
        currentWeightKg: 60,
        targetWeightKg: 58,
        activityLevel: 'Moderate',
        stressLevel: 'Moderate',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      await repo.saveProfile(profile);

      final retrieved = await repo.getProfile('u1');
      expect(retrieved?.name, 'Persistence Test');
      expect(retrieved?.gender, 'Female');
    });

    test('Updating profile replaces old values', () async {
      final p1 = HealthProfile(
        userId: 'u1',
        name: 'Initial Name',
        dateOfBirth: DateTime(1990, 1, 1),
        gender: 'Male',
        heightCm: 180,
        currentWeightKg: 80,
        targetWeightKg: 75,
        activityLevel: 'Active',
        stressLevel: 'Low',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      await repo.saveProfile(p1);

      final p2 = HealthProfile(
        userId: 'u1',
        name: 'Updated Name',
        dateOfBirth: DateTime(1990, 1, 1),
        gender: 'Male',
        heightCm: 180,
        currentWeightKg: 80,
        targetWeightKg: 70, // Changed
        activityLevel: 'Active',
        stressLevel: 'Low',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      await repo.saveProfile(p2);

      final retrieved = await repo.getProfile('u1');
      expect(retrieved?.name, 'Updated Name');
      expect(retrieved?.targetWeightKg, 70);
    });

    test('Data is user-specific', () async {
      final p1 = HealthProfile(
        userId: 'user1',
        name: 'User One',
        dateOfBirth: DateTime(1990, 1, 1),
        gender: 'Male',
        heightCm: 180,
        currentWeightKg: 80,
        targetWeightKg: 75,
        activityLevel: 'Active',
        stressLevel: 'Low',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      final p2 = HealthProfile(
        userId: 'user2',
        name: 'User Two',
        dateOfBirth: DateTime(1992, 2, 2),
        gender: 'Female',
        heightCm: 160,
        currentWeightKg: 55,
        targetWeightKg: 52,
        activityLevel: 'Sedentary',
        stressLevel: 'High',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      await repo.saveProfile(p1);
      await repo.saveProfile(p2);

      final r1 = await repo.getProfile('user1');
      final r2 = await repo.getProfile('user2');

      expect(r1?.name, 'User One');
      expect(r2?.name, 'User Two');
    });

    test('Adding measurement updates profile weight', () async {
      final profile = HealthProfile(
        userId: 'u1',
        name: 'Sync Test',
        dateOfBirth: DateTime(1990, 1, 1),
        gender: 'Male',
        heightCm: 180,
        currentWeightKg: 80,
        targetWeightKg: 75,
        activityLevel: 'Active',
        stressLevel: 'Low',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      await repo.saveProfile(profile);

      final measurement = HealthMeasurement(
        id: 'm1',
        userId: 'u1',
        date: DateTime.now(),
        weightKg: 82, // New weight
        heightCm: 180,
      );

      await repo.addMeasurement(measurement);

      final updatedProfile = await repo.getProfile('u1');
      expect(updatedProfile?.currentWeightKg, 82);
    });

    test('saveProfile creates a new measurement on height/weight change', () async {
      final p1 = HealthProfile(
        userId: 'u1',
        name: 'T',
        dateOfBirth: DateTime(1990, 1, 1),
        gender: 'Male',
        heightCm: 170,
        currentWeightKg: 70,
        targetWeightKg: 65,
        activityLevel: 'Active',
        stressLevel: 'Low',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      await repo.saveProfile(p1);
      
      var measurements = await repo.getMeasurements('u1');
      expect(measurements.length, 1);
      expect(measurements.first.heightCm, 170);

      final p2 = HealthProfile(
        userId: 'u1',
        name: 'T',
        dateOfBirth: DateTime(1990, 1, 1),
        gender: 'Male',
        heightCm: 180, // Changed
        currentWeightKg: 70,
        targetWeightKg: 65,
        activityLevel: 'Active',
        stressLevel: 'Low',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      await repo.saveProfile(p2);
      
      measurements = await repo.getMeasurements('u1');
      expect(measurements.length, 2);
      expect(measurements.last.heightCm, 180);
    });
  });

  group('Health Assessment Logic', () {
    test('Assessment generation selects exactly 10 questions', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = MockHealthRepository(prefs);
      final notifier = HealthAssessmentNotifier(repo, 'test@example.com');

      final questions = await notifier.generateDynamicAssessment();
      expect(questions.length, 10);
    });
  });
}
