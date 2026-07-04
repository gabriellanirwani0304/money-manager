import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/money_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transaction/screens/add_transaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final currency = auth.user?.currency ?? 'IDR';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => context.read<DashboardProvider>().load(),
        child: Consumer<DashboardProvider>(
          builder: (_, provider, __) {
            if (provider.loading && provider.data == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final data = provider.data;

            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: _buildHeader(context, auth, data, currency),
                ),

                // Budget Alerts
                if (data != null && data.budgetAlerts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildBudgetAlerts(data, currency),
                  ),

                // Top Expenses
                if (data != null && data.topExpenses.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildTopExpenses(data, currency),
                  ),

                // Recent Transactions
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: SectionHeader(
                      title: 'Transaksi Terbaru',
                      actionLabel: 'Lihat Semua',
                      onAction: () {
                        // Navigate to transactions tab
                      },
                    ),
                  ),
                ),

                if (data?.recentTransactions.isEmpty ?? true)
                  const SliverToBoxAdapter(
                    child: _EmptyTransactions(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final tx = data!.recentTransactions[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              child: Row(
                                children: [
                                  CategoryIconWidget(icon: tx.category.icon, color: tx.category.color),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.description.isNotEmpty ? tx.description : tx.category.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${tx.category.name} • ${DateFormatter.timeAgo(tx.date)}',
                                          style: const TextStyle(
                                              color: AppColors.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AmountText(
                                    amount: tx.amount,
                                    isIncome: tx.type == 'income',
                                    showSign: true,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: data?.recentTransactions.length ?? 0,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider auth, dynamic data, String currency) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hai, 👋',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    auth.user?.name ?? 'Pengguna',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.person_outline, color: Colors.white),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) async {
                        if (value == 'logout') {
                          await context.read<AuthProvider>().logout();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Logout', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Balance card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Text('Total Saldo', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(data?.balance ?? 0, currency: currency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        'Pemasukan',
                        data?.income ?? 0,
                        Icons.arrow_downward_rounded,
                        AppColors.income,
                        currency,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                    Expanded(
                      child: _buildSummaryItem(
                        'Pengeluaran',
                        data?.expense ?? 0,
                        Icons.arrow_upward_rounded,
                        AppColors.expense,
                        currency,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, double amount, IconData icon, Color color, String currency) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          CurrencyFormatter.compact(amount, currency: currency),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildBudgetAlerts(dynamic data, String currency) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '⚠️ Peringatan Budget',
            actionLabel: 'Lihat Semua',
            onAction: () {},
          ),
          const SizedBox(height: 12),
          ...data.budgetAlerts.map<Widget>((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  color: AppColors.expenseLight,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              a.categoryName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${a.percentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: AppColors.expense, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (a.percentage / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation(
                            a.percentage > 100 ? AppColors.exceeded : AppColors.expense,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Terpakai: ${CurrencyFormatter.compact(a.spent, currency: currency)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            'Dari: ${CurrencyFormatter.compact(a.budgetAmount, currency: currency)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTopExpenses(dynamic data, String currency) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '🔥 Pengeluaran Terbesar'),
          const SizedBox(height: 12),
          Row(
            children: data.topExpenses
                .asMap()
                .entries
                .map<Widget>((e) {
                  final idx = e.key;
                  final top = e.value;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: idx < data.topExpenses.length - 1 ? 8 : 0),
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${idx + 1}',
                              style: TextStyle(
                                  color: AppColors.chartColors[idx],
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20),
                            ),
                            const SizedBox(height: 4),
                            Text(top.categoryName,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                              CurrencyFormatter.compact(top.amount, currency: currency),
                              style: TextStyle(
                                  color: AppColors.chartColors[idx],
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        );
        if (mounted) context.read<DashboardProvider>().load();
      },
      backgroundColor: AppColors.primary,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('Catat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      emoji: '✨',
      title: 'Mulai perjalananmu!',
      subtitle: 'Catat transaksi pertamamu dan mulai kendalikan keuanganmu',
    );
  }
}
