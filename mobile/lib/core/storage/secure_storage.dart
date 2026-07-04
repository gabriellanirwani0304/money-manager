import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUserID = 'user_id';
  static const _keyUserName = 'user_name';
  static const _keyCurrency = 'currency';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<void> saveTokens(String access, String refresh) async {
    final p = await _prefs;
    await Future.wait([
      p.setString(_keyAccess, access),
      p.setString(_keyRefresh, refresh),
    ]);
  }

  static Future<String?> getAccessToken() async {
    return (await _prefs).getString(_keyAccess);
  }

  static Future<String?> getRefreshToken() async {
    return (await _prefs).getString(_keyRefresh);
  }

  static Future<void> saveUser({
    required String id,
    required String name,
    required String currency,
  }) async {
    final p = await _prefs;
    await Future.wait([
      p.setString(_keyUserID, id),
      p.setString(_keyUserName, name),
      p.setString(_keyCurrency, currency),
    ]);
  }

  static Future<Map<String, String?>> getUser() async {
    final p = await _prefs;
    return {
      'id': p.getString(_keyUserID),
      'name': p.getString(_keyUserName),
      'currency': p.getString(_keyCurrency),
    };
  }

  static Future<void> clear() async {
    final p = await _prefs;
    await Future.wait([
      p.remove(_keyAccess),
      p.remove(_keyRefresh),
      p.remove(_keyUserID),
      p.remove(_keyUserName),
      p.remove(_keyCurrency),
    ]);
  }
}
