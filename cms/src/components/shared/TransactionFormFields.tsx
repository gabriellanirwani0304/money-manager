import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import DateInput from '@/components/shared/DateInput'
import { CategoryCombobox } from '@/components/shared/CategoryCombobox'
import { SearchableSelect } from '@/components/shared/SearchableSelect'
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
          <CategoryCombobox
            value={value.category_id}
            onChange={(id) => set({ category_id: id })}
            categories={filteredCats}
            placeholder="Pilih kategori"
          />
        </div>
      )}

      {/* Account */}
      <div className="space-y-1">
        <Label>{isTransfer ? 'Dari Rekening' : 'Rekening (opsional)'}</Label>
        <SearchableSelect
          value={value.account_id}
          onChange={(v) => set({ account_id: v })}
          options={accounts.map(a => ({ value: a.id, label: a.name }))}
          placeholder={isTransfer ? 'Pilih rekening asal' : '— Tidak ada —'}
          allowEmpty={!isTransfer}
          emptyLabel="— Tidak ada —"
        />
      </div>

      {/* To Account */}
      {isTransfer && (
        <div className="space-y-1">
          <Label>Ke Rekening</Label>
          <SearchableSelect
            value={value.to_account_id}
            onChange={(v) => set({ to_account_id: v })}
            options={accounts.filter(a => a.id !== value.account_id).map(a => ({ value: a.id, label: a.name }))}
            placeholder="Pilih rekening tujuan"
          />
        </div>
      )}

      {/* Amount */}
      <div className="space-y-1">
        <Label>Jumlah (Rp)</Label>
        <Input
          type="text"
          inputMode="numeric"
          value={value.amount === 0 ? '' : String(value.amount)}
          onChange={(e) => {
            const raw = e.target.value.replace(/\D/g, '')
            set({ amount: raw === '' ? 0 : Number(raw) })
          }}
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
