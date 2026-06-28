import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';
import '../models/budget_models.dart';
import '../../transaction/providers/transaction_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/money_card.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Consumer<BudgetProvider>(
          builder: (_, p, __) => Text(
            'Budget ${DateFormatter.formatMonthFull(p.month, p.year)}',
          ),
        ),
        actions: [
          Consumer<BudgetProvider>(
            builder: (_, p, __) => IconButton(
              icon: p.copying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.copy_all_rounded),
              tooltip: 'Salin dari bulan lalu',
              onPressed: p.copying ? null : () => _copyFromPrevMonth(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              final p = context.read<BudgetProvider>();
              int m = p.month - 1, y = p.year;
              if (m == 0) { m = 12; y--; }
              p.load(month: m, year: y);
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              final p = context.read<BudgetProvider>();
              int m = p.month + 1, y = p.year;
              if (m == 13) { m = 1; y++; }
              p.load(month: m, year: y);
            },
          ),
        ],
      ),
      body: Consumer<BudgetProvider>(
        builder: (_, p, __) {
          if (p.loading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (p.budgets.isEmpty) {
            return _buildEmpty(context, p);
          }

          return RefreshIndicator(
            onRefresh: () => p.load(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: p.budgets.length,
              itemBuilder: (ctx, i) => _BudgetCard(
                budget: p.budgets[i],
                onEdit: () => _showEditDialog(context, p, p.budgets[i]),
                onDelete: () => p.delete(p.budgets[i].id),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Set Budget', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, BudgetProvider p) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.savings_outlined, size: 48, color: AppColors.warning),
          ),
          const SizedBox(height: 20),
          const Text('Belum ada budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Set budget per kategori agar keuanganmu terkontrol',
              style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Set Budget Pertama'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyFromPrevMonth(BuildContext context) async {
    final p = context.read<BudgetProvider>();
    final copied = await p.copyFromPrevMonth();
    if (!context.mounted) return;
    if (copied < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(p.error ?? 'Gagal menyalin budget'), backgroundColor: AppColors.expense),
      );
    } else if (copied == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua budget sudah ada, tidak ada yang perlu disalin')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$copied budget berhasil disalin dari bulan lalu 🎯'),
          backgroundColor: AppColors.income,
        ),
      );
    }
  }

  void _showAddDialog(BuildContext context) {
    final txProvider = context.read<TransactionProvider>();
    txProvider.loadCategories(type: 'expense');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddBudgetSheet(budgetProvider: context.read<BudgetProvider>()),
    );
  }

  void _showEditDialog(BuildContext context, BudgetProvider p, BudgetModel b) {
    final amountCtrl = TextEditingController(text: b.budgetAmount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Budget ${b.category?.name ?? ''}'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nominal Budget', prefixText: 'Rp '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount > 0) {
                Navigator.pop(context);
                await p.update(b.id, amount);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetModel budget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (budget.percentage / 100).clamp(0.0, 1.0);
    final statusColor = switch (budget.status) {
      'safe' => AppColors.safe,
      'warning' => AppColors.warning,
      'danger' => AppColors.danger,
      'exceeded' => AppColors.exceeded,
      _ => AppColors.textHint,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                CategoryIconWidget(
                  icon: budget.category?.icon ?? 'category',
                  color: budget.category?.color ?? '#6366F1',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(budget.category?.name ?? 'Kategori',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        'Budget: ${CurrencyFormatter.format(budget.budgetAmount)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: budget.status),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHint, size: 20),
                  itemBuilder: (_) => [
                    PopupMenuItem(onTap: onEdit, child: const Text('Edit')),
                    PopupMenuItem(onTap: onDelete, child: const Text('Hapus',
                        style: TextStyle(color: AppColors.expense))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Progress bar
            Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusColor.withOpacity(0.7), statusColor],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terpakai: ${CurrencyFormatter.compact(budget.spent)}',
                  style: TextStyle(
                      color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Sisa: ${CurrencyFormatter.compact(budget.remaining)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBudgetSheet extends StatefulWidget {
  final BudgetProvider budgetProvider;
  const _AddBudgetSheet({required this.budgetProvider});

  @override
  State<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<_AddBudgetSheet> {
  final _amountCtrl = TextEditingController();
  String? _selectedCategoryId;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.budgetProvider;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Set Budget Baru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(DateFormatter.formatMonthFull(p.month, p.year),
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          Consumer<TransactionProvider>(
            builder: (_, tp, __) {
              final cats = tp.categories.where((c) => c.type == 'expense').toList();
              return DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori Pengeluaran',
                  prefixIcon: Icon(Icons.category_outlined, color: AppColors.primary),
                ),
                hint: const Text('Pilih kategori'),
                items: cats.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
                )).toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
              );
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nominal Budget',
              prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.primary),
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : () async {
                final amount = double.tryParse(_amountCtrl.text) ?? 0;
                if (_selectedCategoryId == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Isi semua field dengan benar')),
                  );
                  return;
                }
                setState(() => _submitting = true);
                final ok = await p.create(
                  categoryId: _selectedCategoryId!,
                  amount: amount,
                  month: p.month,
                  year: p.year,
                );
                if (mounted) {
                  setState(() => _submitting = false);
                  if (ok) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Budget berhasil disimpan! 🎯'),
                          backgroundColor: AppColors.income),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(p.error ?? 'Gagal menyimpan budget'),
                          backgroundColor: AppColors.expense),
                    );
                  }
                }
              },
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Simpan Budget'),
            ),
          ),
        ],
      ),
    );
  }
}
