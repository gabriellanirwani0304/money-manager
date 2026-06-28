class MonthlyTrend {
  final String month;
  final double income;
  final double expense;

  const MonthlyTrend({
    required this.month,
    required this.income,
    required this.expense,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) => MonthlyTrend(
        month: json['month'] as String,
        income: (json['income'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
      );
}

class CategoryBreakdown {
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final double amount;
  final int count;
  final double percentage;

  const CategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.amount,
    required this.count,
    required this.percentage,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as Map<String, dynamic>? ?? {};
    return CategoryBreakdown(
      categoryId: cat['id'] as String? ?? '',
      categoryName: cat['name'] as String? ?? '',
      categoryIcon: cat['icon'] as String? ?? 'category',
      categoryColor: cat['color'] as String? ?? '#6366F1',
      amount: (json['amount'] as num).toDouble(),
      count: json['count'] as int? ?? 0,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class MonthlySummary {
  final int month;
  final int year;
  final double income;
  final double expense;
  final double balance;
  final int transactionCount;
  final double avgDailyExpense;

  const MonthlySummary({
    required this.month,
    required this.year,
    required this.income,
    required this.expense,
    required this.balance,
    required this.transactionCount,
    required this.avgDailyExpense,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) => MonthlySummary(
        month: json['month'] as int,
        year: json['year'] as int,
        income: (json['income'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
        balance: (json['balance'] as num).toDouble(),
        transactionCount: json['transaction_count'] as int? ?? 0,
        avgDailyExpense: (json['avg_daily_expense'] as num? ?? 0).toDouble(),
      );
}
