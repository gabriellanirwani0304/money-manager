import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/auth_models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> checkAuth() async {
    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    final userData = await SecureStorage.getUser();
    if (userData['id'] != null) {
      _user = UserModel(
        id: userData['id']!,
        name: userData['name'] ?? '',
        email: '',
        currency: userData['currency'] ?? 'IDR',
      );
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register(String name, String email, String password, String currency) async {
    _setLoading(true);
    try {
      final res = await dio.post(ApiConstants.register, data: {
        'name': name,
        'email': email,
        'password': password,
        'currency': currency,
      });
      await _handleAuthResponse(res.data['data']);
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final res = await dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });
      await _handleAuthResponse(res.data['data']);
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    final refreshToken = await SecureStorage.getRefreshToken();
    try {
      await dio.post(ApiConstants.logout, data: {'refresh_token': refreshToken});
    } catch (_) {}
    await SecureStorage.clear();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> forceUnauthenticated() async {
    await SecureStorage.clear();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    final auth = AuthResponse.fromJson(data);
    await SecureStorage.saveTokens(auth.accessToken, auth.refreshToken);
    await SecureStorage.saveUser(
      id: auth.user.id,
      name: auth.user.name,
      currency: auth.user.currency,
    );
    _user = auth.user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    _error = null;
    notifyListeners();
  }
}
