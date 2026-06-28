import { useEffect, useState } from 'react'
import { getDashboard, getCategoryBreakdown, getMonthlyTrend } from '@/api/reports'
import { listAccounts, type Account } from '@/api/accounts'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import PageHeader from '@/components/shared/PageHeader'
import { TrendingUp, TrendingDown, Wallet, ArrowLeftRight, AlertTriangle, ArrowRight } from 'lucide-react'
import { Link } from 'react-router-dom'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend,
} from 'recharts'

interface CategoryInfo {
  id: string
  name: string
  icon: string
  color: string
}

interface RecentTransaction {
  id: string
  type: string
  amount: number
  description: string
  date: string
  category: CategoryInfo
}

interface BudgetAlert {
  category_name: string
  budget_amount: number
  spent: number
  percentage: number
}

interface TopCategory {
  category_name: string
  amount: number
  percentage: number
}

interface DashboardData {
  balance: number
  income: number
  expense: number
  recent_transactions: RecentTransaction[]
  budget_alerts: BudgetAlert[]
  top_expenses: TopCategory[]
}

interface CategoryBreakdown {
  category: CategoryInfo
  amount: number
  percentage: number
}

interface TrendItem {
  month: string
  income: number
  expense: number
}

const COLORS = ['#6366f1','#f59e0b','#10b981','#ef4444','#8b5cf6','#ec4899','#14b8a6','#f97316']

const monthNames = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des']

const ACCOUNT_TYPE_LABELS: Record<string, string> = {
  bank: 'Bank',
  cash: 'Tunai',
  ewallet: 'Dompet Digital',
  investment: 'Investasi',
  other: 'Lainnya',
}

function formatRupiah(n: number) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(n)
}

function formatShort(n: number) {
  if (Math.abs(n) >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(1)}M`
  if (Math.abs(n) >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}jt`
  if (Math.abs(n) >= 1_000) return `${(n / 1_000).toFixed(0)}rb`
  return String(n)
}

