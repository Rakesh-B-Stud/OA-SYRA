import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasyara_1/features/nutrition/presentation/screens/nutrition_dashboard_screen.dart';
import 'package:oasyara_1/features/nutrition/presentation/providers/nutrition_providers.dart';
import 'package:oasyara_1/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:oasyara_1/features/auth/presentation/providers/auth_provider.dart';
import 'package:oasyara_1/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  final String? _email;
  FakeAuthRepository([this._email = 'test@oasyra.com']);

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
    state = AuthState(status: AuthStatus.authenticated, email: email);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Nutrition Dashboard renders without overflow on narrow 320px viewport', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Set physical device bounds (360px width, standard OPPO / Android device)
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith((ref) => TestAuthNotifier('test@oasyra.com')),
        ],
        child: const MaterialApp(
          home: NutritionDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify "Today's Meals" and "Add Meal" widgets exist
    expect(find.text("Today's Meals"), findsOneWidget);
    expect(find.text('Add Meal'), findsOneWidget);

    // Verify no RenderFlex overflow exception was logged
    expect(tester.takeException(), isNull);
  });
}
