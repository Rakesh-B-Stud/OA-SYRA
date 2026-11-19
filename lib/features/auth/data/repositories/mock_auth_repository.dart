import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final SharedPreferences _prefs;
  static const String _usersKey = 'mock_users';
  static const String _sessionKey = 'active_session_email';
  String? _currentUserEmail;

  MockAuthRepository(this._prefs);

  Map<String, String> _getUsers() {
    final data = _prefs.getString(_usersKey);
    if (data == null) {
      return {'test@oasyra.com': 'password123'};
    }
    return Map<String, String>.from(json.decode(data));
  }

  Future<void> _saveUsers(Map<String, String> users) async {
    await _prefs.setString(_usersKey, json.encode(users));
  }

  @override
  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    final users = _getUsers();
    
    if (users.containsKey(email) && users[email] == password) {
      _currentUserEmail = email;
      await _prefs.setString(_sessionKey, email);
      return true;
    }
    return false;
  }

  @override
  Future<bool> register(String email, String password, String name) async {
    await Future.delayed(const Duration(seconds: 1));
    final users = _getUsers();
    
    if (users.containsKey(email)) {
      throw Exception('User already exists');
    }
    
    users[email] = password;
    await _saveUsers(users);
    return true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    _currentUserEmail = 'google_user@oasyra.com';
    await _prefs.setString(_sessionKey, _currentUserEmail!);
    return true;
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> checkEmailVerified() async => true;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUserEmail = null;
    await _prefs.remove(_sessionKey);
  }

  @override
  Future<String?> getCurrentUserEmail() async {
    if (_currentUserEmail != null) return _currentUserEmail;
    final savedEmail = _prefs.getString(_sessionKey);
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _currentUserEmail = savedEmail;
      return savedEmail;
    }
    return null;
  }

  @override
  Future<String?> getCurrentUserId() async {
    final email = await getCurrentUserEmail();
    if (email != null && email.isNotEmpty) {
      return 'uid_${email.replaceAll('.', '_')}';
    }
    return null;
  }
}
