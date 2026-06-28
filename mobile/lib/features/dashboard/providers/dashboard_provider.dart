import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/dashboard_models.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardData? _data;
  bool _loading = false;
  String? _error;

  DashboardData? get data => _data;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load({int? month, int? year}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, dynamic>{};
      if (month != null) params['month'] = month;
      if (year != null) params['year'] = year;

      final res = await dio.get(ApiConstants.dashboard, queryParameters: params);
      _data = DashboardData.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
