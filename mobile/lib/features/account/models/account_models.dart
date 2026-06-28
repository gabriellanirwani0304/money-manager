import 'package:flutter/material.dart';

class AccountModel {
  final String id;
  final String name;
  final String type;
  final String bankName;
  final String icon;
  final String color;
  final double initialBalance;
  final double balance;
  final bool isActive;

  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.bankName,
    required this.icon,
    required this.color,
    required this.initialBalance,
    required this.balance,
    required this.isActive,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) => AccountModel(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String? ?? 'bank',
        bankName: json['bank_name'] as String? ?? '',
        icon: json['icon'] as String? ?? 'account_balance',
        color: json['color'] as String? ?? '#6C5CE7',
        initialBalance: (json['initial_balance'] as num? ?? 0).toDouble(),
        balance: (json['balance'] as num? ?? 0).toDouble(),
        isActive: json['is_active'] as bool? ?? true,
      );

  Color get parsedColor {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF6C5CE7);
    }
  }

  String get typeLabel => switch (type) {
        'bank' => 'Bank',
        'cash' => 'Tunai',
        'ewallet' => 'E-Wallet',
        'investment' => 'Investasi',
        _ => 'Lainnya',
      };
}

class AccountType {
  final String value;
  final String label;
  final String icon;
  final String color;

  const AccountType({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  static const List<AccountType> all = [
    AccountType(value: 'bank', label: 'Bank', icon: 'account_balance', color: '#6C5CE7'),
    AccountType(value: 'cash', label: 'Tunai', icon: 'payments', color: '#00C49A'),
    AccountType(value: 'ewallet', label: 'E-Wallet', icon: 'account_balance_wallet', color: '#00B4D8'),
    AccountType(value: 'investment', label: 'Investasi', icon: 'trending_up', color: '#FFB300'),
    AccountType(value: 'other', label: 'Lainnya', icon: 'wallet', color: '#636E72'),
  ];
}

const List<String> popularBanks = [
  'BCA', 'Mandiri', 'BRI', 'BNI', 'CIMB Niaga', 'Danamon',
  'GoPay', 'OVO', 'DANA', 'ShopeePay', 'LinkAja',
  'Jenius', 'SeaBank', 'Jago', 'Neo Commerce',
];
