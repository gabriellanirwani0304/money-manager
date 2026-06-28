import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/transaction_models.dart';

class TransactionProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  double _totalIncome = 0;
  double _totalExpense = 0;

  // Filters
  String? _filterType;
  String? _filterCategoryId;
  String? _startDate;
  String? _endDate;
  String? _search;

  List<TransactionModel> get transactions => _transactions;
  List<CategoryModel> get categories => _categories;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  bool get hasMore => _page < _totalPages;
  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  String? get filterType => _filterType;
  String? get filterCategoryId => _filterCategoryId;

  void setFilter({
    String? type,
    String? categoryId,
    String? startDate,
    String? endDate,
    String? search,
  }) {
    _filterType = type;
    _filterCategoryId = categoryId;
    _startDate = startDate;
    _endDate = endDate;
    _search = search;
    _page = 1;
    _transactions = [];
    notifyListeners();
    load();
  }

  void clearFilters() {
    _filterType = null;
    _filterCategoryId = null;
    _startDate = null;
    _endDate = null;
    _search = null;
    _page = 1;
    _transactions = [];
    notifyListeners();
    load();
  }

  Future<void> load({bool refresh = true}) async {
    if (refresh) {
      _page = 1;
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final params = <String, dynamic>{'page': _page, 'limit': 20};
      if (_filterType != null) params['type'] = _filterType;
      if (_filterCategoryId != null) params['category_id'] = _filterCategoryId;
      if (_startDate != null) params['start_date'] = _startDate;
      if (_endDate != null) params['end_date'] = _endDate;
      if (_search != null && _search!.isNotEmpty) params['search'] = _search;

      final res = await dio.get(ApiConstants.transactions, queryParameters: params);
      final result = TransactionListResult.fromJson(res.data['data'] as Map<String, dynamic>);

      if (refresh) {
        _transactions = result.transactions;
      } else {
        _transactions.addAll(result.transactions);
      }
      _totalPages = result.totalPages;
      _totalIncome = result.totalIncome;
      _totalExpense = result.totalExpense;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
    } finally {
      _loading = false;
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !hasMore) return;
    _page++;
    _loadingMore = true;
    notifyListeners();
    await load(refresh: false);
  }

  Future<void> loadCategories({String? type}) async {
    try {
      final params = <String, dynamic>{'limit': 100};
      if (type != null) params['type'] = type;
      final res = await dio.get(ApiConstants.categories, queryParameters: params);
      // Handle both paginated { categories: [...] } and legacy flat array
      final data = res.data['data'];
      final list = data is List
          ? data
          : (data['categories'] as List<dynamic>? ?? []);
      _categories = list
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> create({
    String? categoryId,
    required String type,
    required double amount,
    required String description,
    required String date,
    String? accountId,
    String? toAccountId,
  }) async {
    try {
      final body = <String, dynamic>{
        'type': type,
        'amount': amount,
        'description': description,
        'date': date,
      };
      if (categoryId != null && categoryId.isNotEmpty) body['category_id'] = categoryId;
      if (accountId != null && accountId.isNotEmpty) body['account_id'] = accountId;
      if (toAccountId != null && toAccountId.isNotEmpty) body['to_account_id'] = toAccountId;

      await dio.post(ApiConstants.transactions, data: body);
      await load();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update({
    required String id,
    String? categoryId,
    required String type,
    required double amount,
    required String description,
    required String date,
    String? accountId,
    String? toAccountId,
  }) async {
    try {
      final body = <String, dynamic>{
        'type': type,
        'amount': amount,
        'description': description,
        'date': date,
      };
      if (categoryId != null && categoryId.isNotEmpty) body['category_id'] = categoryId;
      if (accountId != null && accountId.isNotEmpty) body['account_id'] = accountId;
      if (toAccountId != null && toAccountId.isNotEmpty) body['to_account_id'] = toAccountId;

      await dio.put(ApiConstants.transactionById(id), data: body);
      await load();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }

  Future<Uint8List?> exportCsv({required String startDate, required String endDate}) async {
    try {
      final res = await dio.get(
        ApiConstants.transactionsExport,
        queryParameters: {'start_date': startDate, 'end_date': endDate},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data as List<int>);
    } on DioException {
      return null;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await dio.delete(ApiConstants.transactionById(id));
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }
}
