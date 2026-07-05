import { useEffect, useState, useMemo, useCallback } from 'react'
import {
  listAccounts,
  createAccount,
  updateAccount,
  setBalance,
  deleteAccount,
  type Account,
} from '@/api/accounts'
import { listTransactions, type Transaction } from '@/api/transactions'
import {
  ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, CartesianGrid, Legend,
} from 'recharts'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent } from '@/components/ui/card'
import ConfirmDialog from '@/components/shared/ConfirmDialog'
import PageHeader from '@/components/shared/PageHeader'
import IconPicker from '@/components/shared/IconPicker'
import { Plus, Pencil, Trash2, DollarSign } from 'lucide-react'
import { toast } from 'sonner'

const ACCOUNT_TYPES = [
  { value: 'bank', label: 'Bank' },
  { value: 'cash', label: 'Tunai' },
  { value: 'ewallet', label: 'Dompet Digital' },
  { value: 'investment', label: 'Investasi' },
  { value: 'other', label: 'Lainnya' },
]

const TYPE_EMOJI: Record<string, string> = {
  bank: '🏦', cash: '💵', ewallet: '📱', investment: '📈', other: '💳',
}
const TYPE_LABEL: Record<string, string> = {
  bank: 'Bank', cash: 'Tunai', ewallet: 'Dompet Digital', investment: 'Investasi', other: 'Lainnya',
}

const formatRupiah = (n: number) =>
  new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(n)

const emptyForm = (): Partial<Account> => ({ name: '', type: 'bank', icon: '', color: '#6366f1' })

