import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../transaction/models/transaction_models.dart';

enum DeleteResult { success, conflict, error }

class CategoryProvider extends ChangeNotifier {
  List<CategoryModel> _categories = [];
  bool _loading = false;
  String? _error;

  List<CategoryModel> get categories => _categories;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load({String? type}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{'limit': 200};
      if (type != null) params['type'] = type;
      final res = await dio.get(ApiConstants.categories, queryParameters: params);
      final data = res.data['data'];
      final list = data is List ? data : (data['categories'] as List<dynamic>? ?? []);
      _categories = list
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
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
    required String icon,
    String color = '#6366F1',
  }) async {
    try {
      await dio.post(ApiConstants.categories, data: {
        'name': name,
        'type': type,
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

  Future<bool> update(String id, {
    required String name,
    required String icon,
    required String color,
  }) async {
    try {
      await dio.put(ApiConstants.categoryById(id), data: {
        'name': name,
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

  Future<DeleteResult> delete(String id) async {
    try {
      await dio.delete(ApiConstants.categoryById(id));
      _categories.removeWhere((c) => c.id == id);
      notifyListeners();
      return DeleteResult.success;
    } on DioException catch (e) {
      final apiErr = ApiException.fromDio(e);
      _error = apiErr.message;
      notifyListeners();
      final msg = apiErr.message.toLowerCase();
      if (msg.contains('transaction') || msg.contains('transaksi') || e.response?.statusCode == 409) {
        return DeleteResult.conflict;
      }
      return DeleteResult.error;
    }
  }

  Future<bool> reassignAndDelete(String fromId, String toId) async {
    try {
      // Fetch all transactions for this category
      final res = await dio.get(
        ApiConstants.transactions,
        queryParameters: {'category_id': fromId, 'limit': 1000},
      );
      final data = res.data['data'];
      final List<dynamic> txList = data is List
          ? data
          : (data['transactions'] as List<dynamic>? ?? []);

      // Reassign each transaction
      for (final tx in txList) {
        final txId = tx['id'] as String;
        await dio.put(ApiConstants.transactionById(txId), data: {
          'category_id': toId,
          'amount': tx['amount'],
          'type': tx['type'],
          'description': tx['description'] ?? '',
          'date': tx['date'],
          if (tx['account_id'] != null) 'account_id': tx['account_id'],
        });
      }

      // Now delete the (now empty) category
      await dio.delete(ApiConstants.categoryById(fromId));
      _categories.removeWhere((c) => c.id == fromId);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
      notifyListeners();
      return false;
    }
  }
}
