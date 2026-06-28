import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/transaction_provider.dart';
import '../../account/providers/account_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/money_card.dart';
import 'add_transaction_screen.dart';
import '../../category/screens/category_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().load();
    });
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 100) {
        context.read<TransactionProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cari transaksi...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) {
                  if (v.isEmpty || v.length >= 2) {
                    context.read<TransactionProvider>().setFilter(search: v.isNotEmpty ? v : null);
                  }
                },
              )
            : const Text('Transaksi'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchCtrl.clear();
                context.read<TransactionProvider>().clearFilters();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Kelola Kategori',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
            onPressed: _showExportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (_, p, __) {
          if (p.loading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          return Column(
            children: [
              // Summary bar
              _buildSummaryBar(p),

              // Filter chips
              _buildActiveFilter(p),

              // List
              Expanded(
                child: p.transactions.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: p.transactions.length + (p.loadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == p.transactions.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            );
                          }
                          final tx = p.transactions[i];
                          return _TransactionTile(
                            transaction: tx,
                            onDelete: () => _delete(p, tx.id),
                            onEdit: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddTransactionScreen(existing: tx),
                                ),
                              );
                              if (mounted) p.load();
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          if (mounted) context.read<TransactionProvider>().load();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryBar(TransactionProvider p) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _SummaryChip(
              label: 'Pemasukan',
              amount: p.totalIncome,
              color: AppColors.income,
              icon: Icons.arrow_downward_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryChip(
              label: 'Pengeluaran',
              amount: p.totalExpense,
              color: AppColors.expense,
              icon: Icons.arrow_upward_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilter(TransactionProvider p) {
    final chips = <Widget>[];

    if (p.filterType != null) {
      chips.add(_chip(
        label: p.filterType == 'income' ? '📈 Pemasukan' : (p.filterType == 'transfer' ? '🔄 Transfer' : '📉 Pengeluaran'),
        onRemove: () => p.setFilter(categoryId: p.filterCategoryId, accountId: p.filterAccountId, startDate: p.filterStartDate, endDate: p.filterEndDate),
      ));
    }
    if (p.filterCategoryId != null) {
      final cat = p.categories.where((c) => c.id == p.filterCategoryId).firstOrNull;
      chips.add(_chip(
        label: cat != null ? '${cat.icon} ${cat.name}' : 'Kategori',
        onRemove: () => p.setFilter(type: p.filterType, accountId: p.filterAccountId, startDate: p.filterStartDate, endDate: p.filterEndDate),
      ));
    }
    if (p.filterAccountId != null) {
      final acc = context.read<AccountProvider>().accounts.where((a) => a.id == p.filterAccountId).firstOrNull;
      chips.add(_chip(
        label: acc?.name ?? 'Rekening',
        onRemove: () => p.setFilter(type: p.filterType, categoryId: p.filterCategoryId, startDate: p.filterStartDate, endDate: p.filterEndDate),
      ));
    }
    if (p.filterStartDate != null || p.filterEndDate != null) {
      chips.add(_chip(
        label: '📅 ${p.filterStartDate ?? ''} — ${p.filterEndDate ?? ''}',
        onRemove: () => p.setFilter(type: p.filterType, categoryId: p.filterCategoryId, accountId: p.filterAccountId),
      ));
    }

    if (chips.isEmpty) return const SizedBox();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          ...chips,
          TextButton(
            onPressed: p.clearFilters,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Reset', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  Widget _chip({required String label, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
        deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
        onDeleted: onRemove,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        side: BorderSide.none,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text('Tidak ada transaksi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Tap + untuk mencatat transaksi baru',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Future<void> _showExportDialog() async {
    final now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1);
    DateTime endDate = DateTime(now.year, now.month + 1, 0);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Export CSV'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rentang tanggal:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => startDate = picked);
                      },
                      child: Text(
                        '${startDate.day}/${startDate.month}/${startDate.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('—'),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: endDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) setState(() => endDate = picked);
                      },
                      child: Text(
                        '${endDate.day}/${endDate.month}/${endDate.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Export')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final fmt = (DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    try {
      final bytes = await context.read<TransactionProvider>().exportCsv(
            startDate: fmt(startDate),
            endDate: fmt(endDate),
          );

      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengunduh CSV'), backgroundColor: AppColors.expense),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/transaksi_${fmt(startDate)}_${fmt(endDate)}.csv');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Export transaksi');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  void _showFilterSheet() {
    // Pre-load categories (all types) and accounts
    context.read<TransactionProvider>().loadCategories();
    context.read<AccountProvider>().load();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _FilterSheet(
        txProvider: context.read<TransactionProvider>(),
        accProvider: context.read<AccountProvider>(),
        onApply: (type, catId, accId, start, end) {
          Navigator.pop(ctx);
          context.read<TransactionProvider>().setFilter(
            type: type,
            categoryId: catId,
            accountId: accId,
            startDate: start,
            endDate: end,
          );
        },
        onReset: () {
          Navigator.pop(ctx);
          context.read<TransactionProvider>().clearFilters();
        },
      ),
    );
  }

  void _delete(TransactionProvider p, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Yakin ingin menghapus transaksi ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) await p.delete(id);
  }
}

class _TransactionTile extends StatelessWidget {
  final dynamic transaction;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TransactionTile({
    required this.transaction,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final isIncome = tx.type == 'income';
    final isTransfer = tx.type == 'transfer';
    final amtColor = isTransfer
        ? AppColors.primary
        : (isIncome ? AppColors.income : AppColors.expense);
    final amtPrefix = isTransfer ? '🔄' : (isIncome ? '+' : '-');
    final subtitle = isTransfer
        ? 'Transfer • ${DateFormatter.timeAgo(tx.date)}'
        : '${tx.category?.name ?? ''} • ${DateFormatter.timeAgo(tx.date)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onEdit,
        child: Row(
          children: [
            isTransfer
                ? Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
                  )
                : CategoryIconWidget(
                    icon: tx.category?.icon ?? 'category',
                    color: tx.category?.color ?? '#6366F1',
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description.isNotEmpty
                        ? tx.description
                        : (isTransfer ? 'Transfer' : (tx.category?.name ?? '')),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amtPrefix ${CurrencyFormatter.compact(tx.amount)}',
                  style: TextStyle(
                    color: amtColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.textHint, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                Text(
                  CurrencyFormatter.compact(amount),
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final TransactionProvider txProvider;
  final AccountProvider accProvider;
  final void Function(String? type, String? catId, String? accId, String? start, String? end) onApply;
  final VoidCallback onReset;

  const _FilterSheet({
    required this.txProvider,
    required this.accProvider,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _type;
  String? _catId;
  String? _accId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final p = widget.txProvider;
    _type = p.filterType;
    _catId = p.filterCategoryId;
    _accId = p.filterAccountId;
    _startDate = p.filterStartDate != null ? DateTime.tryParse(p.filterStartDate!) : null;
    _endDate = p.filterEndDate != null ? DateTime.tryParse(p.filterEndDate!) : null;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _display(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final categories = widget.txProvider.categories;
    final accounts = widget.accProvider.accounts;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Transaksi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            // Tipe
            const Text('Tipe', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in [
                  ('expense', '📉 Pengeluaran'),
                  ('income', '📈 Pemasukan'),
                  ('transfer', '🔄 Transfer'),
                ])
                  ChoiceChip(
                    label: Text(t.$2, style: const TextStyle(fontSize: 13)),
                    selected: _type == t.$1,
                    onSelected: (_) => setState(() => _type = _type == t.$1 ? null : t.$1),
                    selectedColor: AppColors.primary.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: _type == t.$1 ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: _type == t.$1 ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
              ],
            ),

            // Kategori
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _catId,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                hint: const Text('Semua kategori'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Semua kategori')),
                  ...categories.map((c) => DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text('${c.icon} ${c.name}'),
                  )),
                ],
                onChanged: (v) => setState(() => _catId = v),
              ),
            ],

            // Rekening
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Rekening', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _accId,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                hint: const Text('Semua rekening'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Semua rekening')),
                  ...accounts.map((a) => DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(a.name),
                  )),
                ],
                onChanged: (v) => setState(() => _accId = v),
              ),
            ],

            // Tanggal
            const SizedBox(height: 16),
            const Text('Rentang Tanggal', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    child: Text(
                      _startDate != null ? _display(_startDate!) : 'Dari',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—')),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    child: Text(
                      _endDate != null ? _display(_endDate!) : 'Sampai',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReset,
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onApply(
                      _type,
                      _catId,
                      _accId,
                      _startDate != null ? _fmt(_startDate!) : null,
                      _endDate != null ? _fmt(_endDate!) : null,
                    ),
                    child: const Text('Terapkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
