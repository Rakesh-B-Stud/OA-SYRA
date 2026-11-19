import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const String _onboardingKey = 'onboarding_completed';

  OnboardingNotifier(this._prefs) : super(_prefs.getBool(_onboardingKey) ?? false);

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingKey, true);
    state = true;
  }

  // For testing purposes
  Future<void> resetOnboarding() async {
    await _prefs.setBool(_onboardingKey, false);
    state = false;
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingNotifier(prefs);
});
