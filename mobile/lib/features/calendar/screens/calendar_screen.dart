import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/money_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _now = DateTime.now();
  late int _month;
  late int _year;

  List<Map<String, dynamic>> _rawTxs = [];
  bool _loading = false;
  String? _selectedDate;

  static const _dayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  static const _monthNames = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _month = _now.month;
    _year = _now.year;
    _load();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String get _startDate => '$_year-${_pad(_month)}-01';
  String get _endDate {
    final last = DateTime(_year, _month + 1, 0).day;
    return '$_year-${_pad(_month)}-${_pad(last)}';
  }

  Future<void> _load() async {
    setState(() { _loading = true; _selectedDate = null; });
    try {
      final res = await dio.get(ApiConstants.transactions, queryParameters: {
        'start_date': _startDate,
        'end_date': _endDate,
        'limit': 500,
      });
      final data = res.data['data'];
      final list = data is Map ? (data['transactions'] as List<dynamic>? ?? []) : (data as List<dynamic>? ?? []);
      setState(() => _rawTxs = list.cast<Map<String, dynamic>>());
    } on DioException catch (_) {
      setState(() => _rawTxs = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) { _month = 12; _year--; } else { _month--; }
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) { _month = 1; _year++; } else { _month++; }
    });
    _load();
  }

  // Build day-level aggregated map
  Map<String, _DayData> get _dayMap {
    final map = <String, _DayData>{};
    for (final tx in _rawTxs) {
      final date = (tx['date'] as String).substring(0, 10);
      final type = tx['type'] as String? ?? '';
      final amount = (tx['amount'] as num? ?? 0).toDouble();
      map.putIfAbsent(date, () => _DayData());
      if (type == 'income') map[date]!.income += amount;
      if (type == 'expense') map[date]!.expense += amount;
      if (type == 'transfer') map[date]!.transferCount++;
      map[date]!.count++;
    }
    return map;
  }

  List<Map<String, dynamic>> get _selectedTxs {
    if (_selectedDate == null) return [];
    return _rawTxs.where((t) => (t['date'] as String).startsWith(_selectedDate!)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dayMap = _dayMap;
    final lastDay = DateTime(_year, _month + 1, 0).day;
    final firstDow = DateTime(_year, _month, 1).weekday % 7; // Sunday=0
    final totalCells = ((firstDow + lastDay) / 7).ceil() * 7;

    final totalIncome = dayMap.values.fold(0.0, (s, d) => s + d.income);
    final totalExpense = dayMap.values.fold(0.0, (s, d) => s + d.expense);
    final net = totalIncome - totalExpense;
    final activeDays = dayMap.length;
    final maxExpense = dayMap.values.fold(0.0, (m, d) => d.expense > m ? d.expense : m);

    // No-spend streak
    int streak = 0;
    for (int d = lastDay; d >= 1; d--) {
      final ds = '$_year-${_pad(_month)}-${_pad(d)}';
      final date = DateTime(_year, _month, d);
      if (date.isAfter(_now)) continue;
      if ((dayMap[ds]?.expense ?? 0) > 0) break;
      streak++;
    }

    // Biggest expense day
    MapEntry<String, _DayData>? biggestDay;
    for (final e in dayMap.entries) {
      if (biggestDay == null || e.value.expense > biggestDay.value.expense) biggestDay = e;
    }

    final todayStr = '${_now.year}-${_pad(_now.month)}-${_pad(_now.day)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
              onPressed: _prevMonth,
              visualDensity: VisualDensity.compact,
            ),
            Text(
              '${_monthNames[_month]} $_year',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
              onPressed: _nextMonth,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day header
                  Row(
                    children: List.generate(7, (i) => Expanded(
                      child: Center(
                        child: Text(
                          _dayNames[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: i == 0 ? Colors.red[400] : i == 6 ? Colors.blue[400] : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 4),

                  // Calendar grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.72,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                    ),
                    itemCount: totalCells,
                    itemBuilder: (ctx, i) {
                      final day = i - firstDow + 1;
                      if (day < 1 || day > lastDay) return const SizedBox();
                      final ds = '$_year-${_pad(_month)}-${_pad(day)}';
                      final data = dayMap[ds];
                      final isToday = ds == todayStr;
                      final isSelected = ds == _selectedDate;
                      final dow = (firstDow + day - 1) % 7;

                      // Heatmap intensity
                      final heat = (data?.expense ?? 0) > 0 && maxExpense > 0
                          ? (data!.expense / maxExpense).clamp(0.05, 1.0)
                          : 0.0;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedDate = isSelected ? null : ds),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : heat > 0
                                    ? Color.lerp(Colors.red[50], Colors.red[300], heat)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.divider,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: isToday
                                    ? BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)
                                    : null,
                                child: Center(
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isToday
                                          ? Colors.white
                                          : dow == 0
                                              ? Colors.red[400]
                                              : dow == 6
                                                  ? Colors.blue[400]
                                                  : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              if (data != null) ...[
                                const SizedBox(height: 2),
                                if (data.income > 0)
                                  Text(
                                    '+${CurrencyFormatter.compact(data.income)}',
                                    style: const TextStyle(fontSize: 7, color: AppColors.income, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (data.expense > 0)
                                  Text(
                                    '-${CurrencyFormatter.compact(data.expense)}',
                                    style: const TextStyle(fontSize: 7, color: AppColors.expense, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (data.transferCount > 0 && data.income == 0 && data.expense == 0)
                                  Text(
                                    '⇄${data.transferCount}',
                                    style: TextStyle(fontSize: 7, color: Colors.blue[600], fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Summary row
                  Row(children: [
                    Expanded(child: _SumCard(label: 'Pemasukan', value: totalIncome, color: AppColors.income)),
                    const SizedBox(width: 8),
                    Expanded(child: _SumCard(label: 'Pengeluaran', value: totalExpense, color: AppColors.expense)),
                    const SizedBox(width: 8),
                    Expanded(child: _SumCard(
                      label: 'Selisih',
                      value: net,
                      color: net >= 0 ? AppColors.income : AppColors.expense,
                    )),
                  ]),

                  const SizedBox(height: 12),

                  // Stats row
                  Row(children: [
                    Expanded(child: _StatCard(
                      icon: Icons.calendar_today_rounded,
                      label: 'Hari aktif',
                      value: '$activeDays hari',
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(
                      icon: Icons.trending_down_rounded,
                      iconColor: AppColors.expense,
                      label: 'Terbesar',
                      value: biggestDay != null && biggestDay.value.expense > 0
                          ? CurrencyFormatter.compact(biggestDay.value.expense)
                          : '—',
                      sub: biggestDay != null ? biggestDay.key.substring(8) : '',
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: streak >= 3 ? Colors.orange : AppColors.textHint,
                      label: 'No-spend',
                      value: '$streak hari',
                    )),
                  ]),

                  // Selected day detail
                  if (_selectedDate != null) ...[
                    const SizedBox(height: 16),
                    _DayDetail(
                      date: _selectedDate!,
                      txs: _selectedTxs,
                      data: dayMap[_selectedDate!],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _DayData {
  double income = 0;
  double expense = 0;
  int transferCount = 0;
  int count = 0;
}

class _SumCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SumCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.compact(value),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;
  final String? sub;
  const _StatCard({required this.icon, this.iconColor, required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor ?? AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        if (sub != null && sub!.isNotEmpty)
          Text(sub!, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
      ],
    ),
  );
}

class _DayDetail extends StatelessWidget {
  final String date;
  final List<Map<String, dynamic>> txs;
  final _DayData? data;
  const _DayDetail({required this.date, required this.txs, this.data});

  @override
  Widget build(BuildContext context) {
    final parts = date.split('-');
    final label = '${parts[2]}/${parts[1]}/${parts[0]}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(width: 8),
            Text('${txs.length} transaksi', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            if (data != null) ...[
              if (data!.income > 0) Text('+${CurrencyFormatter.compact(data!.income)}',
                  style: const TextStyle(color: AppColors.income, fontSize: 12, fontWeight: FontWeight.w600)),
              if (data!.income > 0 && data!.expense > 0) const SizedBox(width: 8),
              if (data!.expense > 0) Text('-${CurrencyFormatter.compact(data!.expense)}',
                  style: const TextStyle(color: AppColors.expense, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ]),
          const SizedBox(height: 12),
          if (txs.isEmpty)
            const Text('Tidak ada transaksi', style: TextStyle(color: AppColors.textSecondary))
          else
            ...txs.map((tx) {
              final type = tx['type'] as String? ?? '';
              final amount = (tx['amount'] as num? ?? 0).toDouble();
              final cat = tx['category'] as Map<String, dynamic>?;
              final acc = tx['account'] as Map<String, dynamic>?;
              final toAcc = tx['to_account'] as Map<String, dynamic>?;
              final desc = tx['description'] as String? ?? '';
              final color = type == 'income' ? AppColors.income : type == 'transfer' ? AppColors.primary : AppColors.expense;
              final sign = type == 'income' ? '+' : type == 'transfer' ? '⇄' : '-';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: type == 'transfer'
                        ? Icon(Icons.swap_horiz_rounded, size: 16, color: color)
                        : Text(cat?['icon'] as String? ?? '💸', style: const TextStyle(fontSize: 14))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      type == 'transfer'
                          ? '${acc?['name'] ?? '?'} → ${toAcc?['name'] ?? '?'}'
                          : cat?['name'] as String? ?? '—',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (desc.isNotEmpty)
                      Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ])),
                  Text(
                    '$sign${CurrencyFormatter.format(amount)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }
}
