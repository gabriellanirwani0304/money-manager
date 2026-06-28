import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUserID = 'user_id';
  static const _keyUserName = 'user_name';
  static const _keyCurrency = 'currency';

  static Future<void> saveTokens(String access, String refresh) async {
    await Future.wait([
      _storage.write(key: _keyAccess, value: access),
      _storage.write(key: _keyRefresh, value: refresh),
    ]);
  }

  static Future<String?> getAccessToken() => _storage.read(key: _keyAccess);
  static Future<String?> getRefreshToken() => _storage.read(key: _keyRefresh);

  static Future<void> saveUser({
    required String id,
    required String name,
    required String currency,
  }) async {
    await Future.wait([
      _storage.write(key: _keyUserID, value: id),
      _storage.write(key: _keyUserName, value: name),
      _storage.write(key: _keyCurrency, value: currency),
    ]);
  }

  static Future<Map<String, String?>> getUser() async {
    final results = await Future.wait([
      _storage.read(key: _keyUserID),
      _storage.read(key: _keyUserName),
      _storage.read(key: _keyCurrency),
    ]);
    return {'id': results[0], 'name': results[1], 'currency': results[2]};
  }

  static Future<void> clear() => _storage.deleteAll();
}
