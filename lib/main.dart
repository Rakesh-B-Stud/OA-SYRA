import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'core/config/ai_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/oasyra_theme.dart';
import 'features/onboarding/presentation/providers/onboarding_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize App Check safely for mobile platforms
  if (!kIsWeb) {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: AndroidDebugProvider(),
        providerApple: AppleDebugProvider(),
      );
    } catch (_) {}
  }

  // Asynchronous background warm-up for cloud backend to wake up sleeping Render instance
  _triggerBackendWarmup();

  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const OasyraApp(),
    ),
  );
}

void _triggerBackendWarmup() {
  Future.microtask(() async {
    try {
      final url = Uri.parse('${AIConfig.backendBaseUrl}/readiness');
      await http.get(url).timeout(const Duration(seconds: 15));
    } catch (_) {}
  });
}

class OasyraApp extends ConsumerWidget {
  const OasyraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'OASYRA',
      debugShowCheckedModeBanner: false,
      theme: OasyraTheme.lightTheme,
      routerConfig: router,
    );
  }
}
