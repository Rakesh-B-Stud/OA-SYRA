import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasyara_1/features/auth/presentation/providers/auth_provider.dart';
import 'package:oasyara_1/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:oasyara_1/features/nutrition/domain/models/nutrition_models.dart';
import 'package:oasyara_1/features/nutrition/presentation/providers/nutrition_providers.dart';

import 'package:oasyara_1/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  final String? _email;
  FakeAuthRepository([this._email]);

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<bool> register(String email, String password, String name) async => true;

  @override
  Future<bool> signInWithGoogle() async => true;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> checkEmailVerified() async => true;

  @override
  Future<void> logout() async {}

  @override
  Future<String?> getCurrentUserEmail() async => _email;

  @override
  Future<String?> getCurrentUserId() async => _email != null ? 'uid_$_email' : null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(String? email) : super(FakeAuthRepository(email)) {
    if (email != null) {
      state = AuthState(status: AuthStatus.authenticated, email: email);
    } else {
      state = AuthState.initial();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockFood = const FoodItem(
    id: 'f1',
    name: 'Chapati or roti',
    cuisine: 'North Indian',
    dietTypes: ['Vegetarian', 'Vegan'],
    category: 'Grain',
    nutritionPer100g: NutritionData(
      calories: 297,
      protein: 8.5,
      carbohydrates: 56.0,
      fat: 3.5,
      fiber: 9.0,
    ),
    source: 'OASYRA-Curated',
    sourceReference: 'Standard culinary composition estimate',
  );

  group('DailyNutritionNotifier & dailyNutritionProvider Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer createContainer({String? userEmail}) {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith((ref) => TestAuthNotifier(userEmail)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('Unauthenticated user receives null state', () async {
      final container = createContainer(userEmail: null);
      
      final state = container.read(dailyNutritionProvider);
      expect(state, isNull);
    });

    test('Authenticated user starts with empty day rollup', () async {
      final container = createContainer(userEmail: 'user_a@oasyra.com');
      
      await container.read(dailyNutritionProvider.notifier).loadToday();

      final state = container.read(dailyNutritionProvider);
      expect(state, isNotNull);
      expect(state!.meals, isEmpty);
      expect(state.totalNutrition, NutritionData.zero);
    });

    test('Logging a meal updates provider state reactively', () async {
      final userEmail = 'user_a@oasyra.com';
      final container = createContainer(userEmail: userEmail);
      await container.read(dailyNutritionProvider.notifier).loadToday();

      final meal = MealRecord(
        id: 'meal_1',
        userId: userEmail,
        timestamp: DateTime.now(),
        type: OasyraMealType.lunch,
        items: [
          LoggedFoodItem(
            food: mockFood,
            portion: const PortionEstimate(estimatedMassG: 100, confidence: 1.0, method: 'Manual'),
          ),
        ],
      );

      await container.read(dailyNutritionProvider.notifier).logMeal(meal);

      final state = container.read(dailyNutritionProvider);
      expect(state, isNotNull);
      expect(state!.meals.length, 1);
      expect(state.meals.first.id, 'meal_1');
      expect(state.totalNutrition.calories, 297);
    });

    test('Deleting a meal updates provider state reactively', () async {
      final userEmail = 'user_a@oasyra.com';
      final container = createContainer(userEmail: userEmail);
      await container.read(dailyNutritionProvider.notifier).loadToday();

      final meal = MealRecord(
        id: 'meal_to_delete',
        userId: userEmail,
        timestamp: DateTime.now(),
        type: OasyraMealType.breakfast,
        items: [
          LoggedFoodItem(
            food: mockFood,
            portion: const PortionEstimate(estimatedMassG: 100, confidence: 1.0, method: 'Manual'),
          ),
        ],
      );

      final notifier = container.read(dailyNutritionProvider.notifier);
      await notifier.logMeal(meal);
      
      DailyNutritionRollup? state1 = container.read(dailyNutritionProvider);
      expect(state1, isNotNull);
      expect(state1!.meals.length, 1);

      await notifier.deleteMeal('meal_to_delete');

      DailyNutritionRollup? state2 = container.read(dailyNutritionProvider);
      expect(state2, isNotNull);
      expect(state2!.meals, isEmpty);
      expect(state2.totalNutrition, NutritionData.zero);
    });

    test('User isolation is maintained across providers', () async {
      final containerA = createContainer(userEmail: 'user_a@oasyra.com');
      final containerB = createContainer(userEmail: 'user_b@oasyra.com');
      await containerA.read(dailyNutritionProvider.notifier).loadToday();
      await containerB.read(dailyNutritionProvider.notifier).loadToday();

      final mealA = MealRecord(
        id: 'meal_a',
        userId: 'user_a@oasyra.com',
        timestamp: DateTime.now(),
        type: OasyraMealType.dinner,
        items: [
          LoggedFoodItem(
            food: mockFood,
            portion: const PortionEstimate(estimatedMassG: 100, confidence: 1.0, method: 'Manual'),
          ),
        ],
      );

      await containerA.read(dailyNutritionProvider.notifier).logMeal(mealA);

      final stateA = containerA.read(dailyNutritionProvider);
      final stateB = containerB.read(dailyNutritionProvider);

      expect(stateA, isNotNull);
      expect(stateB, isNotNull);
      expect(stateA!.meals.length, 1);
      expect(stateA.meals.first.userId, 'user_a@oasyra.com');
      expect(stateB!.meals, isEmpty);
    });

    test('Meals logged for a different date do not appear in today rollup', () async {
      final userEmail = 'user_a@oasyra.com';
      final container = createContainer(userEmail: userEmail);
      await container.read(dailyNutritionProvider.notifier).loadToday();

      final yesterdayMeal = MealRecord(
        id: 'yesterday_meal',
        userId: userEmail,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        type: OasyraMealType.snack,
        items: [
          LoggedFoodItem(
            food: mockFood,
            portion: const PortionEstimate(estimatedMassG: 100, confidence: 1.0, method: 'Manual'),
          ),
        ],
      );

      await container.read(dailyNutritionProvider.notifier).logMeal(yesterdayMeal);

      final state = container.read(dailyNutritionProvider);
      expect(state, isNotNull);
      expect(state!.meals, isEmpty);
    });

    test('Unauthenticated user logMeal and deleteMeal operate safely without crash', () async {
      final container = createContainer(userEmail: null);
      
      final notifier = container.read(dailyNutritionProvider.notifier);

      final meal = MealRecord(
        id: 'unauth_meal',
        userId: 'unknown',
        timestamp: DateTime.now(),
        type: OasyraMealType.snack,
        items: const [],
      );

      // Should complete safely without exception
      await notifier.logMeal(meal);
      await notifier.deleteMeal('unauth_meal');

      final state = container.read(dailyNutritionProvider);
      expect(state, isNull);
    });
  });
}