export default function DashboardPage() {
  const now = new Date()
  const month = now.getMonth() + 1
  const year = now.getFullYear()

  const [data, setData] = useState<DashboardData | null>(null)
  const [accounts, setAccounts] = useState<Account[]>([])
  const [breakdown, setBreakdown] = useState<CategoryBreakdown[]>([])
  const [trend, setTrend] = useState<TrendItem[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.all([
      getDashboard(month, year),
      listAccounts(),
      getCategoryBreakdown('expense', month, year),
      getMonthlyTrend(),
    ])
      .then(([dash, accs, brkd, trnd]) => {
        setData(dash.data.data as DashboardData)
        setAccounts((accs.data.data ?? []) as Account[])
        setBreakdown((brkd.data.data ?? []) as CategoryBreakdown[])
        const raw = (trnd.data.data ?? []) as TrendItem[]
        setTrend(raw.slice(-6))
      })
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [month, year])

  const totalBalance = accounts.reduce((s, a) => s + a.balance, 0)
  const netMonth = data ? data.income - data.expense : null
  const savingsRate =
    netMonth != null && data?.income && data.income > 0
      ? Math.round((netMonth / data.income) * 100)
      : null

  const trendData = trend.map((t) => ({
    name: monthNames[Number(t.month.split('-')[1]) - 1],
    Pemasukan: t.income,
    Pengeluaran: t.expense,
  }))

  const pieData = breakdown.slice(0, 6).map((b) => ({
    name: `${b.category.icon} ${b.category.name}`,
    value: b.amount,
    pct: b.percentage,
  }))

  const recentTxs = data?.recent_transactions ?? []
  const budgetAlerts = data?.budget_alerts ?? []

  return (
    <div className="space-y-6">
      <PageHeader
        title="Dashboard"
        description={`Ringkasan keuangan ${monthNames[month - 1]} ${year}`}
      />

      {/* Summary cards */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Total Saldo</CardTitle>
            <Wallet size={18} className="text-blue-600" />
          </CardHeader>
          <CardContent>
            {loading ? <Skeleton className="h-7 w-32" /> : (
              <p className="text-xl font-bold text-blue-600">{formatRupiah(totalBalance)}</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Pemasukan</CardTitle>
            <TrendingUp size={18} className="text-green-600" />
          </CardHeader>
          <CardContent>
            {loading ? <Skeleton className="h-7 w-32" /> : (
              <p className="text-xl font-bold text-green-600">
                {data ? formatRupiah(data.income) : '-'}
              </p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Pengeluaran</CardTitle>
            <TrendingDown size={18} className="text-red-600" />
          </CardHeader>
          <CardContent>
            {loading ? <Skeleton className="h-7 w-32" /> : (
              <p className="text-xl font-bold text-red-600">
                {data ? formatRupiah(data.expense) : '-'}
              </p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Selisih Bersih</CardTitle>
            <ArrowLeftRight size={18} className={netMonth != null && netMonth >= 0 ? 'text-green-600' : 'text-red-600'} />
          </CardHeader>
          <CardContent>
            {loading ? <Skeleton className="h-7 w-32" /> : (
              <p className={`text-xl font-bold ${netMonth != null && netMonth >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                {netMonth != null ? formatRupiah(netMonth) : '-'}
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Row 2: Recent Transactions + Accounts + Savings Rate */}
      <div className="grid gap-4 lg:grid-cols-2">
        {/* Recent Transactions */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-3">
            <CardTitle className="text-sm font-semibold">Transaksi Terakhir</CardTitle>
            <Link to="/transactions" className="flex items-center gap-1 text-xs text-primary hover:underline">
              Lihat semua <ArrowRight size={12} />
            </Link>
          </CardHeader>
          <CardContent className="space-y-3">
            {loading ? (
              Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-10 w-full" />)
            ) : recentTxs.length === 0 ? (
              <p className="text-sm text-muted-foreground py-4 text-center">Belum ada transaksi</p>
            ) : (
              recentTxs.map((tx) => (
                <div key={tx.id} className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="text-lg leading-none">{tx.category.icon || '💸'}</span>
                    <div className="min-w-0">
                      <p className="text-sm font-medium truncate">
                        {tx.description || tx.category.name || '—'}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {tx.category.name} · {tx.date}
                      </p>
                    </div>
                  </div>
                  <span className={`text-sm font-semibold whitespace-nowrap ${tx.type === 'income' ? 'text-green-600' : 'text-red-500'}`}>
                    {tx.type === 'income' ? '+' : '-'}{formatRupiah(tx.amount)}
                  </span>
                </div>
              ))
            )}
          </CardContent>
        </Card>

        {/* Accounts + Savings Rate */}
        <div className="space-y-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between pb-3">
              <CardTitle className="text-sm font-semibold">Saldo Rekening</CardTitle>
              <Link to="/accounts" className="flex items-center gap-1 text-xs text-primary hover:underline">
                Kelola <ArrowRight size={12} />
              </Link>
            </CardHeader>
            <CardContent className="space-y-2">
              {loading ? (
                Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-8 w-full" />)
              ) : accounts.length === 0 ? (
                <p className="text-sm text-muted-foreground py-2 text-center">Belum ada rekening</p>
              ) : (
                accounts.map((acc) => (
                  <div key={acc.id} className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium">{acc.name}</p>
                      <p className="text-xs text-muted-foreground">{ACCOUNT_TYPE_LABELS[acc.type] ?? acc.type}</p>
                    </div>
                    <span className="text-sm font-semibold">{formatRupiah(acc.balance)}</span>
                  </div>
                ))
              )}
            </CardContent>
          </Card>

          {/* Savings Rate */}
          {!loading && savingsRate !== null && (
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-semibold">Tingkat Tabungan Bulan Ini</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex items-end justify-between mb-1">
                  <span className={`text-2xl font-bold ${savingsRate >= 20 ? 'text-green-600' : savingsRate >= 0 ? 'text-yellow-500' : 'text-red-500'}`}>
                    {savingsRate}%
                  </span>
                  <span className="text-xs text-muted-foreground">
                    {savingsRate >= 20 ? 'Bagus!' : savingsRate >= 0 ? 'Perlu ditingkatkan' : 'Defisit'}
                  </span>
                </div>
                <div className="h-2 rounded-full bg-muted overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all ${savingsRate >= 20 ? 'bg-green-500' : savingsRate >= 0 ? 'bg-yellow-400' : 'bg-red-500'}`}
                    style={{ width: `${Math.min(Math.max(savingsRate, 0), 100)}%` }}
                  />
                </div>
                <p className="mt-1 text-xs text-muted-foreground">Ideal ≥ 20% dari pemasukan</p>
              </CardContent>
            </Card>
          )}
        </div>
      </div>

      {/* Budget Alerts */}
      {!loading && budgetAlerts.length > 0 && (
        <Card className="border-yellow-300 dark:border-yellow-700">
          <CardHeader className="flex flex-row items-center gap-2 pb-3">
            <AlertTriangle size={16} className="text-yellow-500" />
            <CardTitle className="text-sm font-semibold text-yellow-600 dark:text-yellow-400">
              Peringatan Anggaran
            </CardTitle>
            <Link to="/budgets" className="ml-auto flex items-center gap-1 text-xs text-primary hover:underline">
              Kelola <ArrowRight size={12} />
            </Link>
          </CardHeader>
          <CardContent className="space-y-3">
            {budgetAlerts.map((alert) => (
              <div key={alert.category_name}>
                <div className="flex justify-between text-sm mb-1">
                  <span className="font-medium">{alert.category_name}</span>
                  <span className={alert.percentage >= 100 ? 'text-red-500 font-semibold' : 'text-yellow-600'}>
                    {formatRupiah(alert.spent)} / {formatRupiah(alert.budget_amount)}
                    {' '}({Math.round(alert.percentage)}%)
                  </span>
                </div>
                <div className="h-1.5 rounded-full bg-muted overflow-hidden">
                  <div
                    className={`h-full rounded-full ${alert.percentage >= 100 ? 'bg-red-500' : 'bg-yellow-400'}`}
                    style={{ width: `${Math.min(alert.percentage, 100)}%` }}
                  />
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      )}

      {/* Row 3: Trend chart + Expense donut */}
      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold">Tren 6 Bulan Terakhir</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <Skeleton className="h-52 w-full" />
            ) : trendData.length === 0 ? (
              <p className="text-sm text-muted-foreground py-10 text-center">Belum ada data</p>
            ) : (
              <ResponsiveContainer width="100%" height={200}>
                <BarChart data={trendData} barCategoryGap="30%">
                  <XAxis dataKey="name" tick={{ fontSize: 11 }} axisLine={false} tickLine={false} />
                  <YAxis tickFormatter={formatShort} tick={{ fontSize: 10 }} axisLine={false} tickLine={false} width={40} />
                  <Tooltip formatter={(v: number) => formatRupiah(v)} contentStyle={{ fontSize: 12 }} />
                  <Bar dataKey="Pemasukan" fill="#10b981" radius={[3, 3, 0, 0]} />
                  <Bar dataKey="Pengeluaran" fill="#ef4444" radius={[3, 3, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold">
              Pengeluaran per Kategori — {monthNames[month - 1]}
            </CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <Skeleton className="h-52 w-full" />
            ) : pieData.length === 0 ? (
              <p className="text-sm text-muted-foreground py-10 text-center">Belum ada pengeluaran</p>
            ) : (
              <ResponsiveContainer width="100%" height={200}>
                <PieChart>
                  <Pie data={pieData} cx="40%" cy="50%" innerRadius={52} outerRadius={80} dataKey="value" paddingAngle={2}>
                    {pieData.map((_, i) => (
                      <Cell key={i} fill={COLORS[i % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip
                    formatter={(v: number, _n, p) => [`${formatRupiah(v)} (${p.payload.pct}%)`, p.payload.name]}
                    contentStyle={{ fontSize: 12 }}
                  />
                  <Legend layout="vertical" align="right" verticalAlign="middle" iconType="circle" iconSize={8}
                    formatter={(v) => <span style={{ fontSize: 11 }}>{v}</span>}
                  />
                </PieChart>
              </ResponsiveContainer>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
