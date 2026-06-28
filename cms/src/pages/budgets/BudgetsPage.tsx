import { useEffect, useState } from 'react'
import { listBudgets, createBudget, updateBudget, deleteBudget, type Budget } from '@/api/budgets'
import { listCategories, type Category } from '@/api/categories'
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
import { Plus, Pencil, Trash2, Copy } from 'lucide-react'
import { toast } from 'sonner'

const formatRupiah = (n: number) =>
  new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(n)

const statusVariant: Record<string, 'default' | 'secondary' | 'outline' | 'destructive'> = {
  safe: 'default',
  warning: 'secondary',
  danger: 'outline',
  exceeded: 'destructive',
}
const statusLabel: Record<string, string> = {
  safe: 'Aman',
  warning: 'Peringatan',
  danger: 'Bahaya',
  exceeded: 'Melebihi',
}
const monthNames = [
  'Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des',
]

export default function BudgetsPage() {
  const now = new Date()
  const [month, setMonth] = useState(now.getMonth() + 1)
  const [year, setYear] = useState(now.getFullYear())

  const [items, setItems] = useState<Budget[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Budget | null>(null)
  const [form, setForm] = useState<Partial<Budget>>({})
  const [deleteID, setDeleteID] = useState<string | null>(null)

  const load = () =>
    listBudgets(month, year)
      .then((r) => setItems(r.data.data ?? []))
      .catch(() => {})

  useEffect(() => {
    load()
  }, [month, year])

  useEffect(() => {
    listCategories({ limit: 200, type: 'expense' })
      .then((r) => setCategories(r.data.data.categories ?? []))
      .catch(() => {})
  }, [])

  const openCreate = () => {
    setEditing(null)
    setForm({ category_id: '', amount: 0, month, year })
    setOpen(true)
  }
  const openEdit = (b: Budget) => {
    setEditing(b)
    setForm({ category_id: b.category_id, amount: b.budget_amount ?? b.amount, month: b.month, year: b.year })
    setOpen(true)
  }

  const handleSave = async () => {
    try {
      if (editing) {
        await updateBudget(editing.id, form)
        toast.success('Anggaran diperbarui')
      } else {
        await createBudget(form)
        toast.success('Anggaran ditambahkan')
      }
      setOpen(false)
      load()
    } catch {
      toast.error('Gagal menyimpan anggaran')
    }
  }

  const [copying, setCopying] = useState(false)
  const copyFromPrevMonth = async () => {
    const prevMonth = month > 1 ? month - 1 : 12
    const prevYear = month > 1 ? year : year - 1
    setCopying(true)
    try {
      const [prevRes, curRes] = await Promise.all([
        listBudgets(prevMonth, prevYear),
        listBudgets(month, year),
      ])
      const prevBudgets = prevRes.data.data ?? []
      const curCatIDs = new Set((curRes.data.data ?? []).map((b) => b.category_id))
      const toCreate = prevBudgets.filter((b) => !curCatIDs.has(b.category_id))
      if (toCreate.length === 0) {
        toast.info('Semua kategori dari bulan lalu sudah ada di bulan ini')
        return
      }
      await Promise.all(
        toCreate.map((b) =>
          createBudget({ category_id: b.category_id, amount: b.budget_amount ?? b.amount, month, year })
        )
      )
      toast.success(`${toCreate.length} anggaran disalin dari ${monthNames[prevMonth - 1]} ${prevYear}`)
      load()
    } catch {
      toast.error('Gagal menyalin anggaran')
    } finally {
      setCopying(false)
    }
  }

  const handleDelete = async () => {
    if (!deleteID) return
    try {
      await deleteBudget(deleteID)
      toast.success('Anggaran dihapus')
      setDeleteID(null)
      load()
    } catch {
      toast.error('Gagal menghapus anggaran')
    }
  }

  const years = [now.getFullYear() - 1, now.getFullYear(), now.getFullYear() + 1]

  return (
    <div>
      <PageHeader
        title="Anggaran"
        description="Kelola anggaran bulanan"
        action={
          <div className="flex gap-2">
            <Button size="sm" variant="outline" onClick={copyFromPrevMonth} disabled={copying}>
              <Copy size={14} className="mr-1" />
              {copying ? 'Menyalin...' : 'Salin Bulan Lalu'}
            </Button>
            <Button size="sm" onClick={openCreate}>
              <Plus size={16} className="mr-1" /> Tambah
            </Button>
          </div>
        }
      />

      <div className="mb-4 flex gap-2">
        <Select value={String(month)} onValueChange={(v) => setMonth(Number(v ?? month))}>
          <SelectTrigger className="w-32">
            <SelectValue>{monthNames[month - 1]}</SelectValue>
          </SelectTrigger>
          <SelectContent>
            {monthNames.map((m, i) => (
              <SelectItem key={i + 1} value={String(i + 1)}>
                {m}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select value={String(year)} onValueChange={(v) => setYear(Number(v ?? year))}>
          <SelectTrigger className="w-28">
            <SelectValue>{year}</SelectValue>
          </SelectTrigger>
          <SelectContent>
            {years.map((y) => (
              <SelectItem key={y} value={String(y)}>
                {y}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Kategori</TableHead>
            <TableHead>Anggaran</TableHead>
            <TableHead>Terpakai</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="text-right">Aksi</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {items.map((b) => (
            <TableRow key={b.id}>
              <TableCell className="font-medium">
                {b.category?.icon} {b.category?.name ?? b.category_id}
              </TableCell>
              <TableCell>{formatRupiah(b.budget_amount ?? b.amount)}</TableCell>
              <TableCell>{b.spent != null ? formatRupiah(b.spent) : '-'}</TableCell>
              <TableCell>
                {b.status && (
                  <Badge variant={statusVariant[b.status]}>{statusLabel[b.status]}</Badge>
                )}
              </TableCell>
              <TableCell className="text-right">
                <Button variant="ghost" size="icon" onClick={() => openEdit(b)}>
                  <Pencil size={14} />
                </Button>
                <Button variant="ghost" size="icon" onClick={() => setDeleteID(b.id)}>
                  <Trash2 size={14} className="text-destructive" />
                </Button>
              </TableCell>
            </TableRow>
          ))}
          {items.length === 0 && (
            <TableRow>
              <TableCell colSpan={5} className="text-center text-muted-foreground">
                Belum ada anggaran untuk periode ini
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Edit Anggaran' : 'Tambah Anggaran'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div className="space-y-1">
              <Label>Kategori</Label>
              <Select
                value={form.category_id}
                onValueChange={(v) => setForm((f) => ({ ...f, category_id: v ?? undefined }))}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Pilih kategori" />
                </SelectTrigger>
                <SelectContent>
                  {categories.map((c) => (
                    <SelectItem key={c.id} value={c.id}>
                      {c.icon} {c.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label>Jumlah (Rp)</Label>
              <Input
                type="number"
                value={form.amount ?? ''}
                onChange={(e) => setForm((f) => ({ ...f, amount: Number(e.target.value) }))}
              />
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

      <ConfirmDialog
        open={!!deleteID}
        title="Hapus Anggaran"
        description="Anggaran yang dihapus tidak dapat dikembalikan."
        onConfirm={handleDelete}
        onCancel={() => setDeleteID(null)}
      />
    </div>
  )
}
