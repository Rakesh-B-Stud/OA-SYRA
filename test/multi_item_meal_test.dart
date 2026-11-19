import 'package:flutter_test/flutter_test.dart';
import 'package:oasyara_1/features/nutrition/domain/models/nutrition_models.dart';

void main() {
  group('Multi-Item Meal Batch Tests', () {
    const food1 = FoodItem(
      id: 'ind_002',
      name: 'Chapati',
      cuisine: 'North Indian',
      dietTypes: ['Vegetarian', 'Vegan'],
      category: 'Grain',
      nutritionPer100g: NutritionData(
        calories: 297.0,
        protein: 8.5,
        carbohydrates: 56.0,
        fat: 3.5,
        fiber: 9.0,
      ),
      source: 'OASYRA-Curated',
      sourceReference: 'Standard culinary composition estimate',
    );

    const food2 = FoodItem(
      id: 'ind_005',
      name: 'Plain Cooked Dal',
      cuisine: 'General Indian',
      dietTypes: ['Vegetarian', 'Vegan'],
      category: 'Protein / Lentils',
      nutritionPer100g: NutritionData(
        calories: 105.0,
        protein: 6.2,
        carbohydrates: 18.0,
        fat: 1.2,
        fiber: 3.5,
      ),
      source: 'OASYRA-Curated',
      sourceReference: 'Standard culinary composition estimate',
    );

    test('LoggedFoodItem calculates correct independent item nutrition', () {
      final item1 = LoggedFoodItem(
        food: food1,
        portion: const PortionEstimate(estimatedMassG: 100, confidence: 1.0, method: 'Manual portion'),
      );

      final item2 = LoggedFoodItem(
        food: food2,
        portion: const PortionEstimate(estimatedMassG: 150, confidence: 0.8, method: 'Manual portion'),
      );

      expect(item1.totalNutrition.calories, 297.0);
      expect(item1.totalNutrition.protein, 8.5);

      // 150g Dal = 1.5 * per100g
      expect(item2.totalNutrition.calories, 157.5);
      expect(item2.totalNutrition.protein, 9.3);
    });

    test('MealRecord correctly aggregates multiple items into one single record', () {
      final item1 = LoggedFoodItem(
        food: food1,
        portion: const PortionEstimate(estimatedMassG: 100, confidence: 1.0, method: 'Manual portion'),
      );

      final item2 = LoggedFoodItem(
        food: food2,
        portion: const PortionEstimate(estimatedMassG: 150, confidence: 0.8, method: 'Manual portion'),
      );

      final meal = MealRecord(
        id: 'meal_123',
        userId: 'test@oasyra.com',
        timestamp: DateTime(2026, 10, 31, 12, 0),
        type: OasyraMealType.lunch,
        items: [item1, item2],
      );

      expect(meal.items.length, 2);
      expect(meal.totalNutrition.calories, 297.0 + 157.5); // 454.5 kcal
      expect(meal.totalNutrition.protein, 8.5 + 9.3); // 17.8 g
      expect(meal.totalNutrition.carbohydrates, 56.0 + 27.0); // 83.0 g
      expect(meal.totalNutrition.fat, 3.5 + 1.8); // 5.3 g
      expect(meal.totalNutrition.fiber, 9.0 + 5.25); // 14.25 g
    });

    test('MealRecord serialization preserves multi-item structure and fields', () {
      final item1 = LoggedFoodItem(
        food: food1,
        portion: const PortionEstimate(estimatedMassG: 100, confidence: 1.0, method: 'Manual portion'),
      );

      final item2 = LoggedFoodItem(
        food: food2,
        portion: const PortionEstimate(estimatedMassG: 150, confidence: 0.8, method: 'Manual portion'),
      );

      final meal = MealRecord(
        id: 'meal_123',
        userId: 'test@oasyra.com',
        timestamp: DateTime(2026, 10, 31, 12, 0),
        type: OasyraMealType.lunch,
        items: [item1, item2],
      );

      final map = meal.toMap();
      final restored = MealRecord.fromMap(map);

      expect(restored.id, meal.id);
      expect(restored.userId, meal.userId);
      expect(restored.type, meal.type);
      expect(restored.items.length, 2);
      expect(restored.items[0].food.name, 'Chapati');
      expect(restored.items[1].food.name, 'Plain Cooked Dal');
      expect(restored.totalNutrition.calories, meal.totalNutrition.calories);
    });
  });
}
