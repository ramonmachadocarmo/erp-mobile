import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'erp_token';
  static const _userKey = 'erp_user';

  Future<void> save({required String token, required String userJson}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: userJson);
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<String?> readUserJson() => _storage.read(key: _userKey);

  // Credentials kept for biometric sign-in. They live in the platform keystore
  // and deliberately survive [clear], so logging out does not disable biometrics.
  static const _bioEmailKey = 'erp_bio_email';
  static const _bioPasswordKey = 'erp_bio_password';

  Future<void> saveBiometricCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _bioEmailKey, value: email);
    await _storage.write(key: _bioPasswordKey, value: password);
  }

  Future<({String email, String password})?> readBiometricCredentials() async {
    final email = await _storage.read(key: _bioEmailKey);
    final password = await _storage.read(key: _bioPasswordKey);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  Future<void> clearBiometricCredentials() async {
    await _storage.delete(key: _bioEmailKey);
    await _storage.delete(key: _bioPasswordKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
