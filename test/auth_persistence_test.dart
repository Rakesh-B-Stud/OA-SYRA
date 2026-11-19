import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasyara_1/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:oasyara_1/features/auth/presentation/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Persistence & Session Restoration Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Initial state starts as initializing then resolves unauthenticated when no session exists', () async {
      final repository = MockAuthRepository(prefs);
      final notifier = AuthNotifier(repository);

      expect(notifier.state.status, AuthStatus.initializing);

      await notifier.restoreSession();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.email, isNull);
    });

    test('Session restores authenticated state on startup if saved session exists', () async {
      await prefs.setString('active_session_email', 'user@oasyra.com');
      
      final repository = MockAuthRepository(prefs);
      final notifier = AuthNotifier(repository);

      await notifier.restoreSession();

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.email, 'user@oasyra.com');
    });

    test('Login saves session to SharedPreferences and updates state to authenticated', () async {
      final repository = MockAuthRepository(prefs);
      final notifier = AuthNotifier(repository);

      await notifier.login('test@oasyra.com', 'password123');

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.email, 'test@oasyra.com');

      final savedEmail = prefs.getString('active_session_email');
      expect(savedEmail, 'test@oasyra.com');
    });

    test('Logout clears session from SharedPreferences and resets state', () async {
      await prefs.setString('active_session_email', 'test@oasyra.com');
      
      final repository = MockAuthRepository(prefs);
      final notifier = AuthNotifier(repository);
      await notifier.restoreSession();

      expect(notifier.state.status, AuthStatus.authenticated);

      await notifier.logout();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.email, isNull);
      expect(prefs.getString('active_session_email'), isNull);
    });
  });
}
