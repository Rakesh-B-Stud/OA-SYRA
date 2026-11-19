import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/health/presentation/screens/add_measurement_screen.dart';
import '../../features/health/presentation/screens/health_assessment_results_screen.dart';
import '../../features/health/presentation/screens/health_assessment_screen.dart';
import '../../features/health/presentation/screens/health_profile_setup_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/analysis/presentation/screens/health_analysis_screen.dart';
import '../../features/health/presentation/screens/health_data_screen.dart';
import '../../features/chatbot/presentation/screens/chatbot_screen.dart';
import '../../features/chatbot/presentation/screens/ai_test_screen.dart';
import '../../features/chatbot/presentation/screens/ondevice_ai_test_screen.dart';
import '../../features/chatbot/presentation/providers/chatbot_providers.dart';
import '../../shared/screens/main_scaffold.dart';
import '../../features/profile/presentation/screens/report_preview_screen.dart';
import '../../features/profile/presentation/screens/profile_hub_screen.dart';
import '../../features/profile/presentation/screens/edit_name_screen.dart';
import '../../features/profile/presentation/screens/security_screen.dart';
import '../../features/profile/presentation/screens/about_screen.dart';
import '../../features/nutrition/presentation/screens/nutrition_dashboard_screen.dart';
import '../../features/nutrition/presentation/screens/meal_logging_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) => notifyListeners());
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      
      final isInitializing = authState.status == AuthStatus.initializing;
      if (isInitializing) {
        return null;
      }

      final isAuth = authState.status == AuthStatus.authenticated;
      final isUnverified = authState.status == AuthStatus.unverifiedEmail;
      
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final isVerifyRoute = state.matchedLocation == '/verify-email';
      final isOnboardingRoute = state.matchedLocation == '/onboarding';
      final isSplashRoute = state.matchedLocation == '/';
      final isLoginSuccessRoute = state.matchedLocation == '/login-success';
      final isLogoutSplashRoute = state.matchedLocation == '/logout-splash';

      if (isUnverified) {
        if (!isVerifyRoute && !isLogoutSplashRoute) {
          return '/verify-email';
        }
        return null;
      }

      if (!isAuth) {
        // If unauthenticated and on a splash/auth route, allow it
        if (isAuthRoute || isOnboardingRoute || isSplashRoute || isLogoutSplashRoute || isVerifyRoute) {
          return null;
        }
        return '/onboarding'; // Default to onboarding for fresh launch
      } else {
        // If authenticated and on an entry/auth route (except login-success/logout), redirect to dashboard
        if ((isAuthRoute || isOnboardingRoute || isSplashRoute || isVerifyRoute) && !isLoginSuccessRoute && !isLogoutSplashRoute) {
          return '/login-success';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreenWrapper(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/login-success',
        builder: (context, state) => const LoginSuccessScreen(),
      ),
      GoRoute(
        path: '/logout-splash',
        builder: (context, state) => const LogoutSplashScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/chatbot',
            builder: (context, state) => const ChatbotScreenWrapper(),
          ),
          GoRoute(
            path: '/ai-test',
            builder: (context, state) => const AITestScreen(),
          ),
          GoRoute(
            path: '/ondevice-ai-test',
            builder: (context, state) => const OnDeviceAiTestScreen(),
          ),
          GoRoute(
            path: '/health-data',
            builder: (context, state) => const HealthDataScreen(),
          ),
          GoRoute(
            path: '/health-setup',
            builder: (context, state) => const HealthProfileSetupScreen(),
          ),
          GoRoute(
            path: '/profile-hub',
            builder: (context, state) => const ProfileHubScreen(),
          ),
          GoRoute(
            path: '/edit-name',
            builder: (context, state) => const EditNameScreen(),
          ),
          GoRoute(
            path: '/security',
            builder: (context, state) => const SecurityScreen(),
          ),
          GoRoute(
            path: '/about',
            builder: (context, state) => const AboutScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/health-assessment',
        builder: (context, state) => const HealthAssessmentScreen(),
      ),
      GoRoute(
        path: '/health-results',
        builder: (context, state) => const HealthAssessmentResultsScreen(),
      ),
      GoRoute(
        path: '/add-measurement',
        builder: (context, state) => const AddMeasurementScreen(),
      ),
      GoRoute(
        path: '/health-analysis',
        builder: (context, state) => const HealthAnalysisScreen(),
      ),
      GoRoute(
        path: '/nutrition-dashboard',
        builder: (context, state) => const NutritionDashboardScreen(),
      ),
      GoRoute(
        path: '/meal-logging',
        builder: (context, state) => const MealLoggingScreen(),
      ),
      GoRoute(
        path: '/report-preview',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ReportPreviewScreen(
            pdfBytes: extra['bytes'] as Uint8List,
            fileName: extra['name'] as String,
          );
        },
      ),
    ],
  );
});

class ChatbotScreenWrapper extends ConsumerStatefulWidget {
  const ChatbotScreenWrapper({super.key});

  @override
  ConsumerState<ChatbotScreenWrapper> createState() => _ChatbotScreenWrapperState();
}

class _ChatbotScreenWrapperState extends ConsumerState<ChatbotScreenWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(currentConversationProvider) == null) {
        ref.read(chatbotNotifierProvider.notifier).resumeLastConversation();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ChatbotScreen();
  }
}

// Splash screen shown after successful login
class LoginSuccessScreen extends StatefulWidget {
  const LoginSuccessScreen({super.key});

  @override
  State<LoginSuccessScreen> createState() => _LoginSuccessScreenState();
}

class _LoginSuccessScreenState extends State<LoginSuccessScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToDashboard();
  }

  Future<void> _navigateToDashboard() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

// Splash screen shown during logout
class LogoutSplashScreen extends ConsumerStatefulWidget {
  const LogoutSplashScreen({super.key});

  @override
  ConsumerState<LogoutSplashScreen> createState() => _LogoutSplashScreenState();
}

class _LogoutSplashScreenState extends ConsumerState<LogoutSplashScreen> {
  @override
  void initState() {
    super.initState();
    _performLogout();
  }

  Future<void> _performLogout() async {
    // Show splash for 2 seconds then trigger logout which will redirect via GoRouter
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

// A small wrapper to handle splash screen duration and navigation
class SplashScreenWrapper extends ConsumerStatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  ConsumerState<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends ConsumerState<SplashScreenWrapper> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.authenticated) {
        context.go('/dashboard');
      } else {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
