import '../../../health/domain/models/health_models.dart';
import '../models/analysis_models.dart';

class AnalysisEngine {
  HealthAnalysis analyze({
    required HealthProfile? profile,
    required List<HealthMeasurement> measurements,
    required HealthAssessment? assessment,
  }) {
    if (profile == null) {
      return const HealthAnalysis(
        overallConcern: ScreeningConcern.lower,
        behavioralFactors: [],
        recommendations: [],
        personalizedPlan: [],
        nutritionPlan: [],
        summary: 'Complete your health profile to receive a personalized analysis.',
      );
    }

    final factors = _identifyFactors(profile, assessment);
    final recommendations = _generateRecommendations(profile, factors);
    final plan = _generatePlan(profile, factors);
    final nutrition = _generateNutritionPlan(profile);
    
    final bmr = _calculateBmr(profile);
    final energy = _calculateEnergyNeeds(bmr, profile.activityLevel);
    
    final concern = _calculateScreeningConcern(profile, measurements, factors);
    
    final summary = _generateSummary(profile, concern, factors);

    return HealthAnalysis(
      overallConcern: concern,
      estimatedBmr: bmr,
      estimatedDailyEnergy: energy,
      behavioralFactors: factors,
      recommendations: recommendations,
      personalizedPlan: plan,
      nutritionPlan: nutrition,
      summary: summary,
    );
  }

