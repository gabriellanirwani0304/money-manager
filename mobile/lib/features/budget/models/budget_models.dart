import '../../transaction/models/transaction_models.dart';

class BudgetModel {
  final String id;
  final String categoryId;
  final CategoryModel? category;
  final double budgetAmount;
  final double spent;
  final double remaining;
  final double percentage;
  final String status;
  final int month;
  final int year;

  const BudgetModel({
    required this.id,
    required this.categoryId,
    this.category,
    required this.budgetAmount,
    required this.spent,
    required this.remaining,
    required this.percentage,
    required this.status,
    required this.month,
    required this.year,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) => BudgetModel(
        id: json['id'] as String,
        categoryId: json['category_id'] as String,
        category: json['category'] != null
            ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        budgetAmount: (json['budget_amount'] as num).toDouble(),
        spent: (json['spent'] as num? ?? 0).toDouble(),
        remaining: (json['remaining'] as num? ?? 0).toDouble(),
        percentage: (json['percentage'] as num? ?? 0).toDouble(),
        status: json['status'] as String? ?? 'safe',
        month: json['month'] as int,
        year: json['year'] as int,
      );
}
