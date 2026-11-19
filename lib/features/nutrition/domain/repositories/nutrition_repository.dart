import '../models/nutrition_models.dart';

abstract class NutritionRepository {
  /// Save a new meal record for a user
  Future<void> saveMealRecord(MealRecord record);

  /// Get all meal records for a specific day
  Future<List<MealRecord>> getMealRecordsForDay(String userId, DateTime date);

  /// Get meal records in a date range
  Future<List<MealRecord>> getMealRecordsForRange(String userId, DateTime start, DateTime end);

  /// Get a single meal record by ID
  Future<MealRecord?> getMealRecord(String userId, String recordId);

  /// Delete a meal record
  Future<void> deleteMealRecord(String userId, String recordId);

  /// Get the available food catalog (to be expanded later)
  Future<List<FoodItem>> getFoodCatalog();

  /// Search for food items in the catalog
  Future<List<FoodItem>> searchFoodCatalog(String query);
}
