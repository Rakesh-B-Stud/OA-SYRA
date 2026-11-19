import 'package:equatable/equatable.dart';

enum OasyraMealType { breakfast, lunch, dinner, snack }

class NutritionData extends Equatable {
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;

  const NutritionData({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
  });

  @override
  List<Object?> get props => [calories, protein, carbohydrates, fat, fiber];

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
    };
  }

  factory NutritionData.fromMap(Map<String, dynamic> map) {
    return NutritionData(
      calories: (map['calories'] as num).toDouble(),
      protein: (map['protein'] as num).toDouble(),
      carbohydrates: (map['carbohydrates'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      fiber: (map['fiber'] as num).toDouble(),
    );
  }

  static const zero = NutritionData(
    calories: 0,
    protein: 0,
    carbohydrates: 0,
    fat: 0,
    fiber: 0,
  );

  NutritionData operator +(NutritionData other) {
    return NutritionData(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbohydrates: carbohydrates + other.carbohydrates,
      fat: fat + other.fat,
      fiber: fiber + other.fiber,
    );
  }
}

class FoodItem extends Equatable {
  final String id;
  final String name;
  final String cuisine; // North Indian, South Indian, etc.
  final List<String> dietTypes; // Vegetarian, Vegan, etc.
  final String category; // Grain, Protein, etc.
  final NutritionData nutritionPer100g;
  final String source; // IFCT, OASYRA-Custom, etc.
  final String sourceReference;

  const FoodItem({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.dietTypes,
    required this.category,
    required this.nutritionPer100g,
    required this.source,
    required this.sourceReference,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        cuisine,
        dietTypes,
        category,
        nutritionPer100g,
        source,
        sourceReference,
      ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cuisine': cuisine,
      'dietTypes': dietTypes,
      'category': category,
      'nutritionPer100g': nutritionPer100g.toMap(),
      'source': source,
      'sourceReference': sourceReference,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'],
      name: map['name'],
      cuisine: map['cuisine'],
      dietTypes: List<String>.from(map['dietTypes']),
      category: map['category'],
      nutritionPer100g: NutritionData.fromMap(map['nutritionPer100g']),
      source: map['source'],
      sourceReference: map['sourceReference'],
    );
  }
}

class PortionEstimate extends Equatable {
  final double estimatedMassG;
  final double? areaPx;
  final double? pixelToCmScale;
  final double? estimatedVolumeCm3;
  final double confidence; // 0.0 to 1.0
  final String method; // "AI-Volumetric", "AI-Manual-Correction", "Manual"

  const PortionEstimate({
    required this.estimatedMassG,
    this.areaPx,
    this.pixelToCmScale,
    this.estimatedVolumeCm3,
    required this.confidence,
    required this.method,
  });

  @override
  List<Object?> get props => [
        estimatedMassG,
        areaPx,
        pixelToCmScale,
        estimatedVolumeCm3,
        confidence,
        method,
      ];

  Map<String, dynamic> toMap() {
    return {
      'estimatedMassG': estimatedMassG,
      'areaPx': areaPx,
      'pixelToCmScale': pixelToCmScale,
      'estimatedVolumeCm3': estimatedVolumeCm3,
      'confidence': confidence,
      'method': method,
    };
  }

  factory PortionEstimate.fromMap(Map<String, dynamic> map) {
    return PortionEstimate(
      estimatedMassG: (map['estimatedMassG'] as num).toDouble(),
      areaPx: (map['areaPx'] as num?)?.toDouble(),
      pixelToCmScale: (map['pixelToCmScale'] as num?)?.toDouble(),
      estimatedVolumeCm3: (map['estimatedVolumeCm3'] as num?)?.toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
      method: map['method'],
    );
  }
}

class LoggedFoodItem extends Equatable {
  final FoodItem food;
  final PortionEstimate portion;

  const LoggedFoodItem({
    required this.food,
    required this.portion,
  });

  NutritionData get totalNutrition {
    final factor = portion.estimatedMassG / 100.0;
    return NutritionData(
      calories: food.nutritionPer100g.calories * factor,
      protein: food.nutritionPer100g.protein * factor,
      carbohydrates: food.nutritionPer100g.carbohydrates * factor,
      fat: food.nutritionPer100g.fat * factor,
      fiber: food.nutritionPer100g.fiber * factor,
    );
  }

  @override
  List<Object?> get props => [food, portion];

  Map<String, dynamic> toMap() {
    return {
      'food': food.toMap(),
      'portion': portion.toMap(),
    };
  }

  factory LoggedFoodItem.fromMap(Map<String, dynamic> map) {
    return LoggedFoodItem(
      food: FoodItem.fromMap(map['food']),
      portion: PortionEstimate.fromMap(map['portion']),
    );
  }
}

class MealRecord extends Equatable {
  final String id;
  final String userId;
  final DateTime timestamp;
  final OasyraMealType type;
  final List<LoggedFoodItem> items;
  final String? imagePath;

  const MealRecord({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.type,
    required this.items,
    this.imagePath,
  });

  NutritionData get totalNutrition {
    if (items.isEmpty) return NutritionData.zero;
    return items
        .map((item) => item.totalNutrition)
        .reduce((a, b) => a + b);
  }

  @override
  List<Object?> get props => [id, userId, timestamp, type, items, imagePath];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'items': items.map((x) => x.toMap()).toList(),
      'imagePath': imagePath,
    };
  }

  factory MealRecord.fromMap(Map<String, dynamic> map) {
    return MealRecord(
      id: map['id'],
      userId: map['userId'],
      timestamp: DateTime.parse(map['timestamp']),
      type: OasyraMealType.values.byName(map['type']),
      items: List<LoggedFoodItem>.from(
          map['items'].map((x) => LoggedFoodItem.fromMap(x))),
      imagePath: map['imagePath'],
    );
  }
}

class DailyNutritionRollup extends Equatable {
  final DateTime date;
  final List<MealRecord> meals;

  const DailyNutritionRollup({
    required this.date,
    required this.meals,
  });

  NutritionData get totalNutrition {
    if (meals.isEmpty) return NutritionData.zero;
    return meals
        .map((meal) => meal.totalNutrition)
        .reduce((a, b) => a + b);
  }

  @override
  List<Object?> get props => [date, meals];
}
