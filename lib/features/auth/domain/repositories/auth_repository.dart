abstract class AuthRepository {
  Future<bool> login(String email, String password);
  Future<bool> register(String email, String password, String name);
  Future<bool> signInWithGoogle();
  Future<void> sendEmailVerification();
  Future<bool> checkEmailVerified();
  Future<void> logout();
  Future<String?> getCurrentUserEmail();
  Future<String?> getCurrentUserId();
  Future<void> sendPasswordResetEmail(String email);
}
