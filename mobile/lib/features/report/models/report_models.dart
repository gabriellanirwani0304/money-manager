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

class ReportInsights {
  final String? topCategoryName;
  final double? topCategoryAmount;
  final double? topCategoryPercent;
  final double? biggestExpenseAmount;
  final String? biggestExpenseDesc;
  final double? expenseChangePercent;
  final double? incomeChangePercent;
  final String? trend;
  final List<String> budgetExceeded;
  final double savingsRate;

  const ReportInsights({
    this.topCategoryName,
    this.topCategoryAmount,
    this.topCategoryPercent,
    this.biggestExpenseAmount,
    this.biggestExpenseDesc,
    this.expenseChangePercent,
    this.incomeChangePercent,
    this.trend,
    required this.budgetExceeded,
    required this.savingsRate,
  });

  factory ReportInsights.fromJson(Map<String, dynamic> json) {
    final top = json['top_expense_category'] as Map<String, dynamic>? ?? {};
    final biggest = json['biggest_single_expense'] as Map<String, dynamic>? ?? {};
    final mom = json['month_over_month'] as Map<String, dynamic>? ?? {};
    return ReportInsights(
      topCategoryName: top['category_name'] as String?,
      topCategoryAmount: (top['amount'] as num?)?.toDouble(),
      topCategoryPercent: (top['percentage'] as num?)?.toDouble(),
      biggestExpenseAmount: (biggest['amount'] as num?)?.toDouble(),
      biggestExpenseDesc: biggest['description'] as String?,
      expenseChangePercent: (mom['expense_change_percent'] as num?)?.toDouble(),
      incomeChangePercent: (mom['income_change_percent'] as num?)?.toDouble(),
      trend: mom['trend'] as String?,
      budgetExceeded: (json['budget_exceeded_categories'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      savingsRate: (json['savings_rate'] as num? ?? 0).toDouble(),
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
