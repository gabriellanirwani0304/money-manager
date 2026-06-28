import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/budget_models.dart';

class BudgetProvider extends ChangeNotifier {
  List<BudgetModel> _budgets = [];
  bool _loading = false;
  bool _copying = false;
  String? _error;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  List<BudgetModel> get budgets => _budgets;
  bool get loading => _loading;
  bool get copying => _copying;
  String? get error => _error;
  int get month => _month;
  int get year => _year;

  Future<void> load({int? month, int? year}) async {
    if (month != null) _month = month;
    if (year != null) _year = year;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await dio.get(ApiConstants.budgets, queryParameters: {
        'month': _month,
        'year': _year,
      });
      _budgets = (res.data['data'] as List<dynamic>)
          .map((e) => BudgetModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> create({
    required String categoryId,
    required double amount,
    required int month,
    required int year,
  }) async {
    try {
      await dio.post(ApiConstants.budgets, data: {
        'category_id': categoryId,
        'amount': amount,
        'month': month,
        'year': year,
      });
      await load();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(String id, double amount) async {
    try {
      await dio.put(ApiConstants.budgetById(id), data: {'amount': amount});
      await load();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }

  /// Returns count of budgets copied, or -1 on error.
  Future<int> copyFromPrevMonth() async {
    int prevMonth = _month - 1;
    int prevYear = _year;
    if (prevMonth == 0) {
      prevMonth = 12;
      prevYear--;
    }

    _copying = true;
    notifyListeners();

    try {
      final res = await dio.get(ApiConstants.budgets,
          queryParameters: {'month': prevMonth, 'year': prevYear});
      final prevBudgets = (res.data['data'] as List<dynamic>)
          .map((e) => BudgetModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final existingCatIds = _budgets.map((b) => b.categoryId).toSet();
      final toCreate =
          prevBudgets.where((b) => !existingCatIds.contains(b.categoryId)).toList();

      for (final b in toCreate) {
        await dio.post(ApiConstants.budgets, data: {
          'category_id': b.categoryId,
          'amount': b.budgetAmount,
          'month': _month,
          'year': _year,
        });
      }

      await load();
      return toCreate.length;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return -1;
    } finally {
      _copying = false;
      notifyListeners();
    }
  }

  Future<bool> delete(String id) async {
    try {
      await dio.delete(ApiConstants.budgetById(id));
      _budgets.removeWhere((b) => b.id == id);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }
}
