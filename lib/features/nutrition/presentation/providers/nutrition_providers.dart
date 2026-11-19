import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../data/repositories/local_nutrition_repository.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/nutrition_repository.dart';

import '../../data/sources/ml_inference_service.dart';

final mlInferenceServiceProvider = Provider<MlInferenceService>((ref) {
  return MlInferenceService();
});

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalNutritionRepository(prefs);
});

final dailyNutritionProvider = StateNotifierProvider<DailyNutritionNotifier, DailyNutritionRollup?>((ref) {
  final repository = ref.watch(nutritionRepositoryProvider);
  final userEmail = ref.watch(authProvider.select((s) => s.email));
  return DailyNutritionNotifier(repository, userEmail);
});

class DailyNutritionNotifier extends StateNotifier<DailyNutritionRollup?> {
  final NutritionRepository _repository;
  final String? _userEmail;

  DailyNutritionNotifier(this._repository, this._userEmail) : super(null) {
    loadToday();
  }

  Future<void> loadToday() async {
    if (_userEmail == null) return;
    final now = DateTime.now();
    final meals = await _repository.getMealRecordsForDay(_userEmail, now);
    state = DailyNutritionRollup(date: now, meals: meals);
  }

  Future<void> logMeal(MealRecord record) async {
    await _repository.saveMealRecord(record);
    await loadToday();
  }

  Future<void> deleteMeal(String recordId) async {
    if (_userEmail == null) return;
    await _repository.deleteMealRecord(_userEmail, recordId);
    await loadToday();
  }
}
