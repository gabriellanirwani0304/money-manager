import 'package:flutter/material.dart';
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
  final _catSearchCtrl = TextEditingController();

  String _type = 'expense';
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _submitting = false;
  String _catSearch = '';

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
          _catSearch = '';
          _catSearchCtrl.clear();
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
    _catSearchCtrl.dispose();
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
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: color,
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 36),
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(color: Colors.white60, fontSize: 22, fontWeight: FontWeight.w600),
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
                                final allCats = p.categories;
                                if (allCats.isEmpty) {
                                  return const Center(
                                      child: CircularProgressIndicator(color: AppColors.primary));
                                }
                                final cats = _catSearch.isEmpty
                                    ? allCats
                                    : allCats.where((c) =>
                                        c.name.toLowerCase().contains(_catSearch.toLowerCase())).toList();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Search field
                                    TextField(
                                      controller: _catSearchCtrl,
                                      onChanged: (v) => setState(() => _catSearch = v),
                                      decoration: InputDecoration(
                                        hintText: 'Cari kategori...',
                                        hintStyle: const TextStyle(fontSize: 13),
                                        prefixIcon: const Icon(Icons.search_rounded,
                                            size: 18, color: AppColors.textHint),
                                        suffixIcon: _catSearch.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.close_rounded, size: 16),
                                                onPressed: () => setState(() {
                                                  _catSearch = '';
                                                  _catSearchCtrl.clear();
                                                }),
                                              )
                                            : null,
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        isDense: true,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (cats.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text('Tidak ditemukan "$_catSearch"',
                                            style: const TextStyle(
                                                color: AppColors.textSecondary, fontSize: 13)),
                                      )
                                    else
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: cats.map((cat) {
                                          final selected = _selectedCategoryId == cat.id;
                                          final catColor = _parseColor(cat.color);
                                          return GestureDetector(
                                            onTap: () => setState(() => _selectedCategoryId = cat.id),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 180),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? catColor.withValues(alpha: 0.15)
                                                    : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: selected ? catColor : AppColors.divider,
                                                  width: selected ? 2 : 1,
                                                ),
                                                boxShadow: selected
                                                    ? [BoxShadow(
                                                        color: catColor.withValues(alpha: 0.2),
                                                        blurRadius: 8)]
                                                    : null,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CategoryIconWidget(
                                                      icon: cat.icon, color: cat.color, size: 28),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    cat.name,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: selected ? catColor : AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Account picker
                          Consumer<AccountProvider>(
                            builder: (_, accP, __) {
                              if (accP.accounts.isEmpty) return const SizedBox();
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
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        if (!isTransfer)
                                          GestureDetector(
                                            onTap: () => setState(() => _selectedAccountId = null),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              margin: const EdgeInsets.only(right: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: _selectedAccountId == null
                                                    ? AppColors.primary.withOpacity(0.12)
                                                    : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: _selectedAccountId == null
                                                      ? AppColors.primary : AppColors.divider,
                                                  width: _selectedAccountId == null ? 2 : 1,
                                                ),
                                              ),
                                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                Icon(Icons.money_off_rounded,
                                                    color: _selectedAccountId == null
                                                        ? AppColors.primary : AppColors.textHint,
                                                    size: 18),
                                                const SizedBox(width: 6),
                                                Text('Tidak ada',
                                                    style: TextStyle(
                                                        fontSize: 13, fontWeight: FontWeight.w600,
                                                        color: _selectedAccountId == null
                                                            ? AppColors.primary : AppColors.textPrimary)),
                                              ]),
                                            ),
                                          ),
                                        ...accP.accounts.map((acc) {
                                          final selected = _selectedAccountId == acc.id;
                                          final accColor = acc.parsedColor;
                                          return GestureDetector(
                                            onTap: () => setState(() => _selectedAccountId = acc.id),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              margin: const EdgeInsets.only(right: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: selected ? accColor.withOpacity(0.12) : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: selected ? accColor : AppColors.divider,
                                                  width: selected ? 2 : 1,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                                    Icon(_accountIconData(acc.icon), color: accColor, size: 16),
                                                    const SizedBox(width: 6),
                                                    Text(acc.name,
                                                        style: TextStyle(
                                                            fontSize: 13, fontWeight: FontWeight.w600,
                                                            color: selected ? accColor : AppColors.textPrimary)),
                                                  ]),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    CurrencyFormatter.compact(acc.balance),
                                                    style: TextStyle(
                                                        fontSize: 11, color: accColor, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
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
                                    const SizedBox(height: 16),
                                    const Text('Ke Rekening',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    const SizedBox(height: 8),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: accP.accounts
                                            .where((a) => a.id != _selectedAccountId)
                                            .map((acc) {
                                          final selected = _selectedToAccountId == acc.id;
                                          final accColor = acc.parsedColor;
                                          return GestureDetector(
                                            onTap: () => setState(() => _selectedToAccountId = acc.id),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              margin: const EdgeInsets.only(right: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: selected ? accColor.withOpacity(0.12) : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: selected ? accColor : AppColors.divider,
                                                  width: selected ? 2 : 1,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                                    Icon(_accountIconData(acc.icon), color: accColor, size: 16),
                                                    const SizedBox(width: 6),
                                                    Text(acc.name,
                                                        style: TextStyle(
                                                            fontSize: 13, fontWeight: FontWeight.w600,
                                                            color: selected ? accColor : AppColors.textPrimary)),
                                                  ]),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    CurrencyFormatter.compact(acc.balance),
                                                    style: TextStyle(
                                                        fontSize: 11, color: accColor, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
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
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'Tulis catatan...',
                              prefixIcon: Icon(Icons.notes_rounded, color: AppColors.primary),
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
