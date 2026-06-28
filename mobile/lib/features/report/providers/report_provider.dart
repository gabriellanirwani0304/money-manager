import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/report_models.dart';

class ReportProvider extends ChangeNotifier {
  List<MonthlyTrend> _trends = [];
  List<CategoryBreakdown> _breakdownExpense = [];
  List<CategoryBreakdown> _breakdownIncome = [];
  MonthlySummary? _summary;
  bool _loading = false;
  String? _error;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  List<MonthlyTrend> get trends => _trends;
  List<CategoryBreakdown> get breakdownExpense => _breakdownExpense;
  List<CategoryBreakdown> get breakdownIncome => _breakdownIncome;
  MonthlySummary? get summary => _summary;
  bool get loading => _loading;
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
      final params = {'month': _month, 'year': _year};

      final results = await Future.wait([
        dio.get(ApiConstants.reportSummary, queryParameters: params),
        dio.get(ApiConstants.reportMonthly),
        dio.get(ApiConstants.reportByCategory, queryParameters: {...params, 'type': 'expense'}),
        dio.get(ApiConstants.reportByCategory, queryParameters: {...params, 'type': 'income'}),
      ]);

      _summary = MonthlySummary.fromJson(results[0].data['data'] as Map<String, dynamic>);

      _trends = (results[1].data['data'] as List<dynamic>? ?? [])
          .map((e) => MonthlyTrend.fromJson(e as Map<String, dynamic>))
          .toList();

      _breakdownExpense = (results[2].data['data'] as List<dynamic>? ?? [])
          .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
          .toList();

      _breakdownIncome = (results[3].data['data'] as List<dynamic>? ?? [])
          .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
