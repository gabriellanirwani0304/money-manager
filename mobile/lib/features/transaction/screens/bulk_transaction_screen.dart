import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../../account/providers/account_provider.dart';
import '../../transaction/models/transaction_models.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/money_card.dart';

class BulkTransactionScreen extends StatefulWidget {
  const BulkTransactionScreen({super.key});

  @override
  State<BulkTransactionScreen> createState() => _BulkTransactionScreenState();
}

class _BulkTransactionScreenState extends State<BulkTransactionScreen> {
  final List<_RowState> _rows = [];
  bool _submitting = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) _rows.add(_RowState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadCategories();
      context.read<AccountProvider>().load();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  void _addRow({_RowState? copyFrom}) {
    setState(() => _rows.add(_RowState(copyFrom: copyFrom)));
    Future.delayed(const Duration(milliseconds: 80), () {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeRow(int i) {
    if (_rows.length <= 1) return;
    setState(() { _rows[i].dispose(); _rows.removeAt(i); });
  }

  Future<void> _submit() async {
    // Validate all rows
    bool hasError = false;
    for (final r in _rows) {
      r.error = null;
      final amount = double.tryParse(r.amountCtrl.text.trim()) ?? 0;
      if (amount <= 0) { r.error = 'Nominal wajib diisi'; hasError = true; }
      if (r.type != 'transfer' && (r.categoryId == null || r.categoryId!.isEmpty)) {
        r.error = 'Pilih kategori'; hasError = true;
      }
      if (r.type == 'transfer' && (r.accountId == null || r.toAccountId == null)) {
        r.error = 'Pilih rekening asal & tujuan'; hasError = true;
      }
    }
    if (hasError) { setState(() {}); return; }

    setState(() => _submitting = true);
    final provider = context.read<TransactionProvider>();
    final rows = _rows.map((r) {
      final body = <String, dynamic>{
        'type': r.type,
        'amount': double.parse(r.amountCtrl.text.trim()),
        'description': r.descCtrl.text.trim(),
        'date': r.date.toIso8601String().split('T')[0],
      };
      if (r.categoryId != null && r.categoryId!.isNotEmpty) body['category_id'] = r.categoryId;
      if (r.accountId != null && r.accountId!.isNotEmpty) body['account_id'] = r.accountId;
      if (r.toAccountId != null && r.toAccountId!.isNotEmpty) body['to_account_id'] = r.toAccountId;
      return body;
    }).toList();

    try {
      final result = await provider.batchCreate(rows);
      if (mounted) {
        final imported = result['imported'] ?? 0;
        final failed = result['failed'] ?? 0;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(failed == 0
              ? '$imported transaksi berhasil disimpan! 🎉'
              : '$imported berhasil, $failed gagal'),
          backgroundColor: failed == 0 ? AppColors.income : AppColors.expense,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.error ?? 'Gagal menyimpan'),
          backgroundColor: AppColors.expense,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txP = context.watch<TransactionProvider>();
    final accP = context.watch<AccountProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Input Massal'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : Text('Simpan ${_rows.length}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _rows.length,
              itemBuilder: (ctx, i) => _RowCard(
                key: ValueKey(_rows[i].id),
                index: i,
                row: _rows[i],
                categories: txP.categories,
                accounts: accP.accounts,
                onRemove: _rows.length > 1 ? () => _removeRow(i) : null,
                onDuplicate: () => _addRow(copyFrom: _rows[i]),
                onChanged: () => setState(() {}),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addRow(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tambah Baris'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text('Simpan (${_rows.length})'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowState {
  static int _counter = 0;
  final int id = ++_counter;
  final TextEditingController amountCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  String type = 'expense';
  String? categoryId;
  String? accountId;
  String? toAccountId;
  DateTime date = DateTime.now();
  bool expanded = true;
  String? catSearch = '';
  String? error;

  _RowState({_RowState? copyFrom}) {
    if (copyFrom != null) {
      type = copyFrom.type;
      categoryId = copyFrom.categoryId;
      accountId = copyFrom.accountId;
      date = copyFrom.date;
      amountCtrl.text = copyFrom.amountCtrl.text;
    }
  }

  void dispose() {
    amountCtrl.dispose();
    descCtrl.dispose();
  }
}

class _RowCard extends StatefulWidget {
  final int index;
  final _RowState row;
  final List<CategoryModel> categories;
  final List<dynamic> accounts;
  final VoidCallback? onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onChanged;

  const _RowCard({
    super.key,
    required this.index,
    required this.row,
    required this.categories,
    required this.accounts,
    this.onRemove,
    required this.onDuplicate,
    required this.onChanged,
  });

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  late TextEditingController _catSearchCtrl;

  @override
  void initState() {
    super.initState();
    _catSearchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _catSearchCtrl.dispose();
    super.dispose();
  }

  Color get _typeColor => widget.row.type == 'income'
      ? AppColors.income
      : widget.row.type == 'transfer'
          ? AppColors.primary
          : AppColors.expense;

  List<CategoryModel> get _filteredCats {
    final cats = widget.categories.where((c) => c.type == widget.row.type).toList();
    final q = widget.row.catSearch ?? '';
    if (q.isEmpty) return cats;
    return cats.where((c) => c.name.toLowerCase().contains(q.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text('${widget.index + 1}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _typeColor))),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(
                row.amountCtrl.text.isNotEmpty
                    ? 'Rp ${row.amountCtrl.text}'
                    : 'Baris ${widget.index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              )),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                onPressed: widget.onDuplicate,
                tooltip: 'Duplikat',
                visualDensity: VisualDensity.compact,
                color: AppColors.textSecondary,
              ),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  onPressed: widget.onRemove,
                  tooltip: 'Hapus',
                  visualDensity: VisualDensity.compact,
                  color: AppColors.expense,
                ),
              IconButton(
                icon: Icon(row.expanded
                    ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                onPressed: () => setState(() => row.expanded = !row.expanded),
                visualDensity: VisualDensity.compact,
                color: AppColors.textSecondary,
              ),
            ]),

            if (row.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(row.error!,
                    style: const TextStyle(color: AppColors.expense, fontSize: 12)),
              ),

            if (row.expanded) ...[
              const Divider(height: 16),

              // Type toggle
              Row(children: [
                for (final t in [('expense', '📉 Keluar'), ('income', '📈 Masuk'), ('transfer', '🔄 Transfer')])
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          row.type = t.$1;
                          row.categoryId = null;
                          _catSearchCtrl.clear();
                          row.catSearch = '';
                        });
                        widget.onChanged();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: row.type == t.$1 ? _typeColor.withValues(alpha: 0.12) : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: row.type == t.$1 ? _typeColor : AppColors.divider,
                            width: row.type == t.$1 ? 1.5 : 1,
                          ),
                        ),
                        child: Text(t.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: row.type == t.$1 ? FontWeight.w700 : FontWeight.normal,
                            color: row.type == t.$1 ? _typeColor : AppColors.textSecondary,
                          )),
                      ),
                    ),
                  )),
              ]),
              const SizedBox(height: 10),

              // Amount
              TextFormField(
                controller: row.amountCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) { setState(() {}); widget.onChanged(); },
                decoration: const InputDecoration(
                  labelText: 'Nominal (Rp)',
                  prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.primary),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),

              // Category (not for transfer)
              if (row.type != 'transfer') ...[
                const Text('Kategori',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _catSearchCtrl,
                  onChanged: (v) => setState(() => row.catSearch = v),
                  decoration: InputDecoration(
                    hintText: 'Cari kategori...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.textHint),
                    suffixIcon: (row.catSearch?.isNotEmpty ?? false)
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14),
                            onPressed: () => setState(() { row.catSearch = ''; _catSearchCtrl.clear(); }),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 130),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _filteredCats.isEmpty
                          ? [Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                (row.catSearch?.isEmpty ?? true) ? 'Belum ada kategori' : 'Tidak ditemukan',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ))]
                          : _filteredCats.map((c) => InkWell(
                              onTap: () {
                                setState(() {
                                  row.categoryId = c.id;
                                  row.catSearch = '';
                                  _catSearchCtrl.clear();
                                });
                                widget.onChanged();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(children: [
                                  Icon(
                                    row.categoryId == c.id
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 16,
                                    color: row.categoryId == c.id ? AppColors.primary : AppColors.textHint,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${c.icon} ${c.name}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: row.categoryId == c.id ? FontWeight.w600 : FontWeight.normal,
                                        color: row.categoryId == c.id ? AppColors.primary : AppColors.textPrimary,
                                      )),
                                ]),
                              ),
                            )).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Account
              if (widget.accounts.isNotEmpty) ...[
                Text(row.type == 'transfer' ? 'Dari Rekening' : 'Rekening (opsional)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (row.type != 'transfer')
                        _AccChip(
                          label: 'Tidak ada',
                          selected: row.accountId == null,
                          onTap: () { setState(() => row.accountId = null); widget.onChanged(); },
                        ),
                      ...widget.accounts.map((a) => _AccChip(
                        label: a.name as String,
                        selected: row.accountId == a.id,
                        onTap: () { setState(() => row.accountId = a.id as String); widget.onChanged(); },
                      )),
                    ],
                  ),
                ),
                if (row.type == 'transfer') ...[
                  const SizedBox(height: 10),
                  const Text('Ke Rekening',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: widget.accounts
                          .where((a) => a.id != row.accountId)
                          .map((a) => _AccChip(
                            label: a.name as String,
                            selected: row.toAccountId == a.id,
                            onTap: () { setState(() => row.toAccountId = a.id as String); widget.onChanged(); },
                          )).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],

              // Description + Date
              Row(children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row.descCtrl,
                    onChanged: (_) => widget.onChanged(),
                    decoration: const InputDecoration(
                      hintText: 'Catatan (opsional)',
                      prefixIcon: Icon(Icons.notes_rounded, color: AppColors.primary, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: row.date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(primary: AppColors.primary),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() { row.date = picked; widget.onChanged(); });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${row.date.day}/${row.date.month}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AccChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        color: selected ? AppColors.primary : AppColors.textPrimary,
      )),
    ),
  );
}
