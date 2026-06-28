class CategoryInfo {
  final String id;
  final String name;
  final String icon;
  final String color;

  const CategoryInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) => CategoryInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String,
        icon: json['icon'] as String? ?? 'category',
        color: json['color'] as String? ?? '#6366F1',
      );
}

class RecentTransaction {
  final String id;
  final String type;
  final double amount;
  final String description;
  final String date;
  final CategoryInfo category;

  const RecentTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.category,
  });

  factory RecentTransaction.fromJson(Map<String, dynamic> json) => RecentTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String? ?? '',
        date: json['date'] as String,
        category: CategoryInfo.fromJson(json['category'] as Map<String, dynamic>),
      );
}

class BudgetAlert {
  final String categoryName;
  final double budgetAmount;
  final double spent;
  final double percentage;

  const BudgetAlert({
    required this.categoryName,
    required this.budgetAmount,
    required this.spent,
    required this.percentage,
  });

  factory BudgetAlert.fromJson(Map<String, dynamic> json) => BudgetAlert(
        categoryName: json['category_name'] as String,
        budgetAmount: (json['budget_amount'] as num).toDouble(),
        spent: (json['spent'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class TopExpense {
  final String categoryName;
  final double amount;
  final double percentage;

  const TopExpense({
    required this.categoryName,
    required this.amount,
    required this.percentage,
  });

  factory TopExpense.fromJson(Map<String, dynamic> json) => TopExpense(
        categoryName: json['category_name'] as String,
        amount: (json['amount'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class DashboardData {
  final double balance;
  final double income;
  final double expense;
  final List<RecentTransaction> recentTransactions;
  final List<BudgetAlert> budgetAlerts;
  final List<TopExpense> topExpenses;

  const DashboardData({
    required this.balance,
    required this.income,
    required this.expense,
    required this.recentTransactions,
    required this.budgetAlerts,
    required this.topExpenses,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        balance: (json['balance'] as num).toDouble(),
        income: (json['income'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
        recentTransactions: (json['recent_transactions'] as List<dynamic>? ?? [])
            .map((e) => RecentTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        budgetAlerts: (json['budget_alerts'] as List<dynamic>? ?? [])
            .map((e) => BudgetAlert.fromJson(e as Map<String, dynamic>))
            .toList(),
        topExpenses: (json['top_expenses'] as List<dynamic>? ?? [])
            .map((e) => TopExpense.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
