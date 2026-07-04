class ApiConstants {
  ApiConstants._();

  // 10.0.2.2 = host machine dari Android emulator (ganti ke IP laptop jika pakai device fisik)
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Dashboard
  static const String dashboard = '/dashboard';

  // Categories
  static const String categories = '/categories';
  static String categoryById(String id) => '/categories/$id';

  // Transactions
  static const String transactions = '/transactions';
  static String transactionById(String id) => '/transactions/$id';
  static const String transactionsExport = '/transactions/export';

  // Budgets
  static const String budgets = '/budgets';
  static String budgetById(String id) => '/budgets/$id';

  // Reports
  static const String reportSummary = '/reports/summary';
  static const String reportMonthly = '/reports/monthly';
  static const String reportByCategory = '/reports/by-category';
  static const String reportInsights = '/reports/insights';

  // Accounts (rekening)
  static const String accounts = '/accounts';
  static String accountById(String id) => '/accounts/$id';
  static String accountBalance(String id) => '/accounts/$id/balance';
}
