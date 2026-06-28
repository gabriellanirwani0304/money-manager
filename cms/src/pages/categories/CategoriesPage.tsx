import { useEffect, useState } from 'react'
import {
  listCategories,
  createCategory,
  updateCategory,
  deleteCategory,
  type Category,
} from '@/api/categories'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
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
import CategoryForm, { type CategoryFormValue } from '@/components/shared/CategoryForm'
import PageHeader from '@/components/shared/PageHeader'
import { Plus, Pencil, Trash2, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight, Search } from 'lucide-react'
import { toast } from 'sonner'

const PAGE_SIZE = 10

const emptyForm = (): CategoryFormValue => ({ name: '', type: 'expense', icon: '' })

function buildPageList(current: number, total: number): (number | '...')[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1)
  const pages: (number | '...')[] = []
  const add = (p: number) => { if (!pages.includes(p)) pages.push(p) }
  add(1)
  if (current > 3) pages.push('...')
  for (let p = Math.max(2, current - 1); p <= Math.min(total - 1, current + 1); p++) add(p)
  if (current < total - 2) pages.push('...')
  add(total)
  return pages
}

export default function CategoriesPage() {
  const [items, setItems] = useState<Category[]>([])
  const [total, setTotal] = useState(0)
  const [open, setOpen] = useState(false)
  const [editing, setEditing] = useState<Category | null>(null)
  const [form, setForm] = useState<CategoryFormValue>(emptyForm())
  const [deleteID, setDeleteID] = useState<string | null>(null)

  const [filterType, setFilterType] = useState<string>('')
  const [search, setSearch] = useState<string>('')
  const [page, setPage] = useState(1)
  const [jumpInput, setJumpInput] = useState('')

  const load = (p = page, type = filterType, q = search) =>
    listCategories({ page: p, limit: PAGE_SIZE, type, search: q })
      .then(r => {
        setItems(r.data.data.categories ?? [])
        setTotal(r.data.data.pagination?.total ?? 0)
      })
      .catch(() => {})

  useEffect(() => { load() }, [])

  useEffect(() => { load(page) }, [page])

  const applyFilters = (type: string, q: string) => {
    setPage(1)
    load(1, type, q)
  }

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  const goPage = (p: number) => {
    if (p < 1 || p > totalPages) return
    setPage(p)
  }

  const handleJump = () => {
    const p = Number(jumpInput)
    if (!p || p < 1 || p > totalPages) return
    setJumpInput('')
    setPage(p)
  }

  const openCreate = () => {
    setEditing(null)
    setForm(emptyForm())
    setOpen(true)
  }
  const openEdit = (c: Category) => {
    setEditing(c)
    setForm({ name: c.name, type: c.type, icon: c.icon })
    setOpen(true)
  }

  const handleSave = async () => {
    try {
      if (editing) {
        await updateCategory(editing.id, form)
        toast.success('Kategori diperbarui')
      } else {
        await createCategory(form)
        toast.success('Kategori ditambahkan')
      }
      setOpen(false)
      load(page)
    } catch {
      toast.error('Gagal menyimpan kategori')
    }
  }

  const handleDelete = async () => {
    if (!deleteID) return
    try {
      await deleteCategory(deleteID)
      toast.success('Kategori dihapus')
      setDeleteID(null)
      load(page)
    } catch {
      toast.error('Gagal menghapus kategori')
    }
  }

  return (
    <div>
      <PageHeader
        title="Kategori"
        description="Kelola kategori pemasukan dan pengeluaran"
        action={
          <Button size="sm" onClick={openCreate}>
            <Plus size={16} className="mr-1" /> Tambah
          </Button>
        }
      />

      {/* Filter bar */}
      <div className="mb-4 flex items-center gap-2">
        <div className="relative">
          <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <Input
            className="w-48 pl-8 h-9"
            placeholder="Cari nama..."
            value={search}
            onChange={e => {
              const q = e.target.value
              setSearch(q)
              applyFilters(filterType, q)
            }}
          />
        </div>
        <Select value={filterType} onValueChange={v => {
          const t = v ?? ''
          setFilterType(t)
          applyFilters(t, search)
        }}>
          <SelectTrigger className="w-36 h-9">
            <SelectValue>
              {filterType === 'income' ? 'Pemasukan' : filterType === 'expense' ? 'Pengeluaran' : 'Semua Tipe'}
            </SelectValue>
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="">Semua Tipe</SelectItem>
            <SelectItem value="income">Pemasukan</SelectItem>
            <SelectItem value="expense">Pengeluaran</SelectItem>
          </SelectContent>
        </Select>
        {(filterType || search) && (
          <Button size="sm" variant="ghost" onClick={() => {
            setFilterType('')
            setSearch('')
            applyFilters('', '')
          }}>
            Reset
          </Button>
        )}
        <span className="ml-auto text-xs text-muted-foreground">{total} kategori</span>
      </div>

      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Nama</TableHead>
            <TableHead>Tipe</TableHead>
            <TableHead>Icon</TableHead>
            <TableHead className="text-right">Aksi</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {items.map((c) => (
            <TableRow key={c.id}>
              <TableCell className="font-medium">{c.name}</TableCell>
              <TableCell>
                <Badge variant={c.type === 'income' ? 'default' : 'secondary'}>
                  {c.type === 'income' ? 'Pemasukan' : 'Pengeluaran'}
                </Badge>
              </TableCell>
              <TableCell>{c.icon ?? '-'}</TableCell>
              <TableCell className="text-right">
                <Button variant="ghost" size="icon" onClick={() => openEdit(c)} disabled={c.is_default}>
                  <Pencil size={14} />
                </Button>
                <Button variant="ghost" size="icon" onClick={() => setDeleteID(c.id)} disabled={c.is_default}>
                  <Trash2 size={14} className="text-destructive" />
                </Button>
              </TableCell>
            </TableRow>
          ))}
          {items.length === 0 && (
            <TableRow>
              <TableCell colSpan={4} className="text-center text-muted-foreground py-8">
                {total === 0 && (filterType || search) ? 'Tidak ada hasil' : 'Belum ada kategori'}
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-between gap-2">
          <p className="text-sm text-muted-foreground">
            {total} kategori · halaman {page} dari {totalPages}
          </p>
          <div className="flex items-center gap-1">
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
              <span className="text-xs text-muted-foreground">Ke</span>
              <Input
                className="h-8 w-12 text-xs text-center"
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

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editing ? 'Edit Kategori' : 'Tambah Kategori'}</DialogTitle>
          </DialogHeader>
          <CategoryForm value={form} onChange={setForm} />
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Batal</Button>
            <Button onClick={handleSave}>Simpan</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={!!deleteID}
        title="Hapus Kategori"
        description="Kategori yang dihapus tidak dapat dikembalikan."
        onConfirm={handleDelete}
        onCancel={() => setDeleteID(null)}
      />
    </div>
  )
}
