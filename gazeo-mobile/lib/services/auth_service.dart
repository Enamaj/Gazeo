import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _accessTokenKey = 'gazeo_jwt_access';
  static const String _refreshTokenKey = 'gazeo_jwt_refresh';
  static const String _userRoleKey = 'gazeo_user_role';
  static const String _userPhoneKey = 'gazeo_user_phone';

  Future<void> saveTokens({
    required String access,
    required String refresh,
    String? role,
    String? phone,
  }) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
    if (role != null) await _storage.write(key: _userRoleKey, value: role);
    if (phone != null) await _storage.write(key: _userPhoneKey, value: phone);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<String?> getUserRole() async {
    return await _storage.read(key: _userRoleKey);
  }

  Future<String?> getUserPhone() async {
    return await _storage.read(key: _userPhoneKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> saveRole(String role) async {
    await _storage.write(key: _userRoleKey, value: role);
  }

  Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userRoleKey);
    await _storage.delete(key: _userPhoneKey);
  }
}

