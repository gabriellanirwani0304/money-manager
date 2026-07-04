import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../../transaction/models/transaction_models.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/money_card.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Kategori'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Pengeluaran'),
            Tab(text: 'Pemasukan'),
          ],
        ),
      ),
      body: Consumer<CategoryProvider>(
        builder: (_, p, __) {
          if (p.loading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          return TabBarView(
            controller: _tabCtrl,
            children: [
              _CategoryList(
                categories: p.categories.where((c) => c.type == 'expense').toList(),
                onAdd: () => _showForm(context, type: 'expense'),
                onEdit: (c) => _showForm(context, existing: c),
                onDelete: (c) => _confirmDelete(context, c),
              ),
              _CategoryList(
                categories: p.categories.where((c) => c.type == 'income').toList(),
                onAdd: () => _showForm(context, type: 'income'),
                onEdit: (c) => _showForm(context, existing: c),
                onDelete: (c) => _confirmDelete(context, c),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_category',
        onPressed: () {
          final type = _tabCtrl.index == 0 ? 'expense' : 'income';
          _showForm(context, type: type);
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _showForm(BuildContext context, {CategoryModel? existing, String? type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CategoryForm(
        existing: existing,
        defaultType: type ?? (existing?.type ?? 'expense'),
        provider: context.read<CategoryProvider>(),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CategoryModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Hapus kategori "${c.name}"?'),
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
    if (ok != true || !context.mounted) return;

    final p = context.read<CategoryProvider>();
    final result = await p.delete(c.id);

    if (!context.mounted) return;

    if (result == DeleteResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori dihapus'), backgroundColor: AppColors.income),
      );
    } else if (result == DeleteResult.conflict) {
      _showReassignDialog(context, c);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(p.error ?? 'Gagal menghapus'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  void _showReassignDialog(BuildContext context, CategoryModel c) async {
    final p = context.read<CategoryProvider>();
    final others = p.categories.where((x) => x.id != c.id && x.type == c.type).toList();

    if (others.isEmpty) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Tidak Bisa Dihapus'),
          content: Text(
            'Kategori "${c.name}" masih memiliki transaksi, '
            'tapi tidak ada kategori ${c.type == 'expense' ? 'pengeluaran' : 'pemasukan'} '
            'lain untuk memindahkannya.\n\nTambah kategori lain terlebih dahulu.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mengerti')),
          ],
        ),
      );
      return;
    }

    CategoryModel? selected = others.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Pindahkan Transaksi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kategori "${c.name}" masih memiliki transaksi. '
                'Pilih kategori tujuan sebelum menghapus:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...others.map((cat) {
                Color catColor;
                try {
                  catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
                } catch (_) {
                  catColor = AppColors.primary;
                }
                final isSelected = selected?.id == cat.id;
                return InkWell(
                  onTap: () => setState(() => selected = cat),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: isSelected ? AppColors.primary : AppColors.textHint,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: _isEmoji(cat.icon)
                                ? Text(cat.icon, style: const TextStyle(fontSize: 14))
                                : Icon(Icons.category_outlined, size: 14, color: catColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(cat.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: selected == null ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
              child: const Text('Pindahkan & Hapus', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selected == null || !context.mounted) return;

    // Show loading while reassigning
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(width: 16),
            Text('Memindahkan transaksi...'),
          ],
        ),
      ),
    );

    final ok = await p.reassignAndDelete(c.id, selected!.id);

    if (context.mounted) {
      Navigator.pop(context); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Transaksi dipindahkan & kategori dihapus'
              : (p.error ?? 'Gagal memindahkan transaksi')),
          backgroundColor: ok ? AppColors.income : AppColors.expense,
        ),
      );
    }
  }
}

bool _isEmoji(String s) => s.runes.any((r) => r > 127);

class _CategoryList extends StatelessWidget {
  final List<CategoryModel> categories;
  final VoidCallback onAdd;
  final void Function(CategoryModel) onEdit;
  final void Function(CategoryModel) onDelete;

  const _CategoryList({
    required this.categories,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return EmptyState(
        emoji: '🗂️',
        title: 'Belum ada kategori custom',
        subtitle: 'Buat kategori sendiri untuk menyesuaikan pencatatan keuanganmu',
        actionLabel: 'Tambah Kategori',
        onAction: onAdd,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: categories.length,
      itemBuilder: (ctx, i) {
        final c = categories[i];
        Color catColor;
        try {
          catColor = Color(int.parse(c.color.replaceFirst('#', '0xFF')));
        } catch (_) {
          catColor = AppColors.primary;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: _isEmoji(c.icon)
                        ? Text(c.icon, style: const TextStyle(fontSize: 20))
                        : CategoryIconWidget(icon: c.icon, color: c.color, size: 40),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      if (c.isDefault)
                        const Text('Default',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (!c.isDefault) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    onPressed: () => onEdit(c),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                    onPressed: () => onDelete(c),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textHint),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryForm extends StatefulWidget {
  final CategoryModel? existing;
  final String defaultType;
  final CategoryProvider provider;

  const _CategoryForm({
    this.existing,
    required this.defaultType,
    required this.provider,
  });

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _nameCtrl = TextEditingController();
  String _type = 'expense';
  String _icon = '📦';
  String _color = '#6366F1';
  bool _submitting = false;

  static const _emojiOptions = [
    '🍔','🍜','🍕','🍱','☕','🍣','🥗','🥤','🍺','🍰',
    '🛒','🛍️','👗','👠','💄','👟','🧢','👜','💎','🏷️',
    '🏠','🛋️','🪴','🧹','🔧','🔑','📦','💡','🛁','🚿',
    '🚗','🚌','✈️','🚢','🚲','🛵','🚕','⛽','🚁','🏍️',
    '💊','🏥','🏋️','🧘','🩺','🦷','🏃','🚴','⚽','🏀',
    '🎬','🎮','🎵','🎭','🎲','📸','🎤','🎸','🎯','🎨',
    '📚','🎓','💼','💻','📱','🖥️','📝','✏️','🔬','🏫',
    '💳','💰','💸','📈','🏦','📊','🪙','🧾','💹','🤑',
    '❤️','👶','🎁','🎉','🎂','🌹','🐾','🐕','🐈','🌱',
    '⚡','💧','🌐','🔥','♻️','🔔','⚙️','🔋','📺','☎️',
  ];

  static const _colorOptions = [
    '#EF4444','#F97316','#EAB308','#22C55E','#10B981',
    '#06B6D4','#3B82F6','#6366F1','#8B5CF6','#EC4899',
    '#DC2626','#EA580C','#CA8A04','#16A34A','#059669',
    '#0891B2','#2563EB','#4F46E5','#7C3AED','#DB2777',
    '#6B7280','#374151','#1F2937','#111827','#6C5CE7',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.defaultType;
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _icon = widget.existing!.icon;
      _color = widget.existing!.color;
      _type = widget.existing!.type;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Color get _parsedColor {
    try {
      return Color(int.parse(_color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);

    bool ok;
    if (widget.existing != null) {
      ok = await widget.provider.update(
        widget.existing!.id,
        name: _nameCtrl.text.trim(),
        icon: _icon,
        color: _color,
      );
    } else {
      ok = await widget.provider.create(
        name: _nameCtrl.text.trim(),
        type: _type,
        icon: _icon,
        color: _color,
      );
    }

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existing != null ? 'Kategori diperbarui' : 'Kategori ditambahkan 🎉'),
            backgroundColor: AppColors.income,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.provider.error ?? 'Gagal menyimpan'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
              widget.existing != null ? 'Edit Kategori' : 'Tambah Kategori',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // Nama
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama Kategori',
                prefixIcon: Icon(Icons.label_outline_rounded, color: AppColors.primary),
              ),
            ),

            // Tipe (hanya saat create)
            if (widget.existing == null) ...[
              const SizedBox(height: 16),
              const Text('Tipe', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _TypeBtn(
                    label: '📉 Pengeluaran',
                    selected: _type == 'expense',
                    onTap: () => setState(() => _type = 'expense'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TypeBtn(
                    label: '📈 Pemasukan',
                    selected: _type == 'income',
                    onTap: () => setState(() => _type = 'income'),
                  ),
                ),
              ]),
            ],

            const SizedBox(height: 16),

            // Icon preview + picker
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _parsedColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _parsedColor, width: 2),
                ),
                child: Center(child: Text(_icon, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              const Text('Pilih icon:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Container(
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 10,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _emojiOptions.length,
                itemBuilder: (_, i) {
                  final e = _emojiOptions[i];
                  final sel = _icon == e;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = e),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? _parsedColor.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: sel ? Border.all(color: _parsedColor) : null,
                      ),
                      child: Center(child: Text(e, style: const TextStyle(fontSize: 18))),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Color picker
            const Text('Warna', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((c) {
                Color col;
                try { col = Color(int.parse(c.replaceFirst('#', '0xFF'))); } catch (_) { col = AppColors.primary; }
                final sel = _color == c;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: sel ? Border.all(color: Colors.black, width: 2) : null,
                    ),
                    child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.existing != null ? 'Simpan' : 'Tambah'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: selected ? AppColors.primary.withValues(alpha: 0.1) : null,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        color: selected ? AppColors.primary : AppColors.textPrimary,
      )),
    );
  }
}
