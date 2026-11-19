import 'package:equatable/equatable.dart';

enum FactorSeverity { low, moderate, elevated }

class ContributingFactor extends Equatable {
  final String name;
  final String evidence;
  final String interpretation;
  final String recommendation;
  final FactorSeverity severity;

  const ContributingFactor({
    required this.name,
    required this.evidence,
    required this.interpretation,
    required this.recommendation,
    required this.severity,
  });

  @override
  List<Object?> get props => [name, evidence, interpretation, recommendation, severity];
}

class HealthRecommendation extends Equatable {
  final String title;
  final String description;
  final String rationale;
  final String category;
  final String evidence;

  const HealthRecommendation({
    required this.title,
    required this.description,
    required this.rationale,
    required this.category,
    required this.evidence,
  });

  @override
  List<Object?> get props => [title, description, rationale, category, evidence];
}

class HealthPlanItem extends Equatable {
  final String domain; // Nutrition, Activity, Behavioral, Stress, Monitoring
  final String goal;
  final String action;
  final String frequency;
  final String rationale;
  final String evidence;

  const HealthPlanItem({
    required this.domain,
    required this.goal,
    required this.action,
    required this.frequency,
    required this.rationale,
    required this.evidence,
  });

  @override
  List<Object?> get props => [domain, goal, action, frequency, rationale, evidence];
}

class MealOption extends Equatable {
  final String mealType; // Breakfast, Lunch, etc.
  final String dishName;
  final String portion;
  final String description;

  const MealOption({
    required this.mealType,
    required this.dishName,
    required this.portion,
    required this.description,
  });

  @override
  List<Object?> get props => [mealType, dishName, portion, description];
}

enum ScreeningConcern { lower, moderate, elevated }

class HealthAnalysis extends Equatable {
  final ScreeningConcern overallConcern;
  final double? estimatedBmr;
  final double? estimatedDailyEnergy;
  final List<ContributingFactor> behavioralFactors;
  final List<HealthRecommendation> recommendations;
  final List<HealthPlanItem> personalizedPlan;
  final List<MealOption> nutritionPlan;
  final String summary;

  const HealthAnalysis({
    required this.overallConcern,
    this.estimatedBmr,
    this.estimatedDailyEnergy,
    required this.behavioralFactors,
    required this.recommendations,
    required this.personalizedPlan,
    required this.nutritionPlan,
    required this.summary,
  });

  @override
  List<Object?> get props => [
        overallConcern,
        estimatedBmr,
        estimatedDailyEnergy,
        behavioralFactors,
        recommendations,
        personalizedPlan,
        nutritionPlan,
        summary,
      ];
}
