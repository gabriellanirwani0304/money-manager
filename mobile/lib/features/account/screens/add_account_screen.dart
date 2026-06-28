import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/account_models.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/money_card.dart';

class AddAccountScreen extends StatefulWidget {
  final AccountModel? existing;
  const AddAccountScreen({super.key, this.existing});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController(text: '0');

  String _type = 'bank';
  String _icon = 'account_balance';
  String _color = '#6C5CE7';
  bool _submitting = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _bankNameCtrl.text = e.bankName;
      _balanceCtrl.text = e.balance.toStringAsFixed(0);
      _type = e.type;
      _icon = e.icon;
      _color = e.color;
    } else {
      _applyTypeDefaults('bank');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankNameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _applyTypeDefaults(String type) {
    final info = AccountType.all.firstWhere((t) => t.value == type, orElse: () => AccountType.all[0]);
    setState(() {
      _type = type;
      _icon = info.icon;
      _color = info.color;
    });
  }

  Color get _parsedColor {
    try {
      return Color(int.parse(_color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final p = context.read<AccountProvider>();
    final balance = double.tryParse(_balanceCtrl.text.replaceAll('.', '')) ?? 0;
    bool ok;

    if (isEditing) {
      ok = await p.update(
        widget.existing!.id,
        name: _nameCtrl.text.trim(),
        bankName: _bankNameCtrl.text.trim(),
        icon: _icon,
        color: _color,
      );
    } else {
      ok = await p.create(
        name: _nameCtrl.text.trim(),
        type: _type,
        bankName: _bankNameCtrl.text.trim(),
        icon: _icon,
        color: _color,
        initialBalance: balance,
      );
    }

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Rekening diperbarui ✅' : 'Rekening berhasil ditambahkan! 🏦'),
            backgroundColor: AppColors.income,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(p.error ?? 'Gagal menyimpan'), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parsedColor;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(isEditing ? 'Edit Rekening' : 'Tambah Rekening'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview card
              GradientCard(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.7), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shadows: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_iconData(_icon), color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Nama Rekening',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          if (_bankNameCtrl.text.isNotEmpty)
                            Text(_bankNameCtrl.text,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tipe rekening
              const Text('Tipe Rekening',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AccountType.all.map((t) {
                  final selected = _type == t.value;
                  final tColor = Color(int.parse(t.color.replaceFirst('#', '0xFF')));
                  return GestureDetector(
                    onTap: isEditing ? null : () => _applyTypeDefaults(t.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? tColor.withOpacity(0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? tColor : AppColors.divider,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_iconData(t.icon), color: selected ? tColor : AppColors.textHint, size: 18),
                          const SizedBox(width: 6),
                          Text(t.label,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: selected ? tColor : AppColors.textPrimary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Nama rekening
              const Text('Nama Rekening', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Contoh: Tabungan BCA, GoPay Utama',
                  prefixIcon: Icon(Icons.label_outline_rounded, color: color),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama harus diisi' : null,
              ),

              const SizedBox(height: 16),

              // Nama bank / platform
              const Text('Bank / Platform', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (v) => popularBanks.where(
                  (b) => b.toLowerCase().contains(v.text.toLowerCase()),
                ),
                onSelected: (s) {
                  _bankNameCtrl.text = s;
                  setState(() {});
                },
                fieldViewBuilder: (_, ctrl, focus, onSubmit) {
                  ctrl.text = _bankNameCtrl.text;
                  return TextFormField(
                    controller: ctrl,
                    focusNode: focus,
                    onChanged: (v) {
                      _bankNameCtrl.text = v;
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Contoh: BCA, GoPay, OVO (opsional)',
                      prefixIcon: Icon(Icons.business_outlined, color: color),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Saldo awal (hanya saat create)
              if (!isEditing) ...[
                const Text('Saldo Awal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Masukkan saldo rekening saat ini',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _balanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: color),
                    hintText: '0',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: color, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Saldo akan otomatis berubah saat kamu mencatat transaksi dan memilih rekening ini.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ).copyWith(
                    backgroundColor: MaterialStateProperty.all(Colors.transparent),
                    shadowColor: MaterialStateProperty.all(Colors.transparent),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _submitting
                          ? null
                          : LinearGradient(colors: [color.withOpacity(0.8), color]),
                      color: _submitting ? AppColors.textHint : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      child: _submitting
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              isEditing ? 'Simpan Perubahan' : 'Tambah Rekening',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconData(String name) {
    const map = {
      'account_balance': Icons.account_balance_rounded,
      'payments': Icons.payments_rounded,
      'account_balance_wallet': Icons.account_balance_wallet_rounded,
      'trending_up': Icons.trending_up_rounded,
      'wallet': Icons.wallet_rounded,
    };
    return map[name] ?? Icons.account_balance_rounded;
  }
}
