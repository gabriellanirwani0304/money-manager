import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/account_models.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/money_card.dart';
import 'add_account_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AccountProvider>(
        builder: (_, p, __) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: p.load,
            child: CustomScrollView(
              slivers: [
                // Header with total
                SliverToBoxAdapter(
                  child: _buildHeader(p),
                ),

                // Account list
                if (p.loading && p.accounts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (p.accounts.isEmpty)
                  SliverFillRemaining(child: _buildEmpty(context))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _AccountCard(
                          account: p.accounts[i],
                          onSetBalance: () => _showSetBalance(context, p, p.accounts[i]),
                          onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddAccountScreen(existing: p.accounts[i]),
                            ),
                          ).then((_) => p.load()),
                          onDelete: () => _confirmDelete(context, p, p.accounts[i]),
                        ),
                        childCount: p.accounts.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_account',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddAccountScreen()),
        ).then((_) => context.read<AccountProvider>().load()),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Rekening',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader(AccountProvider p) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rekening Saya',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Semua Aset',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Saldo',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(p.totalBalance),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${p.accounts.length}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                    const Text('rekening',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyState(
      emoji: '🏦',
      title: 'Belum ada rekening',
      subtitle: 'Tambahkan rekening bank, e-wallet, atau dompet tunaimu untuk melacak saldo',
      actionLabel: 'Tambah Rekening',
      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAccountScreen())),
    );
  }

  void _showSetBalance(BuildContext context, AccountProvider p, AccountModel account) {
    final ctrl = TextEditingController(text: account.balance.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CategoryIconWidget(icon: account.icon, color: account.color, size: 40),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(account.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Perbarui saldo rekening',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Saldo Saat Ini',
                prefixText: 'Rp ',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 Saldo ini hanya mencatat kondisi rekening saat ini. Transaksi yang ditautkan ke rekening ini akan otomatis mengubah saldo.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final balance = double.tryParse(ctrl.text.replaceAll('.', '')) ?? 0;
                  Navigator.pop(context);
                  final ok = await p.setBalance(account.id, balance);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Saldo ${account.name} berhasil diperbarui ✅' : (p.error ?? 'Gagal')),
                        backgroundColor: ok ? AppColors.income : AppColors.expense,
                      ),
                    );
                  }
                },
                child: const Text('Simpan Saldo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AccountProvider p, AccountModel account) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hapus ${account.name}?'),
        content: const Text(
            'Rekening akan dinonaktifkan. Riwayat transaksi yang terhubung tidak akan hilang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await p.delete(account.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AccountModel account;
  final VoidCallback onSetBalance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.onSetBalance,
    required this.onEdit,
    required this.onDelete,
  });

  IconData _iconData(String name) {
    const map = {
      'account_balance': Icons.account_balance_rounded,
      'payments': Icons.payments_rounded,
      'account_balance_wallet': Icons.account_balance_wallet_rounded,
      'trending_up': Icons.trending_up_rounded,
      'wallet': Icons.wallet_rounded,
      'credit_card': Icons.credit_card_rounded,
      'savings': Icons.savings_rounded,
    };
    return map[name] ?? Icons.account_balance_rounded;
  }

  String _formatDelta(double delta) {
    final sign = delta >= 0 ? '+' : '-';
    return '$sign${CurrencyFormatter.compact(delta.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    final color = account.parsedColor;
    final dark = Color.lerp(color, Colors.black, 0.3)!;
    final delta = account.balance - account.initialBalance;
    final hasDelta = account.initialBalance != account.balance && account.initialBalance != 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Card body ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: icon + name + bank + type
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_iconData(account.icon), color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          if (account.bankName.isNotEmpty)
                            Text(account.bankName,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(account.typeLabel,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Balance
                Text('Saldo Saat Ini',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(account.balance),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
                if (hasDelta) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        delta >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 11,
                        color: delta >= 0 ? Colors.greenAccent.shade200 : Colors.redAccent.shade100,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${_formatDelta(delta)} dari saldo awal',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Action row ─────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                _ActionButton(
                  label: 'Set Saldo',
                  icon: Icons.edit_rounded,
                  onTap: onSetBalance,
                  isFirst: true,
                ),
                Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
                _ActionButton(
                  label: 'Edit Info',
                  icon: Icons.tune_rounded,
                  onTap: onEdit,
                ),
                Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.15)),
                _ActionButton(
                  label: 'Hapus',
                  icon: Icons.delete_outline_rounded,
                  onTap: onDelete,
                  isDestructive: true,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isFirst;
  final bool isLast;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent.shade100 : Colors.white;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.only(
          bottomLeft: isFirst ? const Radius.circular(20) : Radius.zero,
          bottomRight: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color.withValues(alpha: 0.85)),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
