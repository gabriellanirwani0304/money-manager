import { useEffect, useState, useMemo } from 'react'
import {
  listTransactions,
  createTransaction,
  updateTransaction,
  deleteTransaction,
  exportCSV,
  type Transaction,
  type ListFilter,
} from '@/api/transactions'
import { listCategories, createCategory, type Category } from '@/api/categories'
import { listAccounts, type Account } from '@/api/accounts'
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
import ConfirmDialog from '@/components/shared/ConfirmDialog'
import PageHeader from '@/components/shared/PageHeader'
import { TransactionFormFields, defaultTxForm, type TxFormData } from '@/components/shared/TransactionFormFields'
import { CategoryCombobox } from '@/components/shared/CategoryCombobox'
import { SearchableSelect } from '@/components/shared/SearchableSelect'
import { Plus, Pencil, Trash2, Download, Upload, PlusCircle, ArrowLeftRight, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight, ArrowUpDown, ArrowUp, ArrowDown } from 'lucide-react'
import ImportDialog from './ImportDialog'
import BulkTransactionDialog from './BulkTransactionDialog'
import DateInput from '@/components/shared/DateInput'
import CategoryForm, { type CategoryFormValue } from '@/components/shared/CategoryForm'
import { toast } from 'sonner'

const formatRupiah = (n: number) =>
  new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(n)

const emptyForm = (): TxFormData => defaultTxForm()

const TYPE_LABELS: Record<string, string> = {
  income: 'Pemasukan',
  expense: 'Pengeluaran',
  transfer: 'Transfer',
}

type SortKey = 'date' | 'amount' | 'type' | 'account'
type SortDir = 'asc' | 'desc'

interface SortableHeadProps {
  label: string
  field: SortKey
  sortBy: SortKey
  sortDir: SortDir
  onSort: (f: SortKey) => void
  className?: string
}

function SortableHead({ label, field, sortBy, sortDir, onSort, className }: SortableHeadProps) {
  const active = sortBy === field
  return (
    <TableHead
      className={`cursor-pointer select-none hover:text-foreground ${className ?? ''}`}
      onClick={() => onSort(field)}
    >
      <span className="inline-flex items-center gap-1">
        {label}
        {active
          ? sortDir === 'asc' ? <ArrowUp size={12} /> : <ArrowDown size={12} />
          : <ArrowUpDown size={12} className="opacity-30" />}
      </span>
    </TableHead>
  )
}

function buildPageList(current: number, total: number): (number | '...')[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1)
  const pages: (number | '...')[] = []
  const addPage = (p: number) => { if (!pages.includes(p)) pages.push(p) }
  addPage(1)
  if (current > 3) pages.push('...')
  for (let p = Math.max(2, current - 1); p <= Math.min(total - 1, current + 1); p++) addPage(p)
  if (current < total - 2) pages.push('...')
  addPage(total)
  return pages
}

