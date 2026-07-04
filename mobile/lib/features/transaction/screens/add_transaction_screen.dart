import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction_models.dart';
import '../../account/providers/account_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/money_card.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? existing;

  const AddTransactionScreen({super.key, this.existing});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'expense';
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _submitting = false;

  bool get isEditing => widget.existing != null;
  bool get isTransfer => _type == 'transfer';

  static const _types = ['expense', 'income', 'transfer'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          _type = _types[_tabCtrl.index];
          _selectedCategoryId = null;
        });
        if (!isTransfer) {
          context.read<TransactionProvider>().loadCategories(type: _type);
        }
      }
    });

    if (isEditing) {
      final e = widget.existing!;
      _type = e.type;
      _amountCtrl.text = e.amount.toStringAsFixed(0);
      _descCtrl.text = e.description;
      _selectedCategoryId = e.categoryId;
      _selectedAccountId = e.accountId;
      _selectedToAccountId = e.toAccountId;
      _selectedDate = DateTime.tryParse(e.date) ?? DateTime.now();
      _tabCtrl.index = _types.indexOf(_type).clamp(0, 2);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isTransfer) {
        context.read<TransactionProvider>().loadCategories(type: _type);
      }
      context.read<AccountProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isTransfer && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori terlebih dahulu')),
      );
      return;
    }
    if (isTransfer && (_selectedAccountId == null || _selectedToAccountId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih rekening asal dan tujuan')),
      );
      return;
    }
    if (isTransfer && _selectedAccountId == _selectedToAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rekening asal dan tujuan tidak boleh sama')),
      );
      return;
    }

    setState(() => _submitting = true);
    final provider = context.read<TransactionProvider>();
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    final amount = double.tryParse(_amountCtrl.text.replaceAll('.', '')) ?? 0;

    bool ok;
    if (isEditing) {
      ok = await provider.update(
        id: widget.existing!.id,
        categoryId: _selectedCategoryId,
        accountId: _selectedAccountId,
        toAccountId: _selectedToAccountId,
        type: _type,
        amount: amount,
        description: _descCtrl.text.trim(),
        date: dateStr,
      );
    } else {
      ok = await provider.create(
        categoryId: _selectedCategoryId,
        accountId: _selectedAccountId,
        toAccountId: _selectedToAccountId,
        type: _type,
        amount: amount,
        description: _descCtrl.text.trim(),
        date: dateStr,
      );
    }

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Transaksi diperbarui' : 'Transaksi berhasil dicatat! 🎉'),
            backgroundColor: AppColors.income,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Gagal menyimpan'), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  void _showCategorySheet(List categories) {
    final searchCtrl = TextEditingController();
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = query.isEmpty
              ? categories
              : categories
                  .where((c) =>
                      c.name.toLowerCase().contains(query.toLowerCase()))
                  .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Pilih Kategori',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setSheetState(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Cari kategori...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: AppColors.textHint),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setSheetState(() => query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text('Tidak ada "$query"',
                              style: const TextStyle(
                                  color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final cat = filtered[i];
                            final catColor = _parseColor(cat.color);
                            final isSelected = _selectedCategoryId == cat.id;

                            return ListTile(
                              onTap: () {
                                setState(() => _selectedCategoryId = cat.id);
                                Navigator.pop(context);
                              },
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              tileColor: isSelected
                                  ? catColor.withValues(alpha: 0.08)
                                  : null,
                              leading: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(cat.icon,
                                    style: const TextStyle(fontSize: 22)),
                              ),
                              title: Text(cat.name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isSelected
                                          ? catColor
                                          : AppColors.textPrimary)),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle_rounded,
                                      color: catColor, size: 22)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountField({
    required dynamic account,
    required String placeholder,
    required bool allowNone,
    required VoidCallback onTap,
  }) {
    final isNone = account == null && !allowNone;
    final accColor = account?.parsedColor ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: account != null
              ? accColor.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: account != null
                ? accColor.withValues(alpha: 0.4)
                : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            if (account != null) ...[
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: accColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_accountIconData(account.icon), color: accColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: accColor)),
                    Text(CurrencyFormatter.compact(account.balance),
                        style: TextStyle(fontSize: 12, color: accColor.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ] else ...[
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 20, color: AppColors.textHint),
              const SizedBox(width: 12),
              Expanded(
                child: Text(placeholder,
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 15)),
              ),
            ],
            Icon(Icons.keyboard_arrow_down_rounded,
                color: account != null ? accColor : AppColors.textHint),
          ],
        ),
      ),
    );
  }

  void _showAccountSheet({
    required List accounts,
    required String title,
    required bool allowNone,
    required String? excludeId,
    required void Function(String? id) onSelect,
  }) {
    final searchCtrl = TextEditingController();
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = accounts
              .where((a) =>
                  a.id != excludeId &&
                  (query.isEmpty ||
                      a.name.toLowerCase().contains(query.toLowerCase())))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setSheetState(() => query = v),
                    decoration: InputDecoration(
                      hintText: 'Cari rekening...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: AppColors.textHint),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                setSheetState(() => query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    children: [
                      if (allowNone)
                        ListTile(
                          onTap: () {
                            onSelect(null);
                            Navigator.pop(context);
                          },
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          tileColor: _selectedAccountId == null
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : null,
                          leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.divider,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.money_off_rounded,
                                color: AppColors.textSecondary, size: 22),
                          ),
                          title: const Text('Tidak ada rekening',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: const Text('Tidak terhubung ke rekening',
                              style: TextStyle(fontSize: 12)),
                          trailing: _selectedAccountId == null
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 22)
                              : null,
                        ),
                      ...filtered.map((acc) {
                        final accColor = acc.parsedColor;
                        final isSelected = _selectedAccountId == acc.id ||
                            _selectedToAccountId == acc.id;

                        return ListTile(
                          onTap: () {
                            onSelect(acc.id);
                            Navigator.pop(context);
                          },
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          tileColor: isSelected
                              ? accColor.withValues(alpha: 0.08)
                              : null,
                          leading: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: accColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_accountIconData(acc.icon),
                                color: accColor, size: 22),
                          ),
                          title: Text(acc.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isSelected
                                      ? accColor
                                      : AppColors.textPrimary)),
                          subtitle: Text(
                              CurrencyFormatter.format(acc.balance),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: accColor,
                                  fontWeight: FontWeight.w600)),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded,
                                  color: accColor, size: 22)
                              : null,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == 'expense';
    final gradient = isTransfer
        ? AppColors.primaryGradient
        : (isExpense ? AppColors.expenseGradient : AppColors.incomeGradient);
    final color = isTransfer
        ? AppColors.primary
        : (isExpense ? AppColors.expense : AppColors.income);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Transaksi' : 'Catat Transaksi',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Type tabs
              if (!isEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabCtrl,
                      padding: const EdgeInsets.all(4),
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: color,
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      tabs: const [
                        Tab(text: '📉 Keluar'),
                        Tab(text: '📈 Masuk'),
                        Tab(text: '🔄 Transfer'),
                      ],
                    ),
                  ),
                ),

              // Amount input
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    const Text('Nominal', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Rp',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: true,
                                fillColor: Colors.transparent,
                                hintText: '0',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 36),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom sheet
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),

                          // Category picker (hidden for transfer)
                          if (!isTransfer) ...[
                            const Text('Kategori',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 10),
                            Consumer<TransactionProvider>(
                              builder: (_, p, __) {
                                final selected = p.categories
                                    .where((c) => c.id == _selectedCategoryId)
                                    .firstOrNull;
                                final selColor = selected != null
                                    ? _parseColor(selected.color)
                                    : AppColors.primary;

                                return GestureDetector(
                                  onTap: () => _showCategorySheet(p.categories),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: selected != null
                                          ? selColor.withValues(alpha: 0.08)
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: selected != null
                                            ? selColor.withValues(alpha: 0.4)
                                            : AppColors.divider,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        if (selected != null) ...[
                                          Text(selected.icon,
                                              style: const TextStyle(fontSize: 22)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(selected.name,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: selColor)),
                                          ),
                                        ] else ...[
                                          const Icon(Icons.grid_view_rounded,
                                              size: 20, color: AppColors.textHint),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text('Pilih kategori...',
                                                style: TextStyle(
                                                    color: AppColors.textHint, fontSize: 15)),
                                          ),
                                        ],
                                        Icon(Icons.keyboard_arrow_down_rounded,
                                            color: selected != null
                                                ? selColor
                                                : AppColors.textHint),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Account picker
                          Consumer<AccountProvider>(
                            builder: (_, accP, __) {
                              if (accP.accounts.isEmpty) return const SizedBox();
                              final fromAcc = accP.accounts
                                  .where((a) => a.id == _selectedAccountId)
                                  .firstOrNull;
                              final toAcc = accP.accounts
                                  .where((a) => a.id == _selectedToAccountId)
                                  .firstOrNull;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(isTransfer ? 'Dari Rekening' : 'Rekening',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    if (!isTransfer) ...[
                                      const SizedBox(width: 6),
                                      const Text('(opsional)',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    ],
                                  ]),
                                  const SizedBox(height: 8),
                                  _buildAccountField(
                                    account: fromAcc,
                                    placeholder: isTransfer ? 'Pilih rekening asal...' : 'Pilih rekening...',
                                    allowNone: !isTransfer,
                                    onTap: () => _showAccountSheet(
                                      accounts: accP.accounts,
                                      title: isTransfer ? 'Dari Rekening' : 'Pilih Rekening',
                                      allowNone: !isTransfer,
                                      excludeId: null,
                                      onSelect: (id) => setState(() => _selectedAccountId = id),
                                    ),
                                  ),
                                  if (_selectedAccountId != null && !isTransfer) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _type == 'expense'
                                          ? '💸 Saldo rekening akan berkurang'
                                          : '💰 Saldo rekening akan bertambah',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _type == 'expense' ? AppColors.expense : AppColors.income,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],

                                  // To Account (transfer only)
                                  if (isTransfer) ...[
                                    const SizedBox(height: 12),
                                    Row(children: [
                                      const Expanded(child: Divider()),
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.arrow_downward_rounded,
                                            size: 16, color: AppColors.primary),
                                      ),
                                      const Expanded(child: Divider()),
                                    ]),
                                    const SizedBox(height: 12),
                                    const Text('Ke Rekening',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    const SizedBox(height: 8),
                                    _buildAccountField(
                                      account: toAcc,
                                      placeholder: 'Pilih rekening tujuan...',
                                      allowNone: false,
                                      onTap: () => _showAccountSheet(
                                        accounts: accP.accounts,
                                        title: 'Ke Rekening',
                                        allowNone: false,
                                        excludeId: _selectedAccountId,
                                        onSelect: (id) => setState(() => _selectedToAccountId = id),
                                      ),
                                    ),
                                    if (_selectedAccountId != null && _selectedToAccountId != null) ...[
                                      const SizedBox(height: 6),
                                      const Text('🔄 Saldo akan dipindahkan antar rekening',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ],
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 20),
                          const Text('Keterangan (opsional)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 3,
                            minLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Tulis catatan...',
                              hintStyle: const TextStyle(
                                  color: AppColors.textHint, fontSize: 14),
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Text('Tanggal',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 8),
                          AppCard(
                            onTap: _pickDate,
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Text(
                                  '${_selectedDate.day} ${_monthName(_selectedDate.month)} ${_selectedDate.year}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ).copyWith(
                                backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                shadowColor: MaterialStateProperty.all(Colors.transparent),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: _submitting ? null : gradient,
                                  color: _submitting ? AppColors.textHint : null,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Container(
                                  height: 52,
                                  alignment: Alignment.center,
                                  child: _submitting
                                      ? const SizedBox(
                                          width: 22, height: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.white, strokeWidth: 2.5))
                                      : Text(
                                          isEditing ? 'Simpan Perubahan' : 'Catat Sekarang',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _accountIconData(String name) {
    const map = {
      'account_balance': Icons.account_balance_rounded,
      'payments': Icons.payments_rounded,
      'account_balance_wallet': Icons.account_balance_wallet_rounded,
      'trending_up': Icons.trending_up_rounded,
      'wallet': Icons.wallet_rounded,
    };
    return map[name] ?? Icons.account_balance_rounded;
  }

  String _monthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return names[month];
  }
}
