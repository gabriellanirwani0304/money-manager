import { cn } from '@/lib/utils'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

export const EMOJI_OPTIONS = [
  '🍔','🍜','🍕','🍱','☕','🛒','🏠','🚗','🚌','✈️',
  '💊','🏥','🎬','🎮','🎵','📚','🎓','💼','💻','📱',
  '💳','💰','💸','📈','🏦','⭐','🎁','💡','🔧','🧾',
  '📄','📦','🛍️','👗','⚡','💧','🌐','🏋️','🐾','🌿',
  '🎨','✂️','🧹','🚀','🔑','🎯','🏆','❤️','🌟','➕',
]

export interface CategoryFormValue {
  name: string
  type: 'income' | 'expense'
  icon: string
}

interface Props {
  value: CategoryFormValue
  onChange: (v: CategoryFormValue) => void
  /** When set, hides the type selector and locks to this type */
  lockType?: 'income' | 'expense'
}

export default function CategoryForm({ value, onChange, lockType }: Props) {
  const set = (patch: Partial<CategoryFormValue>) => onChange({ ...value, ...patch })

  return (
    <div className="space-y-3">
      <div className="space-y-1">
        <Label>Nama</Label>
        <Input
          autoFocus
          value={value.name}
          onChange={(e) => set({ name: e.target.value })}
          placeholder="Nama kategori"
        />
      </div>

      {lockType ? (
        <p className="text-xs text-muted-foreground">
          Tipe: <span className="font-medium">{lockType === 'income' ? 'Pemasukan' : 'Pengeluaran'}</span>
        </p>
      ) : (
        <div className="space-y-1">
          <Label>Tipe</Label>
          <Select
            value={value.type}
            onValueChange={(v) => set({ type: (v ?? 'expense') as 'income' | 'expense' })}
          >
            <SelectTrigger>
              <SelectValue>{value.type === 'income' ? 'Pemasukan' : 'Pengeluaran'}</SelectValue>
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="income">Pemasukan</SelectItem>
              <SelectItem value="expense">Pengeluaran</SelectItem>
            </SelectContent>
          </Select>
        </div>
      )}

      <div className="space-y-1">
        <Label>Icon</Label>
        <div className="flex items-center gap-2 mb-2">
          <span className="flex h-9 w-9 items-center justify-center rounded-lg border text-xl">
            {value.icon || '?'}
          </span>
          <span className="text-sm text-muted-foreground">
            {value.icon ? 'Terpilih' : 'Belum dipilih'}
          </span>
        </div>
        <div className="grid grid-cols-10 gap-1 rounded-lg border p-2 max-h-32 overflow-y-auto">
          {EMOJI_OPTIONS.map((emoji) => (
            <button
              key={emoji}
              type="button"
              onClick={() => set({ icon: emoji })}
              className={cn(
                'flex h-8 w-8 items-center justify-center rounded text-lg hover:bg-accent',
                value.icon === emoji && 'bg-primary/20 ring-1 ring-primary'
              )}
            >
              {emoji}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