export default function TransactionsPage() {
  const [items, setItems] = useState<Transaction[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const limit = 15

  const [categories, setCategories] = useState<Category[]>([])
  const [accounts, setAccounts] = useState<Account[]>([])

  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Transaction | null>(null)
  const [form, setForm] = useState<TxFormData>(emptyForm())
  const [deleteID, setDeleteID] = useState<string | null>(null)

  const [exportStart, setExportStart] = useState('')
  const [exportEnd, setExportEnd] = useState('')
  const [exportOpen, setExportOpen] = useState(false)
  const [importOpen, setImportOpen] = useState(false)
  const [bulkOpen, setBulkOpen] = useState(false)

  const [quickCatOpen, setQuickCatOpen] = useState(false)
  const [quickCatForm, setQuickCatForm] = useState<CategoryFormValue>({ name: '', type: 'expense', icon: '' })

  const [bulkDates, setBulkDates] = useState<string[]>([])
  const [bulkMode, setBulkMode] = useState(false)

  const [filterType, setFilterType] = useState<string>('')
  const [filterCategory, setFilterCategory] = useState<string>('')
  const [filterAccount, setFilterAccount] = useState<string>('')

  const today = () => {
    const n = new Date()
    return `${n.getFullYear()}-${String(n.getMonth() + 1).padStart(2, '0')}-${String(n.getDate()).padStart(2, '0')}`
  }
  const thisMonthStart = () => {
    const n = new Date()
    return `${n.getFullYear()}-${String(n.getMonth() + 1).padStart(2, '0')}-01`
  }
  const thisMonthEnd = () => {
    const n = new Date()
    const last = new Date(n.getFullYear(), n.getMonth() + 1, 0).getDate()
    return `${n.getFullYear()}-${String(n.getMonth() + 1).padStart(2, '0')}-${String(last).padStart(2, '0')}`
  }

  const [filterStart, setFilterStart] = useState<string>(thisMonthStart)
  const [filterEnd, setFilterEnd] = useState<string>(today)
  const [filterWeek, setFilterWeek] = useState<string>('')

  const weekOptions = useMemo(() => {
    const d = filterStart ? new Date(filterStart + 'T00:00:00') : new Date()
    const y = d.getFullYear()
    const m = d.getMonth()
    const lastDay = new Date(y, m + 1, 0).getDate()
    const pad = (n: number) => String(n).padStart(2, '0')
    const weeks: { label: string; start: string; end: string }[] = []
    for (let s = 1; s <= lastDay; s += 7) {
      const e = Math.min(s + 6, lastDay)
      weeks.push({
        label: `Minggu ${weeks.length + 1} (${s}–${e})`,
        start: `${y}-${pad(m + 1)}-${pad(s)}`,
        end: `${y}-${pad(m + 1)}-${pad(e)}`,
      })
    }
    return weeks
  }, [filterStart])

  const [sortBy, setSortBy] = useState<SortKey>('date')
  const [sortDir, setSortDir] = useState<SortDir>('desc')

  const [jumpInput, setJumpInput] = useState('')

  const buildFilter = (p: number): ListFilter => ({
    page: p,
    limit,
    ...(filterType ? { type: filterType } : {}),
    ...(filterCategory ? { category_id: filterCategory } : {}),
    ...(filterAccount ? { account_id: filterAccount } : {}),
    ...(filterStart ? { start_date: filterStart } : {}),
    ...(filterEnd ? { end_date: filterEnd } : {}),
  })

  const load = (f?: ListFilter) =>
    listTransactions(f ?? buildFilter(page))
      .then((r) => {
        setItems(r.data.data.transactions ?? [])
        setTotal(r.data.data.pagination?.total ?? 0)
      })
      .catch(() => {})

  const applyFilter = (p = 1) => {
    setPage(p)
    load(buildFilter(p))
  }

  const resetFilter = () => {
    setFilterType('')
    setFilterCategory('')
    setFilterAccount('')
    setFilterWeek('')
    const start = thisMonthStart()
    const end = today()
    setFilterStart(start)
    setFilterEnd(end)
    setPage(1)
    listTransactions({ page: 1, limit, start_date: start, end_date: end })
      .then((r) => {
        setItems(r.data.data.transactions ?? [])
        setTotal(r.data.data.pagination?.total ?? 0)
      })
      .catch(() => {})
  }

  const selectWeek = (idx: string) => {
    setFilterWeek(idx)
    const w = idx ? weekOptions[Number(idx) - 1] : null
    const start = w ? w.start : thisMonthStart()
    const end = w ? w.end : thisMonthEnd()
    setFilterStart(start)
    setFilterEnd(end)
    setPage(1)
    load({
      page: 1, limit,
      start_date: start,
      end_date: end,
      ...(filterType ? { type: filterType } : {}),
      ...(filterCategory ? { category_id: filterCategory } : {}),
      ...(filterAccount ? { account_id: filterAccount } : {}),
    })
  }

  useEffect(() => { load(buildFilter(page)) }, [page])

  useEffect(() => {
    listCategories({ limit: 200 }).then((r) => setCategories(r.data.data.categories ?? [])).catch(() => {})
    listAccounts().then((r) => setAccounts(r.data.data ?? [])).catch(() => {})
    load()
  }, [])

  const handleSort = (field: SortKey) => {
    if (sortBy === field) setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    else { setSortBy(field); setSortDir('asc') }
  }

  const sortedItems = useMemo(() => {
    return [...items].sort((a, b) => {
      let cmp = 0
      if (sortBy === 'date') cmp = a.date.localeCompare(b.date)
      else if (sortBy === 'amount') cmp = a.amount - b.amount
      else if (sortBy === 'type') cmp = a.type.localeCompare(b.type)
      else if (sortBy === 'account') {
        const nameA = a.account?.name ?? ''
        const nameB = b.account?.name ?? ''
        cmp = nameA.localeCompare(nameB)
      }
      return sortDir === 'asc' ? cmp : -cmp
    })
  }, [items, sortBy, sortDir])

  const openCreate = () => {
    setEditing(null)
    setForm(emptyForm())
    setBulkMode(false)
    setBulkDates([new Date().toISOString().slice(0, 10)])
    setOpen(true)
  }
  const openEdit = (t: Transaction) => {
    setEditing(t)
    setBulkMode(false)
    setForm({
      type: t.type,
      date: t.date,
      category_id: t.category_id ?? '',
      account_id: t.account_id ?? '',
      to_account_id: t.to_account_id ?? '',
      amount: t.amount,
      description: t.description ?? '',
    })
    setOpen(true)
  }

  const toPayload = (f: TxFormData, date?: string) => ({
    type: f.type,
    date: date ?? f.date,
    category_id: f.category_id || undefined,
    account_id: f.account_id || undefined,
    to_account_id: f.to_account_id || undefined,
    amount: f.amount,
    description: f.description,
  })

  const handleSave = async () => {
    try {
      if (editing) {
        await updateTransaction(editing.id, toPayload(form))
        toast.success('Transaksi diperbarui')
      } else if (bulkMode) {
        const validDates = bulkDates.filter(Boolean)
        if (validDates.length === 0) { toast.error('Masukkan minimal satu tanggal'); return }
        await Promise.all(validDates.map((date) => createTransaction(toPayload(form, date))))
        toast.success(`${validDates.length} transaksi ditambahkan`)
      } else {
        await createTransaction(toPayload(form))
        toast.success('Transaksi ditambahkan')
      }
      setOpen(false)
      load(buildFilter(page))
      listAccounts().then((r) => setAccounts(r.data.data ?? [])).catch(() => {})
    } catch {
      toast.error('Gagal menyimpan transaksi')
    }
  }

  const handleDelete = async () => {
    if (!deleteID) return
    try {
      await deleteTransaction(deleteID)
      toast.success('Transaksi dihapus')
      setDeleteID(null)
      load(buildFilter(page))
      listAccounts().then((r) => setAccounts(r.data.data ?? [])).catch(() => {})
    } catch {
      toast.error('Gagal menghapus transaksi')
    }
  }

  const handleQuickCat = async () => {
    if (!quickCatForm.name.trim()) return
    try {
      const res = await createCategory({
        name: quickCatForm.name.trim(),
        icon: quickCatForm.icon,
        type: quickCatForm.type,
      })
      const newCat = res.data.data
      const updated = await listCategories({ limit: 200 })
      setCategories(updated.data.data.categories ?? [])
      setForm((f) => ({ ...f, category_id: newCat.id }))
      setQuickCatOpen(false)
      setQuickCatForm({ name: '', icon: '' })
      toast.success(`Kategori "${newCat.name}" ditambahkan`)
    } catch {
      toast.error('Gagal membuat kategori')
    }
  }

  const handleExport = async () => {
    try {
      const res = await exportCSV(exportStart, exportEnd)
      const url = URL.createObjectURL(res.data as Blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `transaksi-${exportStart}-${exportEnd}.csv`
      a.click()
      URL.revokeObjectURL(url)
      setExportOpen(false)
      toast.success('CSV berhasil diunduh')
    } catch {
      toast.error('Gagal mengekspor CSV')
    }
  }

  const handleJump = () => {
    const p = Number(jumpInput)
    if (!p || p < 1 || p > totalPages) return
    setJumpInput('')
    setPage(p)
  }

  const goPage = (p: number) => {
    if (p < 1 || p > totalPages) return
    setPage(p)
  }

  const totalPages = Math.ceil(total / limit)

  const txAccountLabel = (t: Transaction) => {
    if (t.type === 'transfer') {
      return `${t.account?.name ?? '?'} → ${t.to_account?.name ?? '?'}`
    }
    return t.account?.name ?? '—'
  }

  const txCategoryLabel = (t: Transaction) => {
    if (t.type === 'transfer') return null
    return `${t.category?.icon ?? ''} ${t.category?.name ?? '—'}`.trim()
  }

  return (
    <div>
      <PageHeader
        title="Transaksi"
        description="Kelola pemasukan, pengeluaran, dan transfer antar rekening"
        action={
          <div className="flex gap-2">
            <Button size="sm" variant="outline" onClick={() => setBulkOpen(true)}>
              <PlusCircle size={16} className="mr-1" /> Input Massal
            </Button>
            <Button size="sm" variant="outline" onClick={() => setImportOpen(true)}>
              <Upload size={16} className="mr-1" /> Import CSV
            </Button>
            <Button size="sm" variant="outline" onClick={() => setExportOpen(true)}>
              <Download size={16} className="mr-1" /> Ekspor CSV
            </Button>
            <Button size="sm" onClick={openCreate}>
              <Plus size={16} className="mr-1" /> Tambah
            </Button>
          </div>
        }
      />

      {/* Balance bar */}
      {accounts.length > 0 && (() => {
        const typeEmoji: Record<string, string> = {
          bank: '🏦', cash: '💵', ewallet: '📱', investment: '📈', other: '💳',
        }
        const totalBalance = accounts.reduce((s, a) => s + a.balance, 0)
        return (
          <div className="mb-5 flex gap-3 overflow-x-auto pb-1" style={{ scrollbarWidth: 'none' }}>
            {accounts.map((a, idx) => {
              const active = filterAccount === a.id
              const pos = a.balance >= 0
              const chartVar = `var(--chart-${(idx % 5) + 1})`
              const emoji = typeEmoji[a.type] ?? '💳'
              return (
                <button
                  key={a.id}
                  onClick={() => {
                    const next = active ? '' : a.id
                    setFilterAccount(next)
                    setPage(1)
                    load({
                      page: 1, limit,
                      ...(filterType ? { type: filterType } : {}),
                      ...(filterCategory ? { category_id: filterCategory } : {}),
                      ...(next ? { account_id: next } : {}),
                      ...(filterStart ? { start_date: filterStart } : {}),
                      ...(filterEnd ? { end_date: filterEnd } : {}),
                    })
                  }}
                  className={`group relative flex-none flex items-center gap-3 rounded-2xl border px-4 py-3 text-left transition-all min-w-[180px]
                    ${active
                      ? 'border-primary/60 shadow-md bg-primary/5'
                      : 'border-border bg-card hover:border-primary/30 hover:shadow-sm'}`}
                >
                  {/* colored left bar */}
                  <div className="absolute left-0 top-3 bottom-3 w-1 rounded-r-full" style={{ backgroundColor: active ? 'var(--primary)' : chartVar }} />
                  <div
                    className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-lg"
                    style={{ background: `color-mix(in oklch, ${chartVar} 18%, transparent)` }}
                  >
                    {emoji}
                  </div>
                  <div className="min-w-0">
                    <p className="text-xs text-muted-foreground truncate">{a.name}</p>
                    <p className={`text-sm font-bold tabular-nums mt-0.5 ${pos ? 'text-foreground' : 'text-red-500'}`}>
                      {formatRupiah(a.balance)}
                    </p>
                  </div>
                  {active && (
                    <div className="absolute top-1.5 right-1.5 h-1.5 w-1.5 rounded-full bg-primary" />
                  )}
                </button>
              )
            })}

            {/* Total */}
            <div className="relative flex-none flex items-center gap-3 rounded-2xl border border-dashed border-border/60 bg-muted/30 px-4 py-3 min-w-[180px]">
              <div className="absolute left-0 top-3 bottom-3 w-1 rounded-r-full bg-muted-foreground/20" />
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-muted text-lg">
                💰
              </div>
              <div>
                <p className="text-xs text-muted-foreground">Total Saldo</p>
                <p className={`text-sm font-bold tabular-nums mt-0.5 ${totalBalance >= 0 ? 'text-foreground' : 'text-red-500'}`}>
                  {formatRupiah(totalBalance)}
                </p>
              </div>
            </div>
          </div>
        )
      })()}

      {/* Filter bar */}
      <div className="mb-4 flex flex-wrap items-center gap-2">
        <Select value={filterType} onValueChange={(v) => setFilterType(v ?? '')}>
          <SelectTrigger className="w-36">
            <SelectValue>{TYPE_LABELS[filterType] ?? 'Semua Tipe'}</SelectValue>
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="">Semua Tipe</SelectItem>
            <SelectItem value="income">Pemasukan</SelectItem>
            <SelectItem value="expense">Pengeluaran</SelectItem>
            <SelectItem value="transfer">Transfer</SelectItem>
          </SelectContent>
        </Select>

        <div className="w-48">
          <CategoryCombobox
            value={filterCategory}
            onChange={setFilterCategory}
            categories={
              filterType === 'income' || filterType === 'expense'
                ? categories.filter(c => c.type === filterType)
                : categories
            }
            allowEmpty
            emptyLabel="Semua Kategori"
            placeholder="Semua Kategori"
          />
        </div>

        <div className="w-44">
          <SearchableSelect
            value={filterAccount}
            onChange={setFilterAccount}
            options={accounts.map(a => ({ value: a.id, label: a.name }))}
            allowEmpty
            emptyLabel="Semua Rekening"
            placeholder="Semua Rekening"
          />
        </div>

        <DateInput value={filterStart} onChange={v => { setFilterStart(v); setFilterWeek('') }} className="w-36" />
        <span className="text-xs text-muted-foreground">s/d</span>
        <DateInput value={filterEnd} onChange={v => { setFilterEnd(v); setFilterWeek('') }} className="w-36" />

        <Select value={filterWeek} onValueChange={selectWeek}>
          <SelectTrigger className="w-44">
            <SelectValue>{filterWeek ? weekOptions[Number(filterWeek) - 1]?.label : 'Semua Minggu'}</SelectValue>
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="">Semua Minggu</SelectItem>
            {weekOptions.map((w, i) => (
              <SelectItem key={i} value={String(i + 1)}>{w.label}</SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Button size="sm" onClick={() => applyFilter(1)}>Terapkan</Button>
        {(filterType || filterCategory || filterAccount || filterWeek) && (
          <Button size="sm" variant="ghost" onClick={resetFilter}>Reset</Button>
        )}
      </div>

      <Table>
        <TableHeader>
          <TableRow>
            <SortableHead label="Tanggal" field="date" sortBy={sortBy} sortDir={sortDir} onSort={handleSort} />
            <TableHead>Kategori</TableHead>
            <SortableHead label="Rekening" field="account" sortBy={sortBy} sortDir={sortDir} onSort={handleSort} />
            <SortableHead label="Tipe" field="type" sortBy={sortBy} sortDir={sortDir} onSort={handleSort} />
            <SortableHead label="Jumlah" field="amount" sortBy={sortBy} sortDir={sortDir} onSort={handleSort} className="text-right" />
            <TableHead>Catatan</TableHead>
            <TableHead className="text-right">Aksi</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {sortedItems.map((t) => (
            <TableRow key={t.id}>
              <TableCell className="whitespace-nowrap">{t.date}</TableCell>
              <TableCell>
                {t.type === 'transfer'
                  ? <span className="inline-flex items-center gap-1 text-blue-500"><ArrowLeftRight size={13} /> Transfer</span>
                  : txCategoryLabel(t)}
              </TableCell>
              <TableCell className="text-sm">
                {t.type === 'transfer'
                  ? <span className="text-muted-foreground">{txAccountLabel(t)}</span>
                  : t.account?.name ?? <span className="text-muted-foreground/50">—</span>}
              </TableCell>
              <TableCell>
                <Badge
                  variant={t.type === 'income' ? 'default' : t.type === 'transfer' ? 'outline' : 'secondary'}
                >
                  {TYPE_LABELS[t.type]}
                </Badge>
              </TableCell>
              <TableCell className={`text-right tabular-nums ${
                t.type === 'income' ? 'text-green-600' :
                t.type === 'transfer' ? 'text-blue-600' :
                'text-red-600'
              }`}>
                {t.type === 'transfer' ? '' : t.type === 'income' ? '+' : '-'}{formatRupiah(t.amount)}
              </TableCell>
              <TableCell className="max-w-[160px] truncate text-muted-foreground text-sm">{t.description || '—'}</TableCell>
              <TableCell className="text-right">
                <Button variant="ghost" size="icon" onClick={() => openEdit(t)}>
                  <Pencil size={14} />
                </Button>
                <Button variant="ghost" size="icon" onClick={() => setDeleteID(t.id)}>
                  <Trash2 size={14} className="text-destructive" />
                </Button>
              </TableCell>
            </TableRow>
          ))}
          {items.length === 0 && (
            <TableRow>
              <TableCell colSpan={7} className="text-center text-muted-foreground py-8">
                Belum ada transaksi
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-between gap-2 flex-wrap">
          <p className="text-sm text-muted-foreground">
            {total} transaksi · halaman {page} dari {totalPages}
          </p>
          <div className="flex items-center gap-1 flex-wrap">
            <Button size="icon" variant="outline" className="h-8 w-8" disabled={page <= 1} onClick={() => goPage(1)}>
              <ChevronsLeft size={14} />
            </Button>
            <Button size="icon" variant="outline" className="h-8 w-8" disabled={page <= 1} onClick={() => goPage(page - 1)}>
              <ChevronLeft size={14} />
            </Button>
            {buildPageList(page, totalPages).map((p, i) =>
              p === '...'
                ? <span key={`el-${i}`} className="px-1 text-muted-foreground text-sm">…</span>
                : <Button
                    key={p}
                    size="sm"
                    variant={p === page ? 'default' : 'outline'}
                    className="h-8 w-8 p-0 text-xs"
                    onClick={() => goPage(p as number)}
                  >{p}</Button>
            )}
            <Button size="icon" variant="outline" className="h-8 w-8" disabled={page >= totalPages} onClick={() => goPage(page + 1)}>
              <ChevronRight size={14} />
            </Button>
            <Button size="icon" variant="outline" className="h-8 w-8" disabled={page >= totalPages} onClick={() => goPage(totalPages)}>
              <ChevronsRight size={14} />
            </Button>
            <div className="flex items-center gap-1 ml-2">
              <span className="text-xs text-muted-foreground">Ke halaman</span>
              <Input
                className="h-8 w-14 text-xs text-center"
                value={jumpInput}
                onChange={e => setJumpInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleJump()}
                placeholder="#"
              />
              <Button size="sm" variant="outline" className="h-8 px-2 text-xs" onClick={handleJump}>Go</Button>
            </div>
          </div>
        </div>
      )}

      {/* Create / Edit */}
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Edit Transaksi' : 'Tambah Transaksi'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            {/* Multi-date toggle (create only) */}
            {!editing && (
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => { setBulkMode(false); setForm((f) => ({ ...f, date: new Date().toISOString().slice(0, 10) })) }}
                  className={`text-xs px-2 py-1 rounded-md border transition-colors ${!bulkMode ? 'bg-primary text-primary-foreground border-primary' : 'text-muted-foreground hover:text-foreground'}`}
                >Satu tanggal</button>
                <button
                  type="button"
                  onClick={() => { setBulkMode(true); setBulkDates([new Date().toISOString().slice(0, 10), '']) }}
                  className={`text-xs px-2 py-1 rounded-md border transition-colors ${bulkMode ? 'bg-primary text-primary-foreground border-primary' : 'text-muted-foreground hover:text-foreground'}`}
                >Beberapa tanggal</button>
              </div>
            )}

            {/* Multi-date picker */}
            {bulkMode && !editing && (
              <div className="space-y-1">
                <Label>Tanggal ({bulkDates.filter(Boolean).length} dipilih)</Label>
                <div className="space-y-2">
                  {bulkDates.map((d, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <DateInput
                        value={d}
                        onChange={(v) => setBulkDates((prev) => prev.map((x, j) => j === i ? v : x))}
                        className="flex-1"
                      />
                      {bulkDates.length > 1 && (
                        <button type="button" onClick={() => setBulkDates((prev) => prev.filter((_, j) => j !== i))}
                          className="text-destructive hover:text-destructive/80 text-sm px-1">✕</button>
                      )}
                    </div>
                  ))}
                  <button type="button" onClick={() => setBulkDates((prev) => [...prev, ''])}
                    className="text-xs text-primary hover:underline flex items-center gap-1">
                    <Plus size={12} /> Tambah tanggal
                  </button>
                </div>
              </div>
            )}

            <TransactionFormFields
              value={form}
              onChange={setForm}
              categories={categories}
              accounts={accounts}
              hideDate={bulkMode && !editing}
              onQuickCat={(type) => {
                setQuickCatForm({ name: '', type, icon: '' })
                setQuickCatOpen(true)
              }}
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Batal</Button>
            <Button onClick={handleSave}>
              {bulkMode && !editing ? `Simpan ${bulkDates.filter(Boolean).length} Transaksi` : 'Simpan'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Export */}
      <Dialog open={exportOpen} onOpenChange={setExportOpen}>
        <DialogContent>
          <DialogHeader><DialogTitle>Ekspor CSV</DialogTitle></DialogHeader>
          <div className="space-y-3">
            <div className="space-y-1">
              <Label>Tanggal Mulai</Label>
              <DateInput value={exportStart} onChange={setExportStart} />
            </div>
            <div className="space-y-1">
              <Label>Tanggal Akhir</Label>
              <DateInput value={exportEnd} onChange={setExportEnd} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setExportOpen(false)}>Batal</Button>
            <Button onClick={handleExport}>Unduh</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={!!deleteID}
        title="Hapus Transaksi"
        description="Transaksi yang dihapus tidak dapat dikembalikan."
        onConfirm={handleDelete}
        onCancel={() => setDeleteID(null)}
      />

      <ImportDialog
        open={importOpen}
        onClose={() => setImportOpen(false)}
        categories={categories}
        accounts={accounts}
        onImported={() => {
          load(buildFilter(page))
          listAccounts().then(r => setAccounts(r.data.data ?? [])).catch(() => {})
        }}
      />

      <BulkTransactionDialog
        open={bulkOpen}
        onClose={() => setBulkOpen(false)}
        categories={categories}
        accounts={accounts}
        onImported={() => {
          load(buildFilter(page))
          listAccounts().then(r => setAccounts(r.data.data ?? [])).catch(() => {})
        }}
      />

      <Dialog open={quickCatOpen} onOpenChange={setQuickCatOpen}>
        <DialogContent className="max-w-sm">
          <DialogHeader><DialogTitle>Buat Kategori Baru</DialogTitle></DialogHeader>
          <CategoryForm
            value={quickCatForm}
            onChange={setQuickCatForm}
            lockType={form.type === 'income' ? 'income' : 'expense'}
          />
          <DialogFooter>
            <Button variant="outline" onClick={() => setQuickCatOpen(false)}>Batal</Button>
            <Button onClick={handleQuickCat} disabled={!quickCatForm.name.trim()}>Buat & Pilih</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
