import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oasyara_1/features/chatbot/presentation/screens/chatbot_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasyara_1/features/onboarding/presentation/providers/onboarding_provider.dart';

void main() {
  testWidgets('ChatbotScreen shows empty state initially', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: ChatbotScreen(),
        ),
      ),
    );

    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    
    // Clear any pending timers from animations
    await tester.pumpAndSettle();
  });
}
