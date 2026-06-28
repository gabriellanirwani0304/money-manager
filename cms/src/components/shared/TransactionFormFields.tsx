import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import DateInput from '@/components/shared/DateInput'
import { PlusCircle } from 'lucide-react'
import type { Category } from '@/api/categories'
import type { Account } from '@/api/accounts'

export interface TxFormData {
  type: 'income' | 'expense' | 'transfer'
  date: string
  category_id: string
  account_id: string
  to_account_id: string
  amount: number
  description: string
}

export const defaultTxForm = (): TxFormData => ({
  type: 'expense',
  date: new Date().toISOString().slice(0, 10),
  category_id: '',
  account_id: '',
  to_account_id: '',
  amount: 0,
  description: '',
})

interface Props {
  value: TxFormData
  onChange: (v: TxFormData) => void
  categories: Category[]
  accounts: Account[]
  onQuickCat?: (type: 'income' | 'expense') => void
}

export function TransactionFormFields({ value, onChange, categories, accounts, onQuickCat }: Props) {
  const set = (patch: Partial<TxFormData>) => {
    const next = { ...value, ...patch }
    if (patch.type && patch.type !== value.type) {
      next.category_id = ''
      next.to_account_id = ''
    }
    onChange(next)
  }

  const isTransfer = value.type === 'transfer'
  const filteredCats = categories.filter((c) => c.type === value.type)

  return (
    <div className="space-y-3">
      {/* Type */}
      <div className="space-y-1">
        <Label>Tipe</Label>
        <Select value={value.type} onValueChange={(v) => set({ type: v as TxFormData['type'] })}>
          <SelectTrigger>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="expense">Pengeluaran</SelectItem>
            <SelectItem value="income">Pemasukan</SelectItem>
            <SelectItem value="transfer">Transfer</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {/* Date */}
      <div className="space-y-1">
        <Label>Tanggal</Label>
        <DateInput value={value.date} onChange={(v) => set({ date: v })} />
      </div>

      {/* Category */}
      {!isTransfer && (
        <div className="space-y-1">
          <div className="flex items-center justify-between">
            <Label>Kategori</Label>
            {onQuickCat && (
              <button
                type="button"
                onClick={() => onQuickCat(value.type as 'income' | 'expense')}
                className="flex items-center gap-1 text-xs text-primary hover:underline"
              >
                <PlusCircle size={12} /> Buat baru
              </button>
            )}
          </div>
          <Select value={value.category_id} onValueChange={(v) => set({ category_id: v ?? '' })}>
            <SelectTrigger>
              <SelectValue placeholder="Pilih kategori">
                {filteredCats.find((c) => c.id === value.category_id)
                  ? `${filteredCats.find((c) => c.id === value.category_id)?.icon} ${filteredCats.find((c) => c.id === value.category_id)?.name}`
                  : undefined}
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              {filteredCats.map((c) => (
                <SelectItem key={c.id} value={c.id}>{c.icon} {c.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      )}

      {/* Account */}
      <div className="space-y-1">
        <Label>{isTransfer ? 'Dari Rekening' : 'Rekening (opsional)'}</Label>
        <Select value={value.account_id} onValueChange={(v) => set({ account_id: v ?? '' })}>
          <SelectTrigger>
            <SelectValue>
              {accounts.find((a) => a.id === value.account_id)?.name
                ?? (isTransfer ? 'Pilih rekening asal' : '— Tidak ada —')}
            </SelectValue>
          </SelectTrigger>
          <SelectContent>
            {!isTransfer && <SelectItem value="">— Tidak ada —</SelectItem>}
            {accounts.map((a) => (
              <SelectItem key={a.id} value={a.id}>{a.name}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* To Account */}
      {isTransfer && (
        <div className="space-y-1">
          <Label>Ke Rekening</Label>
          <Select value={value.to_account_id} onValueChange={(v) => set({ to_account_id: v ?? '' })}>
            <SelectTrigger>
              <SelectValue>
                {accounts.find((a) => a.id === value.to_account_id)?.name ?? 'Pilih rekening tujuan'}
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              {accounts.filter((a) => a.id !== value.account_id).map((a) => (
                <SelectItem key={a.id} value={a.id}>{a.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      )}

      {/* Amount */}
      <div className="space-y-1">
        <Label>Jumlah (Rp)</Label>
        <Input
          type="number"
          value={value.amount || ''}
          onChange={(e) => set({ amount: Number(e.target.value) })}
          placeholder="0"
        />
      </div>

      {/* Description */}
      <div className="space-y-1">
        <Label>Catatan</Label>
        <Input
          value={value.description}
          onChange={(e) => set({ description: e.target.value })}
          placeholder="Opsional"
        />
      </div>
    </div>
  )
}
