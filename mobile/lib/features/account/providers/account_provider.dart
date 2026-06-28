import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/account_models.dart';

class AccountProvider extends ChangeNotifier {
  List<AccountModel> _accounts = [];
  bool _loading = false;
  String? _error;

  List<AccountModel> get accounts => _accounts;
  bool get loading => _loading;
  String? get error => _error;

  double get totalBalance => _accounts.fold(0.0, (sum, a) => sum + a.balance);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await dio.get(ApiConstants.accounts);
      _accounts = (res.data['data'] as List<dynamic>? ?? [])
          .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> create({
    required String name,
    required String type,
    required String bankName,
    required String icon,
    required String color,
    required double initialBalance,
  }) async {
    try {
      await dio.post(ApiConstants.accounts, data: {
        'name': name,
        'type': type,
        'bank_name': bankName,
        'icon': icon,
        'color': color,
        'initial_balance': initialBalance,
      });
      await load();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(String id, {
    required String name,
    required String bankName,
    required String icon,
    required String color,
  }) async {
    try {
      await dio.put(ApiConstants.accountById(id), data: {
        'name': name,
        'bank_name': bankName,
        'icon': icon,
        'color': color,
      });
      await load();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setBalance(String id, double balance) async {
    try {
      await dio.patch(ApiConstants.accountBalance(id), data: {'balance': balance});
      await load();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await dio.delete(ApiConstants.accountById(id));
      _accounts.removeWhere((a) => a.id == id);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }
}
