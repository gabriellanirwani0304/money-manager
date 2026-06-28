import { useEffect, useState, useMemo } from 'react'
import { useTheme } from '@/context/ThemeContext'
import { listTransactions, type Transaction } from '@/api/transactions'
import { listAccounts, type Account } from '@/api/accounts'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import PageHeader from '@/components/shared/PageHeader'
import { ChevronLeft, ChevronRight, ArrowLeftRight, CalendarDays, TrendingDown, TrendingUp, Flame, Tag, Zap, BarChart3, Activity, Wallet, Hash } from 'lucide-react'

const DAY_NAMES = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
const MONTH_NAMES = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember']

const rp = (n: number) =>
  new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(n)

function compact(n: number) {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}jt`
  if (n >= 1_000) return `${Math.round(n / 1_000)}rb`
  return String(n)
}

interface DayData { income: number; expense: number; transferCount: number; count: number }

export default function CalendarPage() {
  const { theme } = useTheme()
  const cellBase = theme === 'sakura' ? 'oklch(1 0 0)' : 'var(--card)'

  const now = new Date()
  const [year, setYear] = useState(now.getFullYear())
  const [month, setMonth] = useState(now.getMonth())

  const [allTxs, setAllTxs] = useState<Transaction[]>([])
  const [accounts, setAccounts] = useState<Account[]>([])
  const [filterAccount, setFilterAccount] = useState<string>('')
  const [filterType, setFilterType] = useState<string>('')
  const [selected, setSelected] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const startDate = `${year}-${String(month + 1).padStart(2, '0')}-01`
  const lastDay = new Date(year, month + 1, 0).getDate()
  const endDate = `${year}-${String(month + 1).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`

  useEffect(() => {
    listAccounts().then(r => setAccounts(r.data.data ?? [])).catch(() => {})
  }, [])

  useEffect(() => {
    setLoading(true)
    setSelected(null)
    listTransactions({ start_date: startDate, end_date: endDate, limit: 500 })
      .then(r => setAllTxs(r.data.data.transactions ?? []))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [year, month])

  // Apply filters in-memory
  const filteredTxs = useMemo(() => {
    return allTxs.filter(t => {
      if (filterType && t.type !== filterType) return false
      if (filterAccount && t.account_id !== filterAccount && t.to_account_id !== filterAccount) return false
      return true
    })
  }, [allTxs, filterType, filterAccount])

  // Build day map from filtered txs
  const { txMap, totalIncome, totalExpense } = useMemo(() => {
    const map: Record<string, DayData> = {}
    let inc = 0, exp = 0
    filteredTxs.forEach(t => {
      const day = t.date.slice(0, 10)
      if (!map[day]) map[day] = { income: 0, expense: 0, transferCount: 0, count: 0 }
      if (t.type === 'income') { map[day].income += t.amount; inc += t.amount }
      else if (t.type === 'expense') { map[day].expense += t.amount; exp += t.amount }
      else if (t.type === 'transfer') map[day].transferCount++
      map[day].count++
    })
    return { txMap: map, totalIncome: inc, totalExpense: exp }
  }, [filteredTxs])

  // Max expense in a day (for heatmap intensity)
  const maxDayExpense = useMemo(() =>
    Math.max(...Object.values(txMap).map(d => d.expense), 1), [txMap])

  const prevMonth = () => { if (month === 0) { setMonth(11); setYear(y => y - 1) } else setMonth(m => m - 1) }
  const nextMonth = () => { if (month === 11) { setMonth(0); setYear(y => y + 1) } else setMonth(m => m + 1) }

  const firstDow = new Date(year, month, 1).getDay()
  const totalCells = Math.ceil((firstDow + lastDay) / 7) * 7
  const cells = Array.from({ length: totalCells }, (_, i) => {
    const d = i - firstDow + 1
    return d >= 1 && d <= lastDay ? d : null
  })
  const weeks = Math.ceil(totalCells / 7)
  const todayStr = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`

  const selectedTxs = selected ? filteredTxs.filter(t => t.date.slice(0, 10) === selected) : []
  const selectedData = selected ? txMap[selected] : null

  const net = totalIncome - totalExpense
  const savingsRate = totalIncome > 0 ? Math.round((net / totalIncome) * 100) : 0
  const activeDays = Object.keys(txMap).length
  const avgPerActiveDay = activeDays > 0 ? totalExpense / activeDays : 0

  // Best spending day (lowest expense among days with any activity)
  const biggestExpenseDay = Object.entries(txMap)
    .filter(([, d]) => d.expense > 0)
    .sort(([, a], [, b]) => b.expense - a.expense)[0]

  // Top expense category
  const topCategory = useMemo(() => {
    const catMap: Record<string, { name: string; icon: string; amount: number }> = {}
    filteredTxs.filter(t => t.type === 'expense' && t.category).forEach(t => {
      const k = t.category!.id
      if (!catMap[k]) catMap[k] = { name: t.category!.name, icon: t.category!.icon ?? '?', amount: 0 }
      catMap[k].amount += t.amount
    })
    return Object.values(catMap).sort((a, b) => b.amount - a.amount)[0] ?? null
  }, [filteredTxs])

  // Day of week with highest total expense
  const busiestDow = useMemo(() => {
    const dowExp = [0, 0, 0, 0, 0, 0, 0]
    filteredTxs.filter(t => t.type === 'expense').forEach(t => {
      dowExp[new Date(t.date).getDay()] += t.amount
    })
    const max = Math.max(...dowExp)
    if (max === 0) return null
    return { label: DAY_NAMES[dowExp.indexOf(max)], amount: max }
  }, [filteredTxs])

  // Day with most transactions
  const busiestDay = useMemo(() =>
    Object.entries(txMap).sort(([, a], [, b]) => b.count - a.count)[0] ?? null
  , [txMap])

  // Biggest income day
  const biggestIncomeDay = useMemo(() =>
    Object.entries(txMap).filter(([, d]) => d.income > 0).sort(([, a], [, b]) => b.income - a.income)[0] ?? null
  , [txMap])

  // No-spend streak ending today
  const noSpendStreak = useMemo(() => {
    let streak = 0
    const d = new Date(year, month, lastDay)
    while (d.getMonth() === month) {
      const ds = `${year}-${String(month+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
      if (txMap[ds]?.expense) break
      if (d <= new Date()) streak++
      d.setDate(d.getDate() - 1)
    }
    return streak
  }, [txMap, year, month, lastDay])

  const totalTxCount = filteredTxs.length
  const expenseTxCount = filteredTxs.filter(t => t.type === 'expense').length
  const avgExpensePerTx = expenseTxCount > 0 ? Math.round(totalExpense / expenseTxCount) : 0

  return (
    <div className="space-y-4">
      <PageHeader title="Kalender" description="Aktivitas keuangan harian — klik tanggal untuk detail" />

      {/* Controls row */}
      <div className="flex items-center gap-2 flex-wrap">
        <Button variant="outline" size="icon" onClick={prevMonth}><ChevronLeft size={16} /></Button>
        <h2 className="text-base font-semibold min-w-[140px] text-center">{MONTH_NAMES[month]} {year}</h2>
        <Button variant="outline" size="icon" onClick={nextMonth}><ChevronRight size={16} /></Button>

        <div className="ml-auto flex gap-2">
          <Select value={filterType} onValueChange={v => setFilterType(v ?? '')}>
            <SelectTrigger className="w-36 h-8 text-xs">
              <SelectValue>
                {filterType === 'income' ? 'Pemasukan' : filterType === 'expense' ? 'Pengeluaran' : filterType === 'transfer' ? 'Transfer' : 'Semua Tipe'}
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="">Semua Tipe</SelectItem>
              <SelectItem value="income">Pemasukan</SelectItem>
              <SelectItem value="expense">Pengeluaran</SelectItem>
              <SelectItem value="transfer">Transfer</SelectItem>
            </SelectContent>
          </Select>

          <Select value={filterAccount} onValueChange={v => setFilterAccount(v ?? '')}>
            <SelectTrigger className="w-40 h-8 text-xs">
              <SelectValue>
                {filterAccount ? accounts.find(a => a.id === filterAccount)?.name ?? 'Rekening' : 'Semua Rekening'}
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="">Semua Rekening</SelectItem>
              {accounts.map(a => <SelectItem key={a.id} value={a.id}>{a.name}</SelectItem>)}
            </SelectContent>
          </Select>
        </div>
      </div>

      {/* Day header — 7 cols + 1 for week total */}
      <div className="grid gap-1" style={{ gridTemplateColumns: 'repeat(7, 1fr) 48px' }}>
        {DAY_NAMES.map((d, i) => (
          <div key={d} className={`text-center text-xs font-semibold py-1 ${i === 0 ? 'text-red-500' : i === 6 ? 'text-blue-500' : 'text-muted-foreground'}`}>{d}</div>
        ))}
        <div className="text-center text-xs font-semibold py-1 text-muted-foreground/50">W</div>
      </div>

      {/* Calendar grid + week totals */}
      <div className={`space-y-1 ${loading ? 'opacity-50' : ''}`}>
        {Array.from({ length: weeks }, (_, w) => {
          const weekCells = cells.slice(w * 7, w * 7 + 7)
          // Week totals
          let weekIncome = 0, weekExpense = 0
          weekCells.forEach(day => {
            if (!day) return
            const ds = `${year}-${String(month+1).padStart(2,'0')}-${String(day).padStart(2,'0')}`
            weekIncome += txMap[ds]?.income ?? 0
            weekExpense += txMap[ds]?.expense ?? 0
          })

          return (
            <div key={w} className="grid gap-1" style={{ gridTemplateColumns: 'repeat(7, 1fr) 48px' }}>
              {weekCells.map((day, idx) => {
                if (!day) return <div key={`e-${w}-${idx}`} className="min-h-[72px]" />
                const dateStr = `${year}-${String(month+1).padStart(2,'0')}-${String(day).padStart(2,'0')}`
                const data = txMap[dateStr]
                const isToday = dateStr === todayStr
                const isSelected = dateStr === selected
                const dow = (firstDow + day - 1) % 7
                // Heatmap: very soft pastel expense tint, up to 8% intensity
                const heatPct = data?.expense ? Math.min(Math.round((data.expense / maxDayExpense) * 8), 8) : 0

                return (
                  <button key={dateStr} onClick={() => setSelected(isSelected ? null : dateStr)}
                    className={`flex min-h-[72px] flex-col rounded-lg border p-1.5 text-left transition-all relative overflow-hidden
                      ${isSelected ? 'border-primary ring-1 ring-primary' : 'border-border hover:border-primary/40'}`}
                    style={{
                      backgroundColor: isSelected
                        ? `color-mix(in oklch, var(--primary) 8%, ${cellBase})`
                        : heatPct > 0
                        ? `color-mix(in oklch, var(--color-red-200) ${heatPct}%, ${cellBase})`
                        : cellBase
                    }}
                  >
                    <span className={`text-xs font-semibold mb-0.5 ${dow === 0 ? 'text-red-500' : dow === 6 ? 'text-blue-500' : isToday ? 'text-primary' : ''}`}>
                      {day}
                      {isToday && <span className="ml-1 text-[9px] bg-primary text-primary-foreground rounded px-1">Hari ini</span>}
                    </span>
                    {data && (
                      <div className="flex flex-col gap-0.5 mt-0.5">
                        {data.income > 0 && (
                          <span className="text-[10px] font-medium text-green-600 leading-tight">
                            +{compact(data.income)}
                            {totalIncome > 0 && <span className="text-green-400 ml-0.5">{Math.round((data.income/totalIncome)*100)}%</span>}
                          </span>
                        )}
                        {data.expense > 0 && (
                          <span className="text-[10px] font-medium text-red-500 leading-tight">
                            -{compact(data.expense)}
                            {totalExpense > 0 && <span className="text-red-300 ml-0.5">{Math.round((data.expense/totalExpense)*100)}%</span>}
                          </span>
                        )}
                        {data.transferCount > 0 && (
                          <span className="text-[10px] text-blue-500 leading-tight flex items-center gap-0.5">
                            <ArrowLeftRight size={9} />{data.transferCount}×
                          </span>
                        )}
                      </div>
                    )}
                  </button>
                )
              })}

              {/* Week total column */}
              <div className="flex min-h-[72px] flex-col items-center justify-center rounded-lg bg-muted/30 border border-dashed border-border/50 px-1 gap-0.5">
                {weekIncome > 0 && <span className="text-[9px] font-medium text-green-600 leading-tight">+{compact(weekIncome)}</span>}
                {weekExpense > 0 && <span className="text-[9px] font-medium text-red-500 leading-tight">-{compact(weekExpense)}</span>}
                {weekIncome === 0 && weekExpense === 0 && <span className="text-[9px] text-muted-foreground/40">—</span>}
              </div>
            </div>
          )
        })}
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="flex items-center gap-3 rounded-xl border bg-green-50 dark:bg-green-950/20 p-4">
          <TrendingUp size={20} className="text-green-600 shrink-0" />
          <div>
            <p className="text-xs text-muted-foreground mb-1">Pemasukan</p>
            <p className="text-base font-bold text-green-600">+{rp(totalIncome)}</p>
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-xl border bg-red-50 dark:bg-red-950/20 p-4">
          <TrendingDown size={20} className="text-red-500 shrink-0" />
          <div>
            <p className="text-xs text-muted-foreground mb-1">Pengeluaran</p>
            <p className="text-base font-bold text-red-500">-{rp(totalExpense)}</p>
          </div>
        </div>
        <div className={`flex items-center gap-3 rounded-xl border p-4 ${net >= 0 ? 'bg-green-50 dark:bg-green-950/20' : 'bg-red-50 dark:bg-red-950/20'}`}>
          <Wallet size={20} className={`shrink-0 ${net >= 0 ? 'text-green-600' : 'text-red-500'}`} />
          <div>
            <p className="text-xs text-muted-foreground mb-1">Selisih</p>
            <p className={`text-base font-bold ${net >= 0 ? 'text-green-600' : 'text-red-500'}`}>
              {net >= 0 ? '+' : ''}{rp(net)}
            </p>
            <p className="text-[11px] text-muted-foreground mt-0.5">
              {savingsRate >= 0 ? `Tabungan ${savingsRate}%` : `Defisit ${Math.abs(savingsRate)}%`}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-xl border bg-card p-4">
          <Hash size={20} className="text-muted-foreground shrink-0" />
          <div>
            <p className="text-xs text-muted-foreground mb-1">Jumlah transaksi</p>
            <p className="text-base font-bold">{totalTxCount}</p>
            <p className="text-[11px] text-muted-foreground mt-0.5">{activeDays} hari aktif</p>
          </div>
        </div>
      </div>

      {/* Stats bar */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="flex items-center gap-3 rounded-xl border bg-card p-3">
          <CalendarDays size={18} className="text-muted-foreground shrink-0" />
          <div>
            <p className="text-xs text-muted-foreground">Hari aktif</p>
            <p className="text-sm font-bold">{activeDays} hari</p>
            <p className="text-[11px] text-muted-foreground">rata-rata {rp(Math.round(avgPerActiveDay))}/hari</p>
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-xl border bg-card p-3">
          <TrendingDown size={18} className="text-red-500 shrink-0" />
          <div>
            <p className="text-xs text-muted-foreground">Pengeluaran terbesar</p>
            {biggestExpenseDay ? (
              <>
                <p className="text-sm font-bold text-red-500">{rp(biggestExpenseDay[1].expense)}</p>
                <p className="text-[11px] text-muted-foreground">
                  {(() => { const [,m,d] = biggestExpenseDay[0].split('-'); return `${d}/${m}` })()}
                </p>
              </>
            ) : <p className="text-sm text-muted-foreground">—</p>}
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-xl border bg-card p-3">
          <Activity size={18} className="text-muted-foreground shrink-0" />
          <div>
            <p className="text-xs text-muted-foreground">Rata-rata belanja</p>
            {expenseTxCount > 0 ? (
              <>
                <p className="text-sm font-bold text-red-500">{rp(avgExpensePerTx)}</p>
                <p className="text-[11px] text-muted-foreground">per transaksi</p>
              </>
            ) : <p className="text-sm text-muted-foreground">—</p>}
          </div>
        </div>
        <div className="flex items-center gap-3 rounded-xl border bg-card p-3">
          <Flame size={18} className={noSpendStreak >= 3 ? 'text-orange-500 shrink-0' : 'text-muted-foreground shrink-0'} />
          <div>
            <p className="text-xs text-muted-foreground">No-spend streak</p>
            <p className="text-sm font-bold">{noSpendStreak} hari</p>
            <p className="text-[11px] text-muted-foreground">berturut tanpa pengeluaran</p>
          </div>
        </div>
      </div>

      {/* Extra insights */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {/* Top expense category */}
        <div className="flex items-center gap-3 rounded-xl border bg-card p-3">
          <Tag size={18} className="text-muted-foreground shrink-0" />
          <div className="min-w-0">
            <p className="text-xs text-muted-foreground">Kategori terbesar</p>
            {topCategory ? (
              <>
                <p className="text-sm font-bold truncate">{topCategory.icon} {topCategory.name}</p>
                <p className="text-[11px] text-red-500">{rp(topCategory.amount)}</p>
              </>
            ) : <p className="text-sm text-muted-foreground">—</p>}
          </div>
        </div>

        {/* Busiest day of week */}
        <div className="flex items-center gap-3 rounded-xl border bg-card p-3">
          <BarChart3 size={18} className="text-muted-foreground shrink-0" />
          <div>
            <p className="text-xs text-muted-foreground">Hari paling boros</p>
            {busiestDow ? (
              <>
                <p className="text-sm font-bold">{busiestDow.label}</p>
                <p className="text-[11px] text-muted-foreground">total {rp(busiestDow.amount)}</p>
              </>
            ) : <p className="text-sm text-muted-foreground">—</p>}
          </div>
        </div>

        {/* Day with most transactions */}
        <div className="flex items-center gap-3 rounded-xl border bg-card p-3">
          <Zap size={18} className="text-muted-foreground shrink-0" />
          <div>
            <p className="text-xs text-muted-foreground">Hari tersibuk</p>
            {busiestDay ? (
              <>
                <p className="text-sm font-bold">
                  {(() => { const [,m,d] = busiestDay[0].split('-'); return `${d}/${m}` })()}
                </p>
                <p className="text-[11px] text-muted-foreground">{busiestDay[1].count} transaksi</p>
              </>
            ) : <p className="text-sm text-muted-foreground">—</p>}
          </div>
        </div>

        {/* Biggest income day */}
        <div className="flex items-center gap-3 rounded-xl border bg-card p-3">
          <TrendingUp size={18} className="text-green-600 shrink-0" />
          <div>
            <p className="text-xs text-muted-foreground">Pemasukan terbesar</p>
            {biggestIncomeDay ? (
              <>
                <p className="text-sm font-bold text-green-600">{rp(biggestIncomeDay[1].income)}</p>
                <p className="text-[11px] text-muted-foreground">
                  {(() => { const [,m,d] = biggestIncomeDay[0].split('-'); return `${d}/${m}` })()}
                </p>
              </>
            ) : <p className="text-sm text-muted-foreground">—</p>}
          </div>
        </div>
      </div>

      {/* Day detail */}
      {selected && (
        <Card className="p-4">
          <div className="flex items-center justify-between mb-3">
            <p className="text-sm font-semibold">
              {(() => { const [,m,d] = selected.split('-'); return `${d}/${m}/${year}` })()}
              <span className="text-muted-foreground font-normal ml-2 text-xs">
                {selectedTxs.length} transaksi
              </span>
            </p>
            {selectedData && (
              <div className="flex gap-4 text-xs">
                {selectedData.income > 0 && <span className="text-green-600 font-medium">+{rp(selectedData.income)}</span>}
                {selectedData.expense > 0 && <span className="text-red-500 font-medium">-{rp(selectedData.expense)}</span>}
              </div>
            )}
          </div>
          {selectedTxs.length === 0 ? (
            <p className="text-sm text-muted-foreground">Tidak ada transaksi</p>
          ) : (
            <div className="space-y-2">
              {selectedTxs.map(t => (
                <div key={t.id} className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-2 min-w-0">
                    {t.type === 'transfer'
                      ? <ArrowLeftRight size={16} className="text-blue-500 shrink-0" />
                      : <span className="text-base shrink-0">{t.category?.icon}</span>
                    }
                    <div className="min-w-0">
                      <span className="font-medium">
                        {t.type === 'transfer'
                          ? `${t.account?.name ?? '?'} → ${t.to_account?.name ?? '?'}`
                          : t.category?.name ?? '—'}
                      </span>
                      {t.description && <span className="text-muted-foreground text-xs ml-1.5">· {t.description}</span>}
                      {t.account && t.type !== 'transfer' && (
                        <span className="text-muted-foreground text-xs ml-1.5">· {t.account.name}</span>
                      )}
                    </div>
                  </div>
                  <span className={`font-medium shrink-0 ml-2 ${t.type === 'income' ? 'text-green-600' : t.type === 'transfer' ? 'text-blue-600' : 'text-red-500'}`}>
                    {t.type === 'income' ? '+' : t.type === 'transfer' ? '' : '-'}{rp(t.amount)}
                  </span>
                </div>
              ))}
            </div>
          )}
        </Card>
      )}
    </div>
  )
}
