import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, {String currency = 'IDR'}) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: _symbol(currency),
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String compact(double amount, {String currency = 'IDR'}) {
    final symbol = _symbol(currency);
    if (amount >= 1000000000) {
      return '$symbol${(amount / 1000000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}Jt';
    } else if (amount >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(0)}K';
    }
    return format(amount, currency: currency);
  }

  static String _symbol(String currency) {
    switch (currency) {
      case 'IDR': return 'Rp ';
      case 'USD': return '\$ ';
      case 'EUR': return '€ ';
      case 'SGD': return 'S\$ ';
      default: return '$currency ';
    }
  }
}

class DateFormatter {
  static String formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return date;
    }
  }

  static String formatShort(String date) {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd MMM', 'id_ID').format(dt);
    } catch (_) {
      return date;
    }
  }

  static String formatMonth(String yearMonth) {
    try {
      final dt = DateTime.parse('$yearMonth-01');
      return DateFormat('MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return yearMonth;
    }
  }

  static String formatMonthFull(int month, int year) {
    final dt = DateTime(year, month);
    return DateFormat('MMMM yyyy', 'id_ID').format(dt);
  }

  static String timeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Hari ini';
      if (diff.inDays == 1) return 'Kemarin';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return formatShort(dateStr);
    } catch (_) {
      return dateStr;
    }
  }
}
