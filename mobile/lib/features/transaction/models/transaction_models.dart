class CategoryModel {
  final String id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final bool isDefault;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isDefault,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        icon: json['icon'] as String? ?? 'category',
        color: json['color'] as String? ?? '#6366F1',
        isDefault: json['is_default'] as bool? ?? false,
      );
}

class TransactionModel {
  final String id;
  final String categoryId;
  final CategoryModel? category;
  final String type;
  final double amount;
  final String description;
  final String date;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.categoryId,
    this.category,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
  });

  bool get isIncome => type == 'income';

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
        id: json['id'] as String,
        categoryId: json['category_id'] as String,
        category: json['category'] != null
            ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String? ?? '',
        date: json['date'] as String,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class TransactionListResult {
  final List<TransactionModel> transactions;
  final int total;
  final int page;
  final int totalPages;
  final double totalIncome;
  final double totalExpense;

  const TransactionListResult({
    required this.transactions,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.totalIncome,
    required this.totalExpense,
  });

  factory TransactionListResult.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    return TransactionListResult(
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: pagination['total'] as int? ?? 0,
      page: pagination['page'] as int? ?? 1,
      totalPages: pagination['total_pages'] as int? ?? 1,
      totalIncome: (summary['total_income'] as num?)?.toDouble() ?? 0,
      totalExpense: (summary['total_expense'] as num?)?.toDouble() ?? 0,
    );
  }
}
