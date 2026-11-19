import 'package:flutter_test/flutter_test.dart';
import 'package:oasyara_1/features/nutrition/domain/models/nutrition_models.dart';
import 'package:oasyara_1/features/nutrition/data/repositories/local_nutrition_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nutrition Models - Logic Tests', () {
    final mockFood = FoodItem(
      id: 'f1',
      name: 'Paneer Tikka',
      cuisine: 'North Indian',
      dietTypes: const ['Vegetarian'],
      category: 'Protein',
      nutritionPer100g: const NutritionData(
        calories: 250,
        protein: 15,
        carbohydrates: 5,
        fat: 18,
        fiber: 1,
      ),
      source: 'IFCT',
      sourceReference: '2017',
    );

    test('LoggedFoodItem calculates total nutrition correctly', () {
      final loggedItem = LoggedFoodItem(
        food: mockFood,
        portion: const PortionEstimate(
          estimatedMassG: 200,
          confidence: 0.9,
          method: 'Manual',
        ),
      );

      final total = loggedItem.totalNutrition;
      expect(total.calories, 500);
      expect(total.protein, 30);
      expect(total.carbohydrates, 10);
    });

    test('Portion scaling calculates correctly for 100g, 150g, 50g', () {
      // 100g portion -> exact per 100g values
      final item100 = LoggedFoodItem(
        food: mockFood,
        portion: const PortionEstimate(estimatedMassG: 100, confidence: 1.0, method: 'Manual'),
      );
      expect(item100.totalNutrition.calories, 250);
      expect(item100.totalNutrition.protein, 15);

      // 150g portion -> 1.5x values
      final item150 = LoggedFoodItem(
        food: mockFood,
        portion: const PortionEstimate(estimatedMassG: 150, confidence: 1.0, method: 'Manual'),
      );
      expect(item150.totalNutrition.calories, 375);
      expect(item150.totalNutrition.protein, 22.5);

      // 50g portion -> 0.5x values
      final item50 = LoggedFoodItem(
        food: mockFood,
        portion: const PortionEstimate(estimatedMassG: 50, confidence: 1.0, method: 'Manual'),
      );
      expect(item50.totalNutrition.calories, 125);
      expect(item50.totalNutrition.protein, 7.5);
    });

    test('MealRecord aggregates multiple items correctly', () {
      final item1 = LoggedFoodItem(
        food: mockFood,
        portion: const PortionEstimate(estimatedMassG: 100, confidence: 1, method: 'M'),
      );
      final item2 = LoggedFoodItem(
        food: mockFood,
        portion: const PortionEstimate(estimatedMassG: 50, confidence: 1, method: 'M'),
      );

      final meal = MealRecord(
        id: 'm1',
        userId: 'u1',
        timestamp: DateTime.now(),
        type: OasyraMealType.lunch,
        items: [item1, item2],
      );

      expect(meal.totalNutrition.calories, 375); // 250 + 125
    });
  });

  group('LocalNutritionRepository - Persistence', () {
    late SharedPreferences prefs;
    late LocalNutritionRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = LocalNutritionRepository(prefs);
    });

    test('Saving and retrieving meal records works', () async {
      final meal = MealRecord(
        id: 'record_1',
        userId: 'user_a',
        timestamp: DateTime(2026, 8, 21, 13, 0),
        type: OasyraMealType.lunch,
        items: const [],
      );

      await repository.saveMealRecord(meal);
      
      final meals = await repository.getMealRecordsForDay('user_a', DateTime(2026, 8, 21));
      expect(meals.length, 1);
      expect(meals.first.id, 'record_1');
    });

    test('User isolation is maintained', () async {
      final mealA = MealRecord(
        id: 'm_a',
        userId: 'user_a',
        timestamp: DateTime.now(),
        type: OasyraMealType.breakfast,
        items: const [],
      );
      final mealB = MealRecord(
        id: 'm_b',
        userId: 'user_b',
        timestamp: DateTime.now(),
        type: OasyraMealType.breakfast,
        items: const [],
      );

      await repository.saveMealRecord(mealA);
      await repository.saveMealRecord(mealB);

      final recordsA = await repository.getMealRecordsForDay('user_a', DateTime.now());
      final recordsB = await repository.getMealRecordsForDay('user_b', DateTime.now());

      expect(recordsA.every((r) => r.userId == 'user_a'), true);
      expect(recordsB.every((r) => r.userId == 'user_b'), true);
      expect(recordsA.length, 1);
      expect(recordsB.length, 1);
    });
  });

  group('LocalNutritionRepository - Food Catalog', () {
    late SharedPreferences prefs;
    late LocalNutritionRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = LocalNutritionRepository(prefs);
    });

    test('Catalog loads successfully and contains expected count', () async {
      final catalog = await repository.getFoodCatalog();
      expect(catalog.isNotEmpty, true);
      expect(catalog.length, greaterThanOrEqualTo(20));
      
      // Verify required fields on first item
      final item = catalog.first;
      expect(item.id.isNotEmpty, true);
      expect(item.name.isNotEmpty, true);
      expect(item.nutritionPer100g.calories, greaterThan(0));
    });

    test('Case-insensitive and partial name search works', () async {
      final results = await repository.searchFoodCatalog('rice');
      expect(results.isNotEmpty, true);
      expect(results.any((f) => f.name.toLowerCase().contains('rice')), true);

      final mixedResults = await repository.searchFoodCatalog('pAnEeR');
      expect(mixedResults.isNotEmpty, true);
      expect(mixedResults.any((f) => f.name.toLowerCase().contains('paneer')), true);
    });

    test('Empty and whitespace-only queries return full catalog', () async {
      final fullCatalog = await repository.getFoodCatalog();
      
      final emptyResults = await repository.searchFoodCatalog('');
      expect(emptyResults.length, fullCatalog.length);

      final whitespaceResults = await repository.searchFoodCatalog('   ');
      expect(whitespaceResults.length, fullCatalog.length);
    });

    test('Queries with no matches return empty list', () async {
      final results = await repository.searchFoodCatalog('nonexistentfooditemxyz123');
      expect(results.isEmpty, true);
    });
  });
}