  double? _calculateBmr(HealthProfile profile) {
    final weight = profile.currentWeightKg;
    final height = profile.heightCm;
    final age = profile.age.toDouble();
    
    if (profile.gender == 'Male') {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else if (profile.gender == 'Female') {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
    return (10 * weight) + (6.25 * height) - (5 * age) - 78;
  }

  double? _calculateEnergyNeeds(double? bmr, String activityLevel) {
    if (bmr == null) return null;
    
    double factor;
    switch (activityLevel) {
      case 'Sedentary': factor = 1.2; break;
      case 'Lightly Active': factor = 1.375; break;
      case 'Moderately Active': factor = 1.55; break;
      case 'Very Active': factor = 1.725; break;
      case 'Extra Active': factor = 1.9; break;
      default: factor = 1.2;
    }
    return bmr * factor;
  }

  List<ContributingFactor> _identifyFactors(HealthProfile profile, HealthAssessment? assessment) {
    final List<ContributingFactor> factors = [];

    if (profile.activityLevel == 'Sedentary') {
      factors.add(const ContributingFactor(
        name: 'Low Physical Activity',
        evidence: 'User profile indicates a sedentary lifestyle.',
        interpretation: 'Limited physical movement can contribute to a lower metabolic rate and weight management challenges.',
        recommendation: 'Incorporate 15-30 minutes of moderate activity daily.',
        severity: FactorSeverity.moderate,
      ));
    }

    if (profile.stressLevel == 'High' || profile.stressLevel == 'Very High') {
      factors.add(ContributingFactor(
        name: 'Elevated Daily Stress',
        evidence: 'Reported stress level is ${profile.stressLevel}.',
        interpretation: 'Chronic stress can lead to metabolic changes and potential emotional eating patterns.',
        recommendation: 'Introduce structured stress-management habits like meditation.',
        severity: FactorSeverity.elevated,
      ));
    }

    if (assessment != null) {
      for (var response in assessment.responses) {
        if (response.questionId == 'q4' && response.response == 'More than 8 hours') {
          factors.add(const ContributingFactor(
            name: 'Prolonged Sedentary Behavior',
            evidence: 'Assessment indicates more than 8 hours of daily inactivity.',
            interpretation: 'Extended periods of sitting are associated with metabolic health risks.',
            recommendation: 'Break sitting periods every 45-60 minutes with 5 minutes of movement.',
            severity: FactorSeverity.elevated,
          ));
        }
        if (response.questionId == 'q5' && (response.response == '3-5 times per week' || response.response == 'Daily')) {
          factors.add(const ContributingFactor(
            name: 'High Processed Food Exposure',
            evidence: 'Responses indicate frequent consumption of sugary or processed items.',
            interpretation: 'Consistent intake of energy-dense, low-nutrient foods can disrupt hunger signaling.',
            recommendation: 'Prioritize whole, single-ingredient Indian foods.',
            severity: FactorSeverity.elevated,
          ));
        }
        if (response.questionId == 'q6' && (response.response == 'Sometimes' || response.response == 'Often')) {
          factors.add(const ContributingFactor(
            name: 'Irregular Eating Patterns',
            evidence: 'Evidence suggests occasional feelings of uncontrolled or emotional eating.',
            interpretation: 'Unstructured eating can lead to calorie surplus and metabolic inconsistency.',
            recommendation: 'Adopt a structured 4-meal pattern to stabilize blood sugar.',
            severity: FactorSeverity.elevated,
          ));
        }
        if (response.questionId == 'q10' && (response.response == 'Less than 6 hours' || response.response == 'Poor quality/Snoring')) {
          factors.add(const ContributingFactor(
            name: 'Sleep Disruption',
            evidence: 'Assessment suggests poor sleep duration or quality indicators.',
            interpretation: 'Sleep deprivation affects ghrelin and leptin levels, increasing appetite for high-carb foods.',
            recommendation: 'Establish a cool, dark sleep environment and consistent bedtime.',
            severity: FactorSeverity.moderate,
          ));
        }
      }
    }

    return factors;
  }

  List<HealthRecommendation> _generateRecommendations(HealthProfile profile, List<ContributingFactor> factors) {
    final List<HealthRecommendation> recommendations = [];

    if (profile.bmi > 25.0) {
      recommendations.add(const HealthRecommendation(
        title: 'Caloric Balance Strategy',
        description: 'Aim for a slight, sustainable calorie deficit based on your estimated daily needs.',
        rationale: 'Current weight indicators suggest prioritizing metabolic efficiency.',
        category: 'Weight',
        evidence: 'Calculated BMI indicates weight management focus is appropriate.',
      ));
    }

    for (var factor in factors) {
      recommendations.add(HealthRecommendation(
        title: 'Intervention: ${factor.name}',
        description: factor.recommendation,
        rationale: factor.interpretation,
        category: 'Behavioral',
        evidence: factor.evidence,
      ));
    }

    return recommendations;
  }

  List<HealthPlanItem> _generatePlan(HealthProfile profile, List<ContributingFactor> factors) {
    final List<HealthPlanItem> plan = [];

    // Domain: Weight / Progress Monitoring
    plan.add(const HealthPlanItem(
      domain: 'Monitoring',
      goal: 'Track Physical Vitals',
      action: 'Record weight and waist circumference',
      frequency: 'Every Saturday morning',
      rationale: 'Consistent monitoring helps identify trends and maintain accountability.',
      evidence: 'Weight management goal in profile.',
    ));

    // Domain: Nutrition / Diet (Behavioral aspect)
    bool hasFoodFactor = factors.any((f) => f.name.contains('Food') || f.name.contains('Eating'));
    if (hasFoodFactor) {
      plan.add(const HealthPlanItem(
        domain: 'Nutrition',
        goal: 'Consistent Meal Structure',
        action: 'Eat meals at fixed times (8am, 1pm, 5pm, 8pm)',
        frequency: 'Daily',
        rationale: 'Stabilizing meal times reduces emotional eating triggers and stabilizes energy levels.',
        evidence: 'Identification of irregular eating patterns.',
      ));
    }

    // Domain: Physical Activity
    bool hasActivityFactor = factors.any((f) => f.name.contains('Activity') || f.name.contains('Sedentary'));
    if (hasActivityFactor) {
      plan.add(const HealthPlanItem(
        domain: 'Activity',
        goal: 'Movement Foundation',
        action: 'Brisk walking or active yoga',
        frequency: '30 mins, 5 days/week',
        rationale: 'Regular aerobic activity improves insulin sensitivity and cardiovascular health.',
        evidence: 'Sedentary behavior or low activity profile.',
      ));
    }

    // Domain: Stress / Lifestyle
    if (factors.any((f) => f.name.contains('Stress'))) {
      plan.add(const HealthPlanItem(
        domain: 'Behavioral',
        goal: 'Stress Management Habit',
        action: 'Deep breathing (Pranayama) or Guided Meditation',
        frequency: '10 mins daily before breakfast',
        rationale: 'Reducing cortisol levels helps mitigate stress-induced metabolic changes.',
        evidence: 'Reported high stress level.',
      ));
    }

    // Domain: Behavioral / Habit
    if (factors.any((f) => f.name.contains('Sleep'))) {
      plan.add(const HealthPlanItem(
        domain: 'Habit',
        goal: 'Sleep Hygiene',
        action: 'No blue light/screens 45 mins before bed',
        frequency: 'Nightly',
        rationale: 'Improving sleep quality supports hormone balance and cognitive control over food choices.',
        evidence: 'Identified sleep disruption factors.',
      ));
    }

    return plan;
  }

  List<MealOption> _generateNutritionPlan(HealthProfile profile) {
    final List<MealOption> meals = [];
    final cuisine = profile.cuisinePreference ?? 'General Indian';
    final dietType = profile.dietType ?? 'Vegetarian';
    final restrictions = profile.dietaryRestrictions;

    final bool isVegan = restrictions.contains('Vegan') || dietType == 'Vegan';
    final bool isDairyFree = restrictions.contains('Dairy-Free') || isVegan;
    final bool isGlutenFree = restrictions.contains('Gluten-Free');
    final bool isNonVeg = dietType == 'Non-Vegetarian';
    
    final bool isSouth = cuisine == 'South Indian';
    final bool isNorth = cuisine == 'North Indian';
    final bool isWest = cuisine == 'West Indian';
    final bool isEast = cuisine == 'East Indian';

    // 1. Breakfast Selection
    if (isSouth) {
      if (isGlutenFree) {
        meals.add(const MealOption(
          mealType: 'Breakfast',
          dishName: 'Ragi (Finger Millet) Dosa',
          portion: '2 medium',
          description: 'Naturally gluten-free fermented crepe made with finger millet.',
        ));
      } else {
        meals.add(const MealOption(
          mealType: 'Breakfast',
          dishName: 'Idli with Sambar',
          portion: '3 medium idlis',
          description: 'Steam-cooked fermented rice and lentil cakes, rich in probiotics.',
        ));
      }
    } else if (isNorth) {
      if (isGlutenFree) {
        meals.add(const MealOption(
          mealType: 'Breakfast',
          dishName: 'Buckwheat (Kuttu) Cheela',
          portion: '2 medium',
          description: 'Savory buckwheat pancakes with vegetables, naturally gluten-free.',
        ));
      } else if (isVegan) {
        meals.add(const MealOption(
          mealType: 'Breakfast',
          dishName: 'Aloo Paratha (No Butter)',
          portion: '1 medium',
          description: 'Whole wheat flatbread stuffed with spiced potatoes, cooked with minimal vegetable oil.',
        ));
      } else {
        meals.add(const MealOption(
          mealType: 'Breakfast',
          dishName: 'Stuffed Vegetable Paratha',
          portion: '1 medium (minimal oil)',
          description: 'Whole wheat flatbread with vegetable filling, served with fresh curd.',
        ));
      }
    } else if (isWest) {
      meals.add(const MealOption(
        mealType: 'Breakfast',
        dishName: 'Thalipeeth or Misal (No Pav if GF)',
        portion: '1 bowl',
        description: 'Multi-grain savory pancake or sprouted lentil curry.',
      ));
    } else if (isEast) {
       meals.add(const MealOption(
        mealType: 'Breakfast',
        dishName: 'Chira\'r Polao (Vegetable Poha)',
        portion: '1 bowl',
        description: 'Traditional flattened rice tempered with curry leaves and peanuts.',
      ));
    } else {
      meals.add(const MealOption(
        mealType: 'Breakfast',
        dishName: 'Mixed Vegetable Poha',
        portion: '1 bowl',
        description: 'Flattened rice with peas, carrots, and peanuts for healthy fats.',
      ));
    }

    // 2. Lunch Selection
    String lunchMain;
    if (isNonVeg) {
      lunchMain = isEast ? 'Machher Jhol (Fish)' : 'Chicken Curry';
    } else if (isVegan) {
      lunchMain = 'Chana Masala or Rajma';
    } else {
      lunchMain = 'Paneer Matar or Dal Tadka';
    }

    String grain = isGlutenFree ? 'Brown Rice' : 'Whole Wheat Roti';
    
    if (isSouth) {
      meals.add(MealOption(
        mealType: 'Lunch',
        dishName: '$lunchMain with Rice & Poriyal',
        portion: '1 cup rice + 1 bowl dal/curry',
        description: 'Balanced meal with local seasonal vegetables and coconut-based tempering.',
      ));
    } else if (isEast) {
      meals.add(MealOption(
        mealType: 'Lunch',
        dishName: 'Steamed Rice with $lunchMain & Shukto',
        portion: '1 cup rice + 1 bowl main',
        description: 'Traditional Bengali balanced meal with bitter gourd and vegetable stew.',
      ));
    } else {
      meals.add(MealOption(
        mealType: 'Lunch',
        dishName: '$lunchMain with $grain & Sabzi',
        portion: '2 rotis/1 cup rice + 1 bowl veg',
        description: 'High-fiber meal with protein-rich plant or animal base.',
      ));
    }

    // 3. Evening Snack Selection
    if (isDairyFree) {
      meals.add(const MealOption(
        mealType: 'Evening Snack',
        dishName: 'Roasted Makhana (Fox Nuts)',
        portion: '1 small cup',
        description: 'Low-calorie, crunchy snack flavored with turmeric and salt.',
      ));
    } else {
      meals.add(const MealOption(
        mealType: 'Evening Snack',
        dishName: 'Sprouts Salad with fresh Curd',
        portion: '1 small cup',
        description: 'High-protein snack to prevent evening overeating.',
      ));
    }

    // 4. Dinner Selection
    if (isGlutenFree) {
      meals.add(const MealOption(
        mealType: 'Dinner',
        dishName: 'Vegetable Khichdi (Rice & Moong Dal)',
        portion: '1 bowl',
        description: 'Lighter evening meal, easy to digest and naturally gluten-free.',
      ));
    } else {
      meals.add(const MealOption(
        mealType: 'Dinner',
        dishName: 'Lentil Soup (Shorba) or Light Roti with Veg',
        portion: '1 bowl / 1 roti',
        description: 'Lighter evening meal for better digestion and sleep.',
      ));
    }

    return meals;
  }

  ScreeningConcern _calculateScreeningConcern(HealthProfile profile, List<HealthMeasurement> measurements, List<ContributingFactor> factors) {
    int score = 0;
    
    if (profile.bmi >= 30.0) {
      score += 3;
    } else if (profile.bmi >= 25.0) {
      score += 1;
    }
    
    if (measurements.length >= 2) {
      if (measurements.last.weightKg > measurements.first.weightKg) {
        score += 1;
      }
    }
    
    if (factors.length >= 3) {
      score += 2;
    } else if (factors.isNotEmpty) {
      score += 1;
    }

    if (score >= 5) return ScreeningConcern.elevated;
    if (score >= 2) return ScreeningConcern.moderate;
    return ScreeningConcern.lower;
  }

  String _generateSummary(HealthProfile profile, ScreeningConcern concern, List<ContributingFactor> factors) {
    if (factors.isEmpty) {
      return 'Your screening indicators are currently stable. Focus on consistent habit tracking and energy balance.';
    }

    final topFactor = factors.first;
    String summary = 'Your primary area of focus is ${topFactor.name}. ';
    summary += topFactor.recommendation;
    
    return summary;
  }
}
