import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GradientCard extends StatelessWidget {
  final Gradient gradient;
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final List<BoxShadow>? shadows;

  const GradientCard({
    super.key,
    required this.gradient,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: child,
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
            )
          : Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
      ],
    );
  }
}

class AmountText extends StatelessWidget {
  final double amount;
  final bool isIncome;
  final double fontSize;
  final bool showSign;

  const AmountText({
    super.key,
    required this.amount,
    required this.isIncome,
    this.fontSize = 16,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppColors.income : AppColors.expense;
    final sign = showSign ? (isIncome ? '+' : '-') : '';
    final formatted = _formatAmount(amount);

    return Text(
      '$sign$formatted',
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}Jt';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}K';
    }
    return 'Rp ${amount.toStringAsFixed(0)}';
  }
}

class CategoryIconWidget extends StatelessWidget {
  final String icon;
  final String color;
  final double size;

  const CategoryIconWidget({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  bool _isEmoji(String s) {
    if (s.isEmpty) return false;
    final rune = s.runes.first;
    return rune > 0x2000;
  }

  @override
  Widget build(BuildContext context) {
    final hexColor = _parseColor(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hexColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size * 0.35),
      ),
      alignment: Alignment.center,
      child: _isEmoji(icon)
          ? Text(icon, style: TextStyle(fontSize: size * 0.5))
          : Icon(_iconData(icon), color: hexColor, size: size * 0.5),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _iconData(String name) {
    final map = <String, IconData>{
      'work': Icons.work_outline_rounded,
      'star': Icons.star_outline_rounded,
      'trending_up': Icons.trending_up_rounded,
      'sell': Icons.sell_outlined,
      'computer': Icons.computer_rounded,
      'add_circle': Icons.add_circle_outline_rounded,
      'restaurant': Icons.restaurant_rounded,
      'directions_car': Icons.directions_car_outlined,
      'shopping_cart': Icons.shopping_cart_outlined,
      'receipt_long': Icons.receipt_long_outlined,
      'local_hospital': Icons.local_hospital_outlined,
      'movie': Icons.movie_outlined,
      'school': Icons.school_outlined,
      'savings': Icons.savings_outlined,
      'credit_card': Icons.credit_card_outlined,
      'more_horiz': Icons.more_horiz_rounded,
      'sports_esports': Icons.sports_esports_outlined,
      'gamepad': Icons.gamepad_outlined,
      'category': Icons.category_outlined,
    };
    return map[name] ?? Icons.category_outlined;
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'safe' => (AppColors.safe, 'Aman'),
      'warning' => (AppColors.warning, 'Waspada'),
      'danger' => (AppColors.danger, 'Berbahaya'),
      'exceeded' => (AppColors.exceeded, 'Melewati'),
      _ => (AppColors.textHint, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 44)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
