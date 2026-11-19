import 'package:flutter_test/flutter_test.dart';
import 'package:oasyara_1/features/analysis/domain/models/analysis_models.dart';
import 'package:oasyara_1/features/analysis/domain/services/analysis_engine.dart';
import 'package:oasyara_1/features/health/domain/models/health_models.dart';

void main() {
  group('Analysis Engine Logic Tests', () {
    final engine = AnalysisEngine();

    test('BMR calculation is correct for Male', () {
      final profile = HealthProfile(
        userId: 'test',
        name: 'Test',
        dateOfBirth: DateTime(1996, 1, 1), // Fixed birth date
        gender: 'Male',
        heightCm: 180,
        currentWeightKg: 80,
        targetWeightKg: 75,
        activityLevel: 'Sedentary',
        stressLevel: 'Low',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      // Manual calculation based on 2026-08-20 current time:
      // Age = 2026 - 1996 = 30
      // BMR Men: (10 × 80) + (6.25 × 180) - (5 × 30) + 5 = 800 + 1125 - 150 + 5 = 1780
      final analysis = engine.analyze(profile: profile, measurements: [], assessment: null);
      expect(analysis.estimatedBmr, 1780);
    });

    test('Identifies factors from assessment answers', () {
      final profile = HealthProfile(
        userId: 'test',
        name: 'Test',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 30)),
        gender: 'Female',
        heightCm: 165,
        currentWeightKg: 75,
        targetWeightKg: 65,
        activityLevel: 'Lightly Active',
        stressLevel: 'Low',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      final assessment = HealthAssessment(
        id: 'a1',
        userId: 'test',
        date: DateTime.now(),
        responses: const [
          AssessmentResponse(questionId: 'q4', response: 'More than 8 hours'), // Prolonged Sedentary
          AssessmentResponse(questionId: 'q6', response: 'Often'), // Irregular Eating
        ],
      );

      final analysis = engine.analyze(profile: profile, measurements: [], assessment: assessment);
      
      final factorNames = analysis.behavioralFactors.map((f) => f.name).toList();
      expect(factorNames, contains('Prolonged Sedentary Behavior'));
      expect(factorNames, contains('Irregular Eating Patterns'));
    });

    test('Calculates screening concern correctly', () {
       // Elevated: BMI > 30 (Obesity) + 3 factors
       final profile = HealthProfile(
        userId: 'test',
        name: 'Test',
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 30)),
        gender: 'Male',
        heightCm: 170,
        currentWeightKg: 100, // BMI ~34.6
        targetWeightKg: 80,
        activityLevel: 'Sedentary', // Factor 1
        stressLevel: 'High', // Factor 2
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      final assessment = HealthAssessment(
        id: 'a1',
        userId: 'test',
        date: DateTime.now(),
        responses: const [
          AssessmentResponse(questionId: 'q4', response: 'More than 8 hours'), // Factor 3
        ],
      );

      final analysis = engine.analyze(profile: profile, measurements: [], assessment: assessment);
      expect(analysis.overallConcern, ScreeningConcern.elevated);
    });
  });
}
