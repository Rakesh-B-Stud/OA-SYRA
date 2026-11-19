import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oasyara_1/main.dart';
import 'package:oasyara_1/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Oasyra app initial flow test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const OasyraApp(),
      ),
    );

    // Verify Splash Screen elements
    expect(find.text('OASY'), findsOneWidget);
    expect(find.text('RA'), findsOneWidget);

    // Wait for splash duration
    // Using pump instead of pumpAndSettle to avoid hanging on infinite animations
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify transition to Onboarding
    expect(find.text('Welcome to OASYRA'), findsOneWidget);
  });
}
