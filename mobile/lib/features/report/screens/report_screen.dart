import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/report_provider.dart';
import '../models/report_models.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/money_card.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging && _tabCtrl.index == 2) {
        final p = context.read<ReportProvider>();
        p.loadWeekly(month: p.month, year: p.year);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Consumer<ReportProvider>(
          builder: (_, p, __) => Text(
            'Laporan ${DateFormatter.formatMonthFull(p.month, p.year)}',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              final p = context.read<ReportProvider>();
              int m = p.month - 1, y = p.year;
              if (m == 0) { m = 12; y--; }
              p.load(month: m, year: y);
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              final p = context.read<ReportProvider>();
              int m = p.month + 1, y = p.year;
              if (m == 13) { m = 1; y++; }
              p.load(month: m, year: y);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Kategori'),
            Tab(text: 'Mingguan'),
            Tab(text: 'Komparasi'),
          ],
        ),
      ),
      body: Consumer<ReportProvider>(
        builder: (_, p, __) {
          if (p.loading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _SummaryTab(provider: p),
              _CategoryTab(provider: p),
              _WeeklyTab(provider: p),
              _CompareTab(provider: p),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final ReportProvider provider;
  const _SummaryTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final s = provider.summary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary cards
          if (s != null) ...[
            Row(
              children: [
                Expanded(
                  child: GradientCard(
                    gradient: AppColors.incomeGradient,
                    shadows: [BoxShadow(color: AppColors.income.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_downward_rounded, color: Colors.white70, size: 20),
                        const SizedBox(height: 8),
                        const Text('Pemasukan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(CurrencyFormatter.compact(s.income),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientCard(
                    gradient: AppColors.expenseGradient,
                    shadows: [BoxShadow(color: AppColors.expense.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_upward_rounded, color: Colors.white70, size: 20),
                        const SizedBox(height: 8),
                        const Text('Pengeluaran', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(CurrencyFormatter.compact(s.expense),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GradientCard(
              gradient: AppColors.primaryGradient,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saldo Bulan Ini', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(CurrencyFormatter.format(s.balance),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${s.transactionCount} transaksi',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('Rata: ${CurrencyFormatter.compact(s.avgDailyExpense)}/hari',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Smart Insights
          if (provider.insights != null) ...[
            _InsightsCard(insights: provider.insights!),
            const SizedBox(height: 20),
          ],

          // Monthly trend chart
          if (provider.trends.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '📊 Tren 6 Bulan'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: _BarChart(trends: provider.trends),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendItem(color: AppColors.income, label: 'Pemasukan'),
                      const SizedBox(width: 20),
                      _LegendItem(color: AppColors.expense, label: 'Pengeluaran'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final ReportProvider provider;
  const _CategoryTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Expense breakdown
          if (provider.breakdownExpense.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '📉 Pengeluaran per Kategori'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _PieChart(
                      breakdowns: provider.breakdownExpense,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...provider.breakdownExpense.take(5).map((b) => _CategoryBar(
                  breakdown: b,
                  color: AppColors.expense,
                )),
            const SizedBox(height: 20),
          ],

          // Income breakdown
          if (provider.breakdownIncome.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '📈 Pemasukan per Kategori'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _PieChart(
                      breakdowns: provider.breakdownIncome,
                      isIncome: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...provider.breakdownIncome.take(5).map((b) => _CategoryBar(
                  breakdown: b,
                  color: AppColors.income,
                )),
          ],
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<MonthlyTrend> trends;
  const _BarChart({required this.trends});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: trends.fold(0.0, (m, t) => m > t.income ? m : (m > t.expense ? m : t.income)) * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trends.length) return const SizedBox();
                final month = trends[idx].month;
                final short = DateFormatter.formatMonth(month).split(' ')[0];
                return Text(short, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary));
              },
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: trends.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.income,
                color: AppColors.income,
                width: 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: e.value.expense,
                color: AppColors.expense,
                width: 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  final List<CategoryBreakdown> breakdowns;
  final bool isIncome;
  const _PieChart({required this.breakdowns, this.isIncome = false});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 48,
        sections: breakdowns.take(6).toList().asMap().entries.map((e) {
          final color = _parseColor(e.value.categoryColor);
          return PieChartSectionData(
            value: e.value.percentage,
            color: color,
            title: '${e.value.percentage.toStringAsFixed(0)}%',
            radius: 56,
            titleStyle: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            badgeWidget: e.key == 0
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Icon(
                      isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  )
                : null,
            badgePositionPercentageOffset: 1.2,
          );
        }).toList(),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

class _CategoryBar extends StatelessWidget {
  final CategoryBreakdown breakdown;
  final Color color;
  const _CategoryBar({required this.breakdown, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CategoryIconWidget(
              icon: breakdown.categoryIcon,
              color: breakdown.categoryColor,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(breakdown.categoryName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        CurrencyFormatter.compact(breakdown.amount),
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: breakdown.percentage / 100,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation(
                          _parseColor(breakdown.categoryColor)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${breakdown.percentage.toStringAsFixed(1)}% • ${breakdown.count} transaksi',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _WeeklyTab extends StatelessWidget {
  final ReportProvider provider;
  const _WeeklyTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.weeklyLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (provider.weekly.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_rounded, size: 64, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text('Belum ada data mingguan',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.loadWeekly(),
              child: const Text('Muat Data'),
            ),
          ],
        ),
      );
    }

    final weeks = provider.weekly;
    final maxVal = weeks.fold(0.0, (m, w) => m > w.income ? m > w.expense ? m : w.expense : w.income > w.expense ? w.income : w.expense);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Bar chart
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: '📅 Pendapatan & Pengeluaran per Minggu'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxVal * 1.25,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= weeks.length) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('M${weeks[idx].week}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: AppColors.divider, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: weeks.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.income,
                              color: AppColors.income,
                              width: 12,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            BarChartRodData(
                              toY: e.value.expense,
                              color: AppColors.expense,
                              width: 12,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendItem(color: AppColors.income, label: 'Pemasukan'),
                    const SizedBox(width: 20),
                    _LegendItem(color: AppColors.expense, label: 'Pengeluaran'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Summary per week
          ...weeks.map((w) {
            final net = w.income - w.expense;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Minggu ${w.week}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(
                          net >= 0 ? '+${CurrencyFormatter.compact(net)}' : CurrencyFormatter.compact(net),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: net >= 0 ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pemasukan', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(CurrencyFormatter.compact(w.income),
                                  style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pengeluaran', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              Text(CurrencyFormatter.compact(w.expense),
                                  style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final ReportInsights insights;
  const _InsightsCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final trendIcon = switch (insights.trend) {
      'improving' => ('📈', AppColors.income),
      'worsening' => ('📉', AppColors.expense),
      _ => ('➡️', AppColors.textSecondary),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '💡 Smart Insights'),
          const SizedBox(height: 12),

          // Savings rate
          _InsightRow(
            icon: '💰',
            label: 'Tingkat Tabungan',
            value: '${insights.savingsRate.toStringAsFixed(1)}%',
            valueColor: insights.savingsRate >= 20 ? AppColors.income : AppColors.warning,
          ),

          // Top expense category
          if (insights.topCategoryName != null) ...[
            const Divider(height: 16),
            _InsightRow(
              icon: '🏆',
              label: 'Kategori Terbesar',
              value: '${insights.topCategoryName} (${insights.topCategoryPercent?.toStringAsFixed(0)}%)',
            ),
          ],

          // Biggest single expense
          if (insights.biggestExpenseDesc != null) ...[
            const Divider(height: 16),
            _InsightRow(
              icon: '💸',
              label: 'Pengeluaran Terbesar',
              value: insights.biggestExpenseDesc!,
            ),
          ],

          // Month over month
          if (insights.expenseChangePercent != null) ...[
            const Divider(height: 16),
            _InsightRow(
              icon: trendIcon.$1,
              label: 'vs Bulan Lalu',
              value: insights.expenseChangePercent! > 0
                  ? '+${insights.expenseChangePercent!.toStringAsFixed(1)}% pengeluaran'
                  : '${insights.expenseChangePercent!.toStringAsFixed(1)}% pengeluaran',
              valueColor: insights.expenseChangePercent! > 0 ? AppColors.expense : AppColors.income,
            ),
          ],

          // Budget exceeded
          if (insights.budgetExceeded.isNotEmpty) ...[
            const Divider(height: 16),
            _InsightRow(
              icon: '⚠️',
              label: 'Budget Terlampaui',
              value: insights.budgetExceeded.join(', '),
              valueColor: AppColors.expense,
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Komparasi Bulan ────────────────────────────────────────────────────────

class _CompareTab extends StatefulWidget {
  final ReportProvider provider;
  const _CompareTab({required this.provider});

  @override
  State<_CompareTab> createState() => _CompareTabState();
}

class _CompareTabState extends State<_CompareTab> {
  static const _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  late List<_SlotState> _slots;
  final List<MonthlySummary?> _results = [];
  bool _loading = false;
  static const _colors = [AppColors.primary, AppColors.income, AppColors.expense];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _slots = [
      _SlotState(month: now.month, year: now.year),
      _SlotState(
        month: now.month == 1 ? 12 : now.month - 1,
        year: now.month == 1 ? now.year - 1 : now.year,
      ),
    ];
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _results.clear(); });
    final futures = _slots.map((s) => widget.provider.fetchSummary(s.month, s.year));
    final list = await Future.wait(futures);
    if (mounted) setState(() { _results.addAll(list); _loading = false; });
  }

  String _label(_SlotState s) => '${_monthNames[s.month]} ${s.year}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List.generate(5, (i) => now.year - i);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot pickers
          ...List.generate(_slots.length, (i) {
            final s = _slots[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 12, height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: _colors[i], shape: BoxShape.circle),
                ),
                Text('Bulan ${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int>(
                    value: s.month,
                    isExpanded: true,
                    isDense: true,
                    items: List.generate(12, (mi) => DropdownMenuItem(
                      value: mi + 1,
                      child: Text(_monthNames[mi + 1], style: const TextStyle(fontSize: 13)),
                    )),
                    onChanged: (v) => setState(() => s.month = v ?? s.month),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int>(
                    value: s.year,
                    isExpanded: true,
                    isDense: true,
                    items: years.map((y) => DropdownMenuItem(
                      value: y,
                      child: Text('$y', style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (v) => setState(() => s.year = v ?? s.year),
                  ),
                ),
                if (_slots.length > 2)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () => setState(() => _slots.removeAt(i)),
                    visualDensity: VisualDensity.compact,
                    color: AppColors.expense,
                  ),
              ]),
            );
          }),

          Row(children: [
            if (_slots.length < 3)
              TextButton.icon(
                onPressed: () {
                  final last = _slots.last;
                  setState(() => _slots.add(_SlotState(
                    month: last.month == 1 ? 12 : last.month - 1,
                    year: last.month == 1 ? last.year - 1 : last.year,
                  )));
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Tambah bulan', style: TextStyle(fontSize: 13)),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _loading ? null : _fetch,
              child: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Bandingkan'),
            ),
          ]),

          if (_results.isNotEmpty && _results.length == _slots.length) ...[
            const SizedBox(height: 20),
            const Text('Perbandingan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),

            // Bar chart
            SizedBox(
              height: 200,
              child: _CompareChart(results: _results, labels: _slots.map(_label).toList()),
            ),
            const SizedBox(height: 16),

            // Table
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // Header
                  _TableRow(
                    cells: ['Metrik', ..._slots.map(_label)],
                    isHeader: true,
                  ),
                  const Divider(height: 1),
                  for (final metric in [
                    ('Pemasukan', (MonthlySummary s) => s.income, true),
                    ('Pengeluaran', (MonthlySummary s) => s.expense, false),
                    ('Selisih', (MonthlySummary s) => s.balance, true),
                    ('Transaksi', (MonthlySummary s) => s.transactionCount.toDouble(), null),
                    ('Rata-rata/Hari', (MonthlySummary s) => s.avgDailyExpense, false),
                  ]) ...[
                    _MetricRow(
                      label: metric.$1,
                      values: _results.map((r) => r == null ? null : metric.$2(r)).toList(),
                      higherIsBetter: metric.$3,
                      isCount: metric.$3 == null,
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlotState {
  int month;
  int year;
  _SlotState({required this.month, required this.year});
}

class _TableRow extends StatelessWidget {
  final List<String> cells;
  final bool isHeader;
  const _TableRow({required this.cells, this.isHeader = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      children: cells.asMap().entries.map((e) => Expanded(
        child: Text(
          e.value,
          textAlign: e.key == 0 ? TextAlign.left : TextAlign.right,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
            color: isHeader ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      )).toList(),
    ),
  );
}

class _MetricRow extends StatelessWidget {
  final String label;
  final List<double?> values;
  final bool? higherIsBetter; // null = no highlight
  final bool isCount;

  const _MetricRow({
    required this.label,
    required this.values,
    this.higherIsBetter,
    this.isCount = false,
  });

  @override
  Widget build(BuildContext context) {
    final nonNull = values.whereType<double>().toList();
    int? bestIdx;
    if (higherIsBetter != null && nonNull.isNotEmpty) {
      final best = higherIsBetter! ? nonNull.reduce((a, b) => a > b ? a : b)
          : nonNull.reduce((a, b) => a < b ? a : b);
      bestIdx = values.indexWhere((v) => v == best);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          ...values.asMap().entries.map((e) {
            final v = e.value;
            final isBest = e.key == bestIdx;
            final text = v == null ? '—' : isCount
                ? v.toInt().toString()
                : CurrencyFormatter.compact(v);
            return Expanded(child: Text(
              isBest ? '✓ $text' : text,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBest ? FontWeight.w700 : FontWeight.normal,
                color: isBest ? AppColors.income : AppColors.textPrimary,
              ),
            ));
          }),
        ],
      ),
    );
  }
}

class _CompareChart extends StatelessWidget {
  final List<MonthlySummary?> results;
  final List<String> labels;
  const _CompareChart({required this.results, required this.labels});

  static const _colors = [AppColors.primary, AppColors.income, AppColors.expense];

  @override
  Widget build(BuildContext context) {
    final metrics = ['Pemasukan', 'Pengeluaran', 'Selisih'];
    final groups = List.generate(metrics.length, (mi) {
      return BarChartGroupData(
        x: mi,
        barRods: List.generate(results.length, (ri) {
          final r = results[ri];
          double value = 0;
          if (r != null) {
            if (mi == 0) value = r.income;
            if (mi == 1) value = r.expense;
            if (mi == 2) value = r.balance;
          }
          return BarChartRodData(
            toY: value,
            color: _colors[ri % _colors.length],
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          );
        }),
        barsSpace: 4,
      );
    });

    return BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barGroups: groups,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) => Text(
              metrics[v.toInt()],
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    ));
  }
}
