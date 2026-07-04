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
import '../../calendar/screens/calendar_screen.dart';
import 'bulk_transaction_screen.dart';
import 'import_csv_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

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
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showMoreMenu(context),
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

              // Search + Filter row
              _buildSearchBar(p),

              // Active filter chips
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
    );
  }

  Widget _buildSearchBar(TransactionProvider p) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                if (v.isEmpty || v.length >= 2) {
                  p.setFilter(search: v.isNotEmpty ? v : null);
                }
              },
              decoration: InputDecoration(
                hintText: 'Cari transaksi...',
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: AppColors.textHint),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          p.setFilter(search: null);
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Consumer<TransactionProvider>(
            builder: (_, tp, __) {
              final hasFilter = tp.filterType != null ||
                  tp.filterCategoryId != null ||
                  tp.filterAccountId != null ||
                  tp.filterStartDate != null;
              return GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasFilter
                        ? AppColors.primary
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: hasFilter ? Colors.white : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
              );
            },
          ),
        ],
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
    final p = context.read<TransactionProvider>();
    final hasFilter = p.filterType != null || p.filterCategoryId != null ||
        p.filterAccountId != null || p.filterStartDate != null;
    return EmptyState(
      emoji: hasFilter ? '🔍' : '🧾',
      title: hasFilter ? 'Tidak ada hasil' : 'Belum ada transaksi',
      subtitle: hasFilter
          ? 'Coba ubah filter atau kata kunci pencarianmu'
          : 'Tap + untuk mulai mencatat pemasukan & pengeluaran',
    );
  }

  void _showMoreMenu(BuildContext context) {
    final items = [
      (
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF6C5CE7),
        label: 'Kalender',
        desc: 'Lihat transaksi per tanggal',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
      ),
      (
        icon: Icons.playlist_add_rounded,
        color: const Color(0xFF00B894),
        label: 'Input Massal',
        desc: 'Tambah banyak transaksi sekaligus',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BulkTransactionScreen())),
      ),
      (
        icon: Icons.upload_file_rounded,
        color: const Color(0xFF0984E3),
        label: 'Import CSV',
        desc: 'Import data dari file CSV',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportCsvScreen())),
      ),
      (
        icon: Icons.download_rounded,
        color: const Color(0xFFE17055),
        label: 'Export CSV',
        desc: 'Unduh data transaksi',
        onTap: () { Navigator.pop(context); _showExportDialog(); },
      ),
      (
        icon: Icons.category_rounded,
        color: const Color(0xFFE84393),
        label: 'Kelola Kategori',
        desc: 'Atur kategori pengeluaran & pemasukan',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen())),
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => InkWell(
              onTap: () { Navigator.pop(context); item.onTap(); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text(item.desc,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textHint, size: 20),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 16),
          ],
        ),
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
  String _catSearch = '';
  String _accSearch = '';
  final _catSearchCtrl = TextEditingController();
  final _accSearchCtrl = TextEditingController();

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

  @override
  void dispose() {
    _catSearchCtrl.dispose();
    _accSearchCtrl.dispose();
    super.dispose();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filter Transaksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: widget.onReset,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
              TextField(
                controller: _catSearchCtrl,
                onChanged: (v) => setState(() => _catSearch = v),
                decoration: InputDecoration(
                  hintText: 'Cari kategori...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textHint),
                  suffixIcon: _catSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () => setState(() {
                            _catSearch = '';
                            _catSearchCtrl.clear();
                          }),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // "Semua" option
                      if (_catSearch.isEmpty)
                        _CatOption(
                          label: 'Semua kategori',
                          selected: _catId == null,
                          onTap: () => setState(() => _catId = null),
                        ),
                      ...(() {
                        final filtered = _catSearch.isEmpty
                            ? categories
                            : categories.where((c) =>
                                c.name.toLowerCase().contains(_catSearch.toLowerCase())).toList();
                        if (filtered.isEmpty) {
                          return [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('Tidak ditemukan "$_catSearch"',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          ];
                        }
                        return filtered.map((c) => _CatOption(
                          label: '${c.icon} ${c.name}',
                          selected: _catId == c.id,
                          onTap: () => setState(() => _catId = c.id),
                        )).toList();
                      })(),
                    ],
                  ),
                ),
              ),
            ],

            // Rekening
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Rekening', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _accSearchCtrl,
                onChanged: (v) => setState(() => _accSearch = v),
                decoration: InputDecoration(
                  hintText: 'Cari rekening...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textHint),
                  suffixIcon: _accSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () => setState(() {
                            _accSearch = '';
                            _accSearchCtrl.clear();
                          }),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_accSearch.isEmpty)
                        _CatOption(
                          label: 'Semua rekening',
                          selected: _accId == null,
                          onTap: () => setState(() => _accId = null),
                        ),
                      ...(() {
                        final filtered = _accSearch.isEmpty
                            ? accounts
                            : accounts.where((a) =>
                                a.name.toLowerCase().contains(_accSearch.toLowerCase())).toList();
                        if (filtered.isEmpty) {
                          return [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('Tidak ditemukan "$_accSearch"',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          ];
                        }
                        return filtered.map((a) => _CatOption(
                          label: a.name,
                          selected: _accId == a.id,
                          onTap: () => setState(() => _accId = a.id),
                        )).toList();
                      })(),
                    ],
                  ),
                ),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onApply(
                  _type,
                  _catId,
                  _accId,
                  _startDate != null ? _fmt(_startDate!) : null,
                  _endDate != null ? _fmt(_endDate!) : null,
                ),
                child: const Text('Terapkan Filter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CatOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
