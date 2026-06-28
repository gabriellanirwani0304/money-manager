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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Saldo',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(p.totalBalance),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${p.accounts.length} rekening aktif',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_outlined,
                  size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('Belum ada rekening',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Tambahkan rekening bank, e-wallet, atau dompet tunaimu untuk melacak saldo',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddAccountScreen()),
              ).then((_) => context.read<AccountProvider>().load()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Rekening Pertama'),
            ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final color = account.parsedColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header strip dengan warna rekening
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: color.withOpacity(0.15))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_iconData(account.icon), color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        if (account.bankName.isNotEmpty)
                          Text(account.bankName,
                              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(account.typeLabel,
                        style: TextStyle(
                            color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert_rounded, color: color, size: 20),
                    itemBuilder: (_) => [
                      PopupMenuItem(onTap: onSetBalance,
                          child: const Row(children: [
                            Icon(Icons.edit_rounded, size: 16),
                            SizedBox(width: 8), Text('Set Saldo'),
                          ])),
                      PopupMenuItem(onTap: onEdit,
                          child: const Row(children: [
                            Icon(Icons.settings_outlined, size: 16),
                            SizedBox(width: 8), Text('Edit Info'),
                          ])),
                      PopupMenuItem(onTap: onDelete,
                          child: const Row(children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.expense),
                            SizedBox(width: 8),
                            Text('Hapus', style: TextStyle(color: AppColors.expense)),
                          ])),
                    ],
                  ),
                ],
              ),
            ),

            // Balance section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saldo Saat Ini',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(account.balance),
                        style: TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onSetBalance,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.8), color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('Update Saldo',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Initial balance info
            if (account.initialBalance != account.balance)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      'Saldo awal: ${CurrencyFormatter.compact(account.initialBalance)}  •  '
                      'Perubahan: ${_formatDelta(account.balance - account.initialBalance)}',
                      style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDelta(double delta) {
    final sign = delta >= 0 ? '+' : '';
    return '$sign${CurrencyFormatter.compact(delta.abs())}';
  }

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
}
