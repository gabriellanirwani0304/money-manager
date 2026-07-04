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
  ReportInsights? _insights;
  List<WeekSummary> _weekly = [];
  List<DailyCashFlow> _daily = [];
  List<CategoryTrendSeries> _categoryTrend = [];
  List<String> _categoryTrendMonths = [];
  bool _loading = false;
  bool _weeklyLoading = false;
  bool _dailyLoading = false;
  bool _catTrendLoading = false;
  String? _error;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  List<MonthlyTrend> get trends => _trends;
  List<CategoryBreakdown> get breakdownExpense => _breakdownExpense;
  List<CategoryBreakdown> get breakdownIncome => _breakdownIncome;
  MonthlySummary? get summary => _summary;
  ReportInsights? get insights => _insights;
  List<WeekSummary> get weekly => _weekly;
  List<DailyCashFlow> get daily => _daily;
  List<CategoryTrendSeries> get categoryTrend => _categoryTrend;
  List<String> get categoryTrendMonths => _categoryTrendMonths;
  bool get loading => _loading;
  bool get weeklyLoading => _weeklyLoading;
  bool get dailyLoading => _dailyLoading;
  bool get catTrendLoading => _catTrendLoading;
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
        dio.get(ApiConstants.reportInsights),
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

      try {
        _insights = ReportInsights.fromJson(results[4].data['data'] as Map<String, dynamic>);
      } catch (_) {
        _insights = null;
      }
    } on DioException catch (e) {
      _error = ApiException.fromDio(e).message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadDaily({int? month, int? year}) async {
    final m = month ?? _month;
    final y = year ?? _year;

    _dailyLoading = true;
    _daily = [];
    notifyListeners();

    try {
      final lastDay = DateTime(y, m + 1, 0).day;
      final startDate = '$y-${m.toString().padLeft(2, '0')}-01';
      final endDate = '$y-${m.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

      final res = await dio.get(
        ApiConstants.transactions,
        queryParameters: {'start_date': startDate, 'end_date': endDate, 'limit': 1000},
      );

      final txList = res.data['data']['transactions'] as List<dynamic>? ?? [];
      final dayMap = <int, Map<String, double>>{};
      for (int d = 1; d <= lastDay; d++) {
        dayMap[d] = {'income': 0, 'expense': 0};
      }

      for (final tx in txList) {
        final date = DateTime.tryParse(tx['date'] as String? ?? '');
        if (date == null) continue;
        final type = tx['type'] as String? ?? '';
        final amount = (tx['amount'] as num? ?? 0).toDouble();
        if (type == 'income') dayMap[date.day]!['income'] = dayMap[date.day]!['income']! + amount;
        if (type == 'expense') dayMap[date.day]!['expense'] = dayMap[date.day]!['expense']! + amount;
      }

      _daily = dayMap.entries
          .map((e) => DailyCashFlow(day: e.key, income: e.value['income']!, expense: e.value['expense']!))
          .toList();
    } on DioException catch (_) {
    } finally {
      _dailyLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategoryTrend({String type = 'expense'}) async {
    _catTrendLoading = true;
    _categoryTrend = [];
    _categoryTrendMonths = [];
    notifyListeners();

    try {
      final now = DateTime.now();
      final months = List.generate(6, (i) {
        int m = now.month - 5 + i;
        int y = now.year;
        while (m <= 0) { m += 12; y--; }
        while (m > 12) { m -= 12; y++; }
        return (m, y);
      });

      const shortMonths = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      _categoryTrendMonths = months.map((my) => shortMonths[my.$1]).toList();

      final results = await Future.wait(months.map((my) => dio.get(
        ApiConstants.reportByCategory,
        queryParameters: {'month': my.$1, 'year': my.$2, 'type': type},
      )));

      // Build series map: categoryId → amounts list
      final seriesMap = <String, CategoryTrendSeries>{};
      for (int i = 0; i < results.length; i++) {
        final breakdowns = (results[i].data['data'] as List<dynamic>? ?? [])
            .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final b in breakdowns) {
          if (!seriesMap.containsKey(b.categoryId)) {
            seriesMap[b.categoryId] = CategoryTrendSeries(
              id: b.categoryId,
              name: b.categoryName,
              icon: b.categoryIcon,
              color: b.categoryColor,
              amounts: List.filled(6, 0),
            );
          }
          final amounts = List<double>.from(seriesMap[b.categoryId]!.amounts);
          amounts[i] = b.amount;
          seriesMap[b.categoryId] = CategoryTrendSeries(
            id: b.categoryId,
            name: b.categoryName,
            icon: b.categoryIcon,
            color: b.categoryColor,
            amounts: amounts,
          );
        }
      }

      // Sort by total amount, take top 5
      final sorted = seriesMap.values.toList()
        ..sort((a, b) => b.amounts.fold(0.0, (s, v) => s + v)
            .compareTo(a.amounts.fold(0.0, (s, v) => s + v)));
      _categoryTrend = sorted.take(5).toList();
    } on DioException catch (_) {
    } finally {
      _catTrendLoading = false;
      notifyListeners();
    }
  }

  Future<MonthlySummary?> fetchSummary(int month, int year) async {
    try {
      final res = await dio.get(ApiConstants.reportSummary,
          queryParameters: {'month': month, 'year': year});
      return MonthlySummary.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  Future<void> loadWeekly({int? month, int? year}) async {
    final m = month ?? _month;
    final y = year ?? _year;

    _weeklyLoading = true;
    _weekly = [];
    notifyListeners();

    try {
      final lastDay = DateTime(y, m + 1, 0).day;
      final startDate = '$y-${m.toString().padLeft(2, '0')}-01';
      final endDate = '$y-${m.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

      final res = await dio.get(
        ApiConstants.transactions,
        queryParameters: {'start_date': startDate, 'end_date': endDate, 'limit': 500},
      );

      final txList = res.data['data']['transactions'] as List<dynamic>? ?? [];

      // Group into 5 weekly blocks
      final weeks = <int, Map<String, double>>{
        1: {'income': 0, 'expense': 0},
        2: {'income': 0, 'expense': 0},
        3: {'income': 0, 'expense': 0},
        4: {'income': 0, 'expense': 0},
        5: {'income': 0, 'expense': 0},
      };

      for (final tx in txList) {
        final date = DateTime.tryParse(tx['date'] as String? ?? '');
        if (date == null) continue;
        final week = ((date.day - 1) ~/ 7) + 1;
        final type = tx['type'] as String? ?? '';
        final amount = (tx['amount'] as num? ?? 0).toDouble();
        if (type == 'income') weeks[week]!['income'] = (weeks[week]!['income']!) + amount;
        if (type == 'expense') weeks[week]!['expense'] = (weeks[week]!['expense']!) + amount;
      }

      final dayRanges = ['1–7', '8–14', '15–21', '22–28', '29–$lastDay'];
      _weekly = weeks.entries
          .where((e) => e.key <= 5 && (e.value['income']! > 0 || e.value['expense']! > 0))
          .map((e) => WeekSummary(
                week: e.key,
                label: 'Minggu ${e.key}\n${dayRanges[e.key - 1]}',
                income: e.value['income']!,
                expense: e.value['expense']!,
              ))
          .toList();
    } on DioException catch (_) {
    } finally {
      _weeklyLoading = false;
      notifyListeners();
    }
  }
}
