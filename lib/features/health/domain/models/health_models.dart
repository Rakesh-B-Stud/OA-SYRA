import 'dart:convert';
import 'package:equatable/equatable.dart';

class HealthProfile extends Equatable {
  final String userId;
  final String name;
  final DateTime dateOfBirth;
  final String gender;
  final double heightCm;
  final double currentWeightKg;
  final double targetWeightKg;
  final String activityLevel;
  final String stressLevel;
  final List<String> dietaryRestrictions;
  final List<String> healthGoals;
  final List<String> medicalConditions;
  final double? waistCircumferenceCm;
  
  // Phase 3 Enhancements: Nutrition Preferences
  final String? cuisinePreference; // South Indian, North Indian, etc.
  final String? dietType; // Vegetarian, Non-Vegetarian, Eggetarian, Vegan

  const HealthProfile({
    required this.userId,
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    required this.heightCm,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.activityLevel,
    required this.stressLevel,
    required this.dietaryRestrictions,
    required this.healthGoals,
    required this.medicalConditions,
    this.waistCircumferenceCm,
    this.cuisinePreference = 'General Indian',
    this.dietType = 'Vegetarian',
  });

  @override
  List<Object?> get props => [
        userId,
        name,
        dateOfBirth,
        gender,
        heightCm,
        currentWeightKg,
        targetWeightKg,
        activityLevel,
        stressLevel,
        dietaryRestrictions,
        healthGoals,
        medicalConditions,
        waistCircumferenceCm,
        cuisinePreference,
        dietType,
      ];

  double get bmi {
    final heightM = heightCm / 100;
    if (heightM <= 0) return 0;
    return currentWeightKg / (heightM * heightM);
  }

  String get bmiCategory {
    final value = bmi;
    if (value < 18.5) return 'Underweight';
    if (value < 25.0) return 'Healthy weight';
    if (value < 30.0) return 'Overweight';
    if (value < 35.0) return 'Obesity Class I';
    if (value < 40.0) return 'Obesity Class II';
    return 'Obesity Class III';
  }

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'heightCm': heightCm,
      'currentWeightKg': currentWeightKg,
      'targetWeightKg': targetWeightKg,
      'activityLevel': activityLevel,
      'stressLevel': stressLevel,
      'dietaryRestrictions': dietaryRestrictions,
      'healthGoals': healthGoals,
      'medicalConditions': medicalConditions,
      'waistCircumferenceCm': waistCircumferenceCm,
      'cuisinePreference': cuisinePreference,
      'dietType': dietType,
    };
  }

  factory HealthProfile.fromMap(Map<String, dynamic> map) {
    return HealthProfile(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      dateOfBirth: DateTime.parse(map['dateOfBirth']),
      gender: map['gender'] ?? 'Other',
      heightCm: (map['heightCm'] as num).toDouble(),
      currentWeightKg: (map['currentWeightKg'] as num).toDouble(),
      targetWeightKg: (map['targetWeightKg'] as num).toDouble(),
      activityLevel: map['activityLevel'] ?? 'Sedentary',
      stressLevel: map['stressLevel'] ?? 'Low',
      dietaryRestrictions: List<String>.from(map['dietaryRestrictions'] ?? []),
      healthGoals: List<String>.from(map['healthGoals'] ?? []),
      medicalConditions: List<String>.from(map['medicalConditions'] ?? []),
      waistCircumferenceCm: map['waistCircumferenceCm'] != null ? (map['waistCircumferenceCm'] as num).toDouble() : null,
      cuisinePreference: map['cuisinePreference'] ?? 'General Indian',
      dietType: map['dietType'] ?? 'Vegetarian',
    );
  }

  String toJson() => json.encode(toMap());
  factory HealthProfile.fromJson(String source) => HealthProfile.fromMap(json.decode(source));
}

class HealthMeasurement extends Equatable {
  final String id;
  final String userId;
  final DateTime date;
  final double weightKg;
  final double heightCm;
  final double? waistCircumferenceCm;

  const HealthMeasurement({
    required this.id,
    required this.userId,
    required this.date,
    required this.weightKg,
    required this.heightCm,
    this.waistCircumferenceCm,
  });

  @override
  List<Object?> get props => [id, userId, date, weightKg, heightCm, waistCircumferenceCm];

  double get bmi {
    final heightM = heightCm / 100;
    if (heightM <= 0) return 0;
    return weightKg / (heightM * heightM);
  }

  String get bmiCategory {
    final value = bmi;
    if (value < 18.5) return 'Underweight';
    if (value < 25.0) return 'Healthy weight';
    if (value < 30.0) return 'Overweight';
    if (value < 35.0) return 'Obesity Class I';
    if (value < 40.0) return 'Obesity Class II';
    return 'Obesity Class III';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'weightKg': weightKg,
      'heightCm': heightCm,
      'waistCircumferenceCm': waistCircumferenceCm,
    };
  }

  factory HealthMeasurement.fromMap(Map<String, dynamic> map) {
    return HealthMeasurement(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      date: DateTime.parse(map['date']),
      weightKg: (map['weightKg'] as num).toDouble(),
      heightCm: (map['heightCm'] as num).toDouble(),
      waistCircumferenceCm: map['waistCircumferenceCm'] != null ? (map['waistCircumferenceCm'] as num).toDouble() : null,
    );
  }
}

enum AssessmentCategory {
  weightHistory,
  physicalActivity,
  sedentaryBehavior,
  dietaryPatterns,
  eatingBehavior,
  sleep,
  familyHistory,
  comorbidities,
  medications,
  lifestyle,
}

class AssessmentQuestion extends Equatable {
  final String id;
  final String text;
  final AssessmentCategory category;
  final List<String> options;
  final bool isRequired;

  const AssessmentQuestion({
    required this.id,
    required this.text,
    required this.category,
    required this.options,
    this.isRequired = true,
  });

  @override
  List<Object?> get props => [id, text, category, options, isRequired];
}

class AssessmentResponse extends Equatable {
  final String questionId;
  final String response;

  const AssessmentResponse({
    required this.questionId,
    required this.response,
  });

  @override
  List<Object?> get props => [questionId, response];

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'response': response,
    };
  }

  factory AssessmentResponse.fromMap(Map<String, dynamic> map) {
    return AssessmentResponse(
      questionId: map['questionId'] ?? '',
      response: map['response'] ?? '',
    );
  }
}

class HealthAssessment extends Equatable {
  final String id;
  final String userId;
  final DateTime date;
  final List<AssessmentResponse> responses;

  const HealthAssessment({
    required this.id,
    required this.userId,
    required this.date,
    required this.responses,
  });

  @override
  List<Object?> get props => [id, userId, date, responses];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'responses': responses.map((x) => x.toMap()).toList(),
    };
  }

  factory HealthAssessment.fromMap(Map<String, dynamic> map) {
    return HealthAssessment(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      date: DateTime.parse(map['date']),
      responses: List<AssessmentResponse>.from(map['responses']?.map((x) => AssessmentResponse.fromMap(x)) ?? []),
    );
  }
}