export default function AccountsPage() {
  const [items, setItems] = useState<Account[]>([])
  const [total, setTotal] = useState<number | null>(null)
  const [historyTxs, setHistoryTxs] = useState<Transaction[]>([])
  const [chartMode, setChartMode] = useState<'12months' | 'monthly'>('monthly')
  const [chartYear, setChartYear] = useState(() => new Date().getFullYear())
  const [chartMonth, setChartMonth] = useState(() => new Date().getMonth())
  const [monthTxs, setMonthTxs] = useState<Transaction[]>([])
  const [monthTxsLoading, setMonthTxsLoading] = useState(false)
  const [open, setOpen] = useState(false)
  const [balanceOpen, setBalanceOpen] = useState(false)
  const [editing, setEditing] = useState<Account | null>(null)
  const [form, setForm] = useState<Partial<Account>>(emptyForm())
  const [newBalance, setNewBalance] = useState('')
  const [deleteID, setDeleteID] = useState<string | null>(null)

  const load = () => {
    listAccounts()
      .then((r) => {
        const data = r.data.data ?? []
        setItems(data)
        setTotal(data.reduce((s, a) => s + a.balance, 0))
      })
      .catch(() => {})
  }

  useEffect(() => {
    load()
    // Load last 12 months of transactions for balance history
    const n = new Date()
    const end = n.toISOString().slice(0, 10)
    n.setMonth(n.getMonth() - 11); n.setDate(1)
    const start = n.toISOString().slice(0, 10)
    listTransactions({ start_date: start, end_date: end, limit: 5000 })
      .then(r => setHistoryTxs(r.data.data.transactions ?? []))
      .catch(() => {})
  }, [])

  const loadMonthTxs = useCallback((y: number, m: number) => {
    const pad = (n: number) => String(n).padStart(2, '0')
    const start = `${y}-${pad(m + 1)}-01`
    const lastDay = new Date(y, m + 1, 0).getDate()
    const end = `${y}-${pad(m + 1)}-${pad(lastDay)}`
    setMonthTxsLoading(true)
    listTransactions({ start_date: start, end_date: end, limit: 1000 })
      .then(r => setMonthTxs(r.data.data.transactions ?? []))
      .catch(() => {})
      .finally(() => setMonthTxsLoading(false))
  }, [])

  useEffect(() => {
    if (chartMode === 'monthly') loadMonthTxs(chartYear, chartMonth)
  }, [chartMode, chartYear, chartMonth, loadMonthTxs])

  const prevChartMonth = () => {
    if (chartMonth === 0) { setChartYear(y => y - 1); setChartMonth(11) }
    else setChartMonth(m => m - 1)
  }
  const nextChartMonth = () => {
    const now = new Date()
    if (chartYear === now.getFullYear() && chartMonth === now.getMonth()) return
    if (chartMonth === 11) { setChartYear(y => y + 1); setChartMonth(0) }
    else setChartMonth(m => m + 1)
  }

  // Compute daily balance per account for selected month
  const monthlyHistory = useMemo(() => {
    if (!items.length) return []
    const pad = (n: number) => String(n).padStart(2, '0')
    const lastDay = new Date(chartYear, chartMonth + 1, 0).getDate()
    const days: string[] = []
    for (let d = 1; d <= lastDay; d++) {
      days.push(`${chartYear}-${pad(chartMonth + 1)}-${pad(d)}`)
    }
    // transactions AFTER this month (for computing balance at start of month)
    const ym = `${chartYear}-${pad(chartMonth + 1)}`
    return days.map(day => {
      const point: Record<string, string | number> = { date: day.slice(8) } // DD
      items.forEach(acc => {
        // net of transactions strictly after this day
        const allTxs = [...historyTxs, ...monthTxs]
        const seen = new Set<string>()
        const deduped = allTxs.filter(t => { if (seen.has(t.id)) return false; seen.add(t.id); return true })
        const netAfter = deduped
          .filter(t => t.date.slice(0, 10) > day)
          .reduce((sum, t) => {
            if (t.account_id === acc.id) {
              if (t.type === 'income') return sum + t.amount
              if (t.type === 'expense') return sum - t.amount
              if (t.type === 'transfer') return sum - t.amount
            }
            if (t.to_account_id === acc.id && t.type === 'transfer') return sum + t.amount
            return sum
          }, 0)
        point[acc.id] = acc.balance - netAfter
      })
      return point
    })
  }, [items, historyTxs, monthTxs, chartYear, chartMonth])

  // Compute end-of-month balance per account for last 12 months
  const balanceHistory = useMemo(() => {
    if (!items.length) return []
    const months: string[] = []
    for (let i = 11; i >= 0; i--) {
      const d = new Date()
      d.setDate(1)
      d.setMonth(d.getMonth() - i)
      months.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`)
    }
    const MONTH_SHORT = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des']
    return months.map(ym => {
      const [y, m] = ym.split('-')
      const label = `${MONTH_SHORT[Number(m) - 1]} ${y.slice(2)}`
      // End of this month as cutoff string
      const endOfMonth = `${ym}-31` // transactions compare by string prefix
      const point: Record<string, string | number> = { date: label }
      items.forEach(acc => {
        const netAfter = historyTxs
          .filter(t => t.date.slice(0, 7) > ym)
          .reduce((sum, t) => {
            if (t.account_id === acc.id) {
              if (t.type === 'income') return sum + t.amount
              if (t.type === 'expense') return sum - t.amount
              if (t.type === 'transfer') return sum - t.amount
            }
            if (t.to_account_id === acc.id && t.type === 'transfer') return sum + t.amount
            return sum
          }, 0)
        point[acc.id] = acc.balance - netAfter
      })
      return point
    })
  }, [items, historyTxs])

  const yTicks = useMemo(() => {
    const data = chartMode === 'monthly' ? monthlyHistory : balanceHistory
    if (!data.length || !items.length) return undefined
    const vals = data.flatMap(p => items.map(acc => Number(p[acc.id] ?? 0)))
    const max = Math.max(...vals, 0)
    const min = Math.min(...vals, 0)
    const step = 300_000
    const result: number[] = []
    for (let v = Math.floor(min / step) * step; v <= Math.ceil(max / step) * step; v += step) {
      result.push(v)
    }
    return result
  }, [chartMode, monthlyHistory, balanceHistory, items])

  const openCreate = () => {
    setEditing(null)
    setForm(emptyForm())
    setOpen(true)
  }
  const openEdit = (a: Account) => {
    setEditing(a)
    setForm({ name: a.name, type: a.type, icon: a.icon, color: a.color })
    setOpen(true)
  }
  const openBalance = (a: Account) => {
    setEditing(a)
    setNewBalance(String(a.balance))
    setBalanceOpen(true)
  }

  const handleSave = async () => {
    try {
      if (editing) {
        await updateAccount(editing.id, form)
        toast.success('Rekening diperbarui')
      } else {
        await createAccount(form)
        toast.success('Rekening ditambahkan')
      }
      setOpen(false)
      load()
    } catch {
      toast.error('Gagal menyimpan rekening')
    }
  }

  const handleSetBalance = async () => {
    if (!editing) return
    try {
      await setBalance(editing.id, Number(newBalance))
      toast.success('Saldo diperbarui')
      setBalanceOpen(false)
      load()
    } catch {
      toast.error('Gagal mengubah saldo')
    }
  }

  const handleDelete = async () => {
    if (!deleteID) return
    try {
      await deleteAccount(deleteID)
      toast.success('Rekening dihapus')
      setDeleteID(null)
      load()
    } catch {
      toast.error('Gagal menghapus rekening')
    }
  }

  return (
    <div>
      <PageHeader
        title="Rekening"
        description="Kelola rekening dan dompet"
        action={
          <Button size="sm" onClick={openCreate}>
            <Plus size={16} className="mr-1" /> Tambah
          </Button>
        }
      />

      {total !== null && (
        <Card className="mb-4">
          <CardContent className="pt-4">
            <p className="text-sm text-muted-foreground">Total Saldo Seluruh Rekening</p>
            <p className="text-2xl font-bold text-green-600">{formatRupiah(total)}</p>
          </CardContent>
        </Card>
      )}

      {/* Balance history chart */}
      {items.length > 0 && (
        <div className="mb-6 rounded-xl border bg-card p-4">
          <div className="flex items-center justify-between mb-3">
            {chartMode === 'monthly' ? (
              <div className="flex items-center gap-2">
                <button onClick={prevChartMonth} className="rounded p-1 hover:bg-accent text-muted-foreground">&#8249;</button>
                <span className="text-sm font-semibold min-w-[90px] text-center">
                  {['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'][chartMonth]} {chartYear}
                </span>
                <button
                  onClick={nextChartMonth}
                  disabled={(() => { const n = new Date(); return chartYear === n.getFullYear() && chartMonth === n.getMonth() })()}
                  className="rounded p-1 hover:bg-accent text-muted-foreground disabled:opacity-30"
                >&#8250;</button>
              </div>
            ) : (
              <p className="text-sm font-semibold">Tren Saldo 12 Bulan Terakhir</p>
            )}
            <div className="flex rounded-lg border overflow-hidden text-xs">
              <button
                onClick={() => setChartMode('12months')}
                className={`px-3 py-1 ${chartMode === '12months' ? 'bg-primary text-primary-foreground' : 'hover:bg-accent'}`}
              >12 Bulan</button>
              <button
                onClick={() => setChartMode('monthly')}
                className={`px-3 py-1 ${chartMode === 'monthly' ? 'bg-primary text-primary-foreground' : 'hover:bg-accent'}`}
              >Bulanan</button>
            </div>
          </div>
          {monthTxsLoading ? (
            <div className="flex h-[220px] items-center justify-center text-sm text-muted-foreground">Memuat...</div>
          ) : (
            <ResponsiveContainer width="100%" height={340}>
              <LineChart
                data={chartMode === 'monthly' ? monthlyHistory : balanceHistory}
                margin={{ top: 4, right: 8, left: 8, bottom: 0 }}
              >
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                <XAxis dataKey="date" tick={{ fontSize: 10, fill: 'var(--foreground)' }} stroke="var(--border)" />
                <YAxis
                  ticks={yTicks}
                  tick={{ fontSize: 10, fill: 'var(--foreground)' }}
                  stroke="var(--border)"
                  tickFormatter={v => {
                    const n = Math.abs(v)
                    if (n >= 1_000_000) return `${(v / 1_000_000).toFixed(1)}jt`
                    if (n >= 1_000) return `${Math.round(v / 1_000)}rb`
                    return String(v)
                  }}
                  width={52}
                />
                <Tooltip
                  formatter={(val: number) =>
                    new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(val)
                  }
                  contentStyle={{ fontSize: 12, background: 'var(--popover)', border: '1px solid var(--border)', borderRadius: 8 }}
                />
                <Legend wrapperStyle={{ fontSize: 11 }} />
                {items.map(acc => (
                  <Line
                    key={acc.id}
                    type="monotone"
                    dataKey={acc.id}
                    name={acc.name}
                    stroke={acc.color ?? '#6366f1'}
                    strokeWidth={2}
                    dot={false}
                    activeDot={{ r: 4 }}
                  />
                ))}
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>
      )}

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Nama</TableHead>
            <TableHead>Tipe</TableHead>
            <TableHead>Saldo</TableHead>
            <TableHead className="text-right">Aksi</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {items.map((a) => (
            <TableRow key={a.id}>
              <TableCell>
                <div className="flex items-center gap-3">
                  <div
                    className="flex h-9 w-9 items-center justify-center rounded-lg text-lg shrink-0"
                    style={{ background: `${a.color}22`, borderLeft: `3px solid ${a.color}` }}
                  >
                    {TYPE_EMOJI[a.type] ?? '💳'}
                  </div>
                  <span className="font-medium">{a.name}</span>
                </div>
              </TableCell>
              <TableCell>
                <Badge variant="outline" style={{ borderColor: a.color, color: a.color }}>
                  {TYPE_LABEL[a.type] ?? a.type}
                </Badge>
              </TableCell>
              <TableCell className={`font-semibold tabular-nums ${a.balance < 0 ? 'text-red-500' : ''}`}>
                {formatRupiah(a.balance)}
              </TableCell>
              <TableCell className="text-right">
                <Button
                  variant="ghost"
                  size="icon"
                  title="Ubah saldo"
                  onClick={() => openBalance(a)}
                >
                  <DollarSign size={14} />
                </Button>
                <Button variant="ghost" size="icon" onClick={() => openEdit(a)}>
                  <Pencil size={14} />
                </Button>
                <Button variant="ghost" size="icon" onClick={() => setDeleteID(a.id)}>
                  <Trash2 size={14} className="text-destructive" />
                </Button>
              </TableCell>
            </TableRow>
          ))}
          {items.length === 0 && (
            <TableRow>
              <TableCell colSpan={4} className="text-center text-muted-foreground">
                Belum ada rekening
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      {/* Create / Edit */}
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Edit Rekening' : 'Tambah Rekening'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div className="space-y-1">
              <Label>Nama</Label>
              <Input
                value={form.name ?? ''}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              />
            </div>
            <div className="space-y-1">
              <Label>Tipe</Label>
              <Select
                value={form.type}
                onValueChange={(v) => setForm((f) => ({ ...f, type: v ?? undefined }))}
              >
                <SelectTrigger>
                  <SelectValue>
                    {ACCOUNT_TYPES.find((t) => t.value === form.type)?.label ?? 'Pilih tipe'}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {ACCOUNT_TYPES.map((t) => (
                    <SelectItem key={t.value} value={t.value}>
                      {t.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label>Icon</Label>
              <IconPicker
                value={form.icon ?? ''}
                onChange={(icon) => setForm((f) => ({ ...f, icon }))}
              />
            </div>
            <div className="space-y-1">
              <Label>Warna</Label>
              <div className="flex gap-2">
                <Input
                  type="color"
                  value={form.color ?? '#6366f1'}
                  onChange={(e) => setForm((f) => ({ ...f, color: e.target.value }))}
                  className="h-9 w-14 p-1"
                />
                <Input
                  value={form.color ?? ''}
                  onChange={(e) => setForm((f) => ({ ...f, color: e.target.value }))}
                />
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Batal
            </Button>
            <Button onClick={handleSave}>Simpan</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Set balance */}
      <Dialog open={balanceOpen} onOpenChange={setBalanceOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Ubah Saldo — {editing?.name}</DialogTitle>
          </DialogHeader>
          <div className="space-y-1">
            <Label>Saldo Baru (Rp)</Label>
            <Input
              type="number"
              value={newBalance}
              onChange={(e) => setNewBalance(e.target.value)}
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setBalanceOpen(false)}>
              Batal
            </Button>
            <Button onClick={handleSetBalance}>Simpan</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={!!deleteID}
        title="Hapus Rekening"
        description="Rekening yang dihapus tidak dapat dikembalikan."
        onConfirm={handleDelete}
        onCancel={() => setDeleteID(null)}
      />
    </div>
  )
}
