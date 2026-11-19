import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';

enum AuthStatus { initializing, unauthenticated, authenticating, authenticated, unverifiedEmail }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? errorMessage;
  final bool registrationSuccess;
  final bool isEmailVerified;

  AuthState({
    required this.status,
    this.email,
    this.errorMessage,
    this.registrationSuccess = false,
    this.isEmailVerified = true,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initializing);

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? errorMessage,
    bool? registrationSuccess,
    bool? isEmailVerified,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      errorMessage: errorMessage,
      registrationSuccess: registrationSuccess ?? this.registrationSuccess,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirebaseAuthRepository(prefs);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState.initial()) {
    restoreSession();
  }

  Future<void> restoreSession() async {
    try {
      final email = await _repository.getCurrentUserEmail();
      if (email != null && email.isNotEmpty) {
        final isVerified = await _repository.checkEmailVerified();
        if (!isVerified) {
          state = state.copyWith(
            status: AuthStatus.unverifiedEmail,
            email: email,
            isEmailVerified: false,
          );
        } else {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            email: email,
            isEmailVerified: true,
          );
        }
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated, email: null);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated, email: null);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      final success = await _repository.login(email, password);
      if (success) {
        final isVerified = await _repository.checkEmailVerified();
        if (!isVerified) {
          state = state.copyWith(
            status: AuthStatus.unverifiedEmail,
            email: email,
            isEmailVerified: false,
          );
        } else {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            email: email,
            isEmailVerified: true,
          );
        }
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Invalid email or password.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> register(String email, String password, String name) async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      final success = await _repository.register(email, password, name);
      if (success) {
        state = state.copyWith(
          status: AuthStatus.unverifiedEmail,
          email: email,
          isEmailVerified: false,
          registrationSuccess: true,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Registration failed.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.authenticating);
    try {
      final success = await _repository.signInWithGoogle();
      if (success) {
        final email = await _repository.getCurrentUserEmail();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          email: email,
          isEmailVerified: true,
        );
      } else {
        // User cancelled selection, revert to unauthenticated
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _repository.sendEmailVerification();
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> checkEmailVerified() async {
    try {
      final isVerified = await _repository.checkEmailVerified();
      if (isVerified) {
        final email = await _repository.getCurrentUserEmail();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          email: email,
          isEmailVerified: true,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _repository.sendPasswordResetEmail(email);
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> updateDisplayName(String name) async {
    try {
      state = state.copyWith(email: state.email);
    } catch (_) {}
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void clearRegistrationSuccess() {
    state = state.copyWith(registrationSuccess: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
