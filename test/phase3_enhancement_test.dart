import 'package:flutter_test/flutter_test.dart';
import 'package:oasyara_1/features/analysis/domain/services/analysis_engine.dart';
import 'package:oasyara_1/features/health/domain/models/health_models.dart';

void main() {
  group('Phase 3 Enhancement Tests - Personalized Plan & Nutrition', () {
    final engine = AnalysisEngine();

    test('Generates South Indian Vegetarian plan correctly', () {
      final profile = HealthProfile(
        userId: 'u1',
        name: 'South Veg User',
        dateOfBirth: DateTime(1990, 1, 1),
        gender: 'Female',
        heightCm: 160,
        currentWeightKg: 65,
        targetWeightKg: 60,
        activityLevel: 'Sedentary',
        stressLevel: 'Low',
        dietaryRestrictions: const [],
        healthGoals: const ['Weight Loss'],
        medicalConditions: const [],
        cuisinePreference: 'South Indian',
        dietType: 'Vegetarian',
      );

      final analysis = engine.analyze(profile: profile, measurements: [], assessment: null);
      
      // Check Nutrition Plan
      final breakfast = analysis.nutritionPlan.firstWhere((m) => m.mealType == 'Breakfast');
      expect(breakfast.dishName, contains('Idli'));
      
      final lunch = analysis.nutritionPlan.firstWhere((m) => m.mealType == 'Lunch');
      expect(lunch.dishName, contains('Rice'));
      expect(lunch.dishName, anyOf(contains('Paneer'), contains('Dal')));
    });

    test('Generates North Indian Non-Vegetarian plan correctly', () {
      final profile = HealthProfile(
        userId: 'u2',
        name: 'North NonVeg User',
        dateOfBirth: DateTime(1985, 5, 10),
        gender: 'Male',
        heightCm: 175,
        currentWeightKg: 85,
        targetWeightKg: 75,
        activityLevel: 'Moderately Active',
        stressLevel: 'Moderate',
        dietaryRestrictions: const [],
        healthGoals: const ['Muscle Gain'],
        medicalConditions: const [],
        cuisinePreference: 'North Indian',
        dietType: 'Non-Vegetarian',
      );

      final analysis = engine.analyze(profile: profile, measurements: [], assessment: null);
      
      // Check Nutrition Plan
      final breakfast = analysis.nutritionPlan.firstWhere((m) => m.mealType == 'Breakfast');
      expect(breakfast.dishName, contains('Paratha'));
      
      final lunch = analysis.nutritionPlan.firstWhere((m) => m.mealType == 'Lunch');
      expect(lunch.dishName, contains('Chicken'));
    });

    test('Plan includes multiple domains based on factors', () {
      final profile = HealthProfile(
        userId: 'u3',
        name: 'Complex User',
        dateOfBirth: DateTime(1992, 10, 15),
        gender: 'Female',
        heightCm: 165,
        currentWeightKg: 78,
        targetWeightKg: 65,
        activityLevel: 'Sedentary',
        stressLevel: 'High', // Factor 1: Stress
        dietaryRestrictions: const [],
        healthGoals: const ['Health Improvement'],
        medicalConditions: const [],
      );

      final assessment = HealthAssessment(
        id: 'a1',
        userId: 'u3',
        date: DateTime.now(),
        responses: const [
          AssessmentResponse(questionId: 'q6', response: 'Sometimes'), // Factor 2: Irregular Eating
          AssessmentResponse(questionId: 'q10', response: 'Less than 6 hours'), // Factor 3: Sleep
        ],
      );

      final analysis = engine.analyze(profile: profile, measurements: [], assessment: assessment);
      
      final domains = analysis.personalizedPlan.map((p) => p.domain).toSet();
      
      expect(domains, contains('Activity')); // From sedentary profile
      expect(domains, contains('Behavioral')); // From high stress
      expect(domains, contains('Nutrition')); // From irregular eating
      expect(domains, contains('Habit')); // From sleep disruption
      expect(domains, contains('Monitoring')); // Default
    });

    test('Recommendations include explainable evidence', () {
      final profile = HealthProfile(
        userId: 'u4',
        name: 'Evidence User',
        dateOfBirth: DateTime(1990, 1, 1),
        gender: 'Male',
        heightCm: 180,
        currentWeightKg: 95,
        targetWeightKg: 85,
        activityLevel: 'Sedentary',
        stressLevel: 'Low',
        dietaryRestrictions: const [],
        healthGoals: const [],
        medicalConditions: const [],
      );

      final analysis = engine.analyze(profile: profile, measurements: [], assessment: null);
      
      final activityRec = analysis.recommendations.firstWhere((r) => r.title.contains('Low Physical Activity'));
      expect(activityRec.evidence, contains('sedentary lifestyle'));
      expect(activityRec.rationale, contains('lower metabolic rate'));
    });

    test('Vegan restriction removes dairy from plan', () {
      final profile = HealthProfile(
        userId: 'u5',
        name: 'Vegan User',
        dateOfBirth: DateTime(1995, 1, 1),
        gender: 'Male',
        heightCm: 175,
        currentWeightKg: 70,
        targetWeightKg: 70,
        activityLevel: 'Active',
        stressLevel: 'Low',
        dietaryRestrictions: const ['Vegan'],
        healthGoals: const [],
        medicalConditions: const [],
        cuisinePreference: 'North Indian',
        dietType: 'Vegan',
      );

      final analysis = engine.analyze(profile: profile, measurements: [], assessment: null);
      
      for (var meal in analysis.nutritionPlan) {
        expect(meal.dishName, isNot(contains('Paneer')));
        expect(meal.dishName, isNot(contains('Curd')));
      }
    });
  });
}
