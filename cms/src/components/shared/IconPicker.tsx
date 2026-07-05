import { useState, useMemo } from 'react'
import { Search } from 'lucide-react'
import { Input } from '@/components/ui/input'
import { cn } from '@/lib/utils'

export interface IconGroup {
  label: string
  icons: string[]
}

const RAW_GROUPS: IconGroup[] = [
  {
    label: 'Makanan & Minuman',
    icons: ['🍔','🍜','🍕','🍱','☕','🍣','🍦','🥗','🥤','🍺','🥩','🍰','🍎','🥦','🧃','🫖','🍫','🍿','🍞','🍳','🥚','🧆','🥘','🫕','🍛','🥟','🍙','🧋','🍷','🥐'],
  },
  {
    label: 'Belanja & Fashion',
    icons: ['🛒','🛍️','👗','👠','💄','👟','🧢','👜','💎','🏷️','🪭','🧣','🧤','👒','🕶️','⌚','💍','🥿','🧥','👔'],
  },
  {
    label: 'Rumah & Tangga',
    icons: ['🏠','🛋️','🪴','🧹','🔧','🔑','📦','🏡','🛁','🪟','🪑','🛏️','🧺','🚿','🧴','🪣','🔨','💡','🕯️','🧻'],
  },
  {
    label: 'Transportasi',
    icons: ['🚗','🚌','✈️','🚢','🚲','🛵','🚕','🚃','⛽','🚁','🛺','🚐','🚑','🚓','🏍️','⛵','🚂','🛻','🅿️','🛤️'],
  },
  {
    label: 'Kesehatan & Olahraga',
    icons: ['💊','🏥','🏋️','🧘','🩺','🦷','🩹','💉','🧬','🫀','🏃','🚴','⚽','🏀','🎾','🏊','🥊','🧗','🏇','🎿'],
  },
  {
    label: 'Hiburan & Hobi',
    icons: ['🎬','🎮','🎵','🎭','🎪','🎲','📸','🎤','🎸','🎯','🎨','🎻','🎹','🎳','🎡','🎢','🎠','🎟️','🃏','🕹️'],
  },
  {
    label: 'Pendidikan & Karier',
    icons: ['📚','🎓','💼','💻','📱','🖥️','📝','✏️','🔬','🏫','📡','🖊️','📐','📏','🗂️','📋','🗒️','📓','📕','🔭'],
  },
  {
    label: 'Keuangan',
    icons: ['💰','💸','📈','📊','🪙','🧾','💹','🤑','📄','🏧','💵','📉','🤝','⚖️','🏦','💳','💴','💶','💷','🔐'],
  },
  {
    label: 'Keluarga & Sosial',
    icons: ['❤️','👶','🎁','🎉','🎂','🌹','🐾','🐕','🐈','🌱','☀️','🌈','🎀','🙏','👪','💝','🌸','🦋','🎊','🌻'],
  },
  {
    label: 'Utilitas & Lainnya',
    icons: ['⚡','💧','🌐','🔥','❄️','🌬️','♻️','🔔','📢','🛡️','⚙️','🔩','🧲','🔋','📺','📻','☎️','🖨️','🪫','🔌'],
  },
]

// Deduplicate across groups — keep first occurrence
const seen = new Set<string>()
export const ICON_GROUPS: IconGroup[] = RAW_GROUPS.map(g => ({
  label: g.label,
  icons: g.icons.filter(icon => {
    if (seen.has(icon)) return false
    seen.add(icon)
    return true
  }),
})).filter(g => g.icons.length > 0)

export const ALL_ICONS = ICON_GROUPS.flatMap(g => g.icons)

interface Props {
  value: string
  onChange: (icon: string) => void
}

export default function IconPicker({ value, onChange }: Props) {
  const [query, setQuery] = useState('')

  const results = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return null
    return ICON_GROUPS
      .filter(g => g.label.toLowerCase().includes(q))
      .flatMap(g => g.icons)
  }, [query])

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2">
        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border text-xl">
          {value || '?'}
        </span>
        <div className="relative flex-1">
          <Search size={13} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
          <Input
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Cari icon... (makan, transport, hobi...)"
            className="pl-7 h-9 text-sm"
          />
        </div>
      </div>

      {results === null ? (
        <p className="text-xs text-muted-foreground px-1">
          Ketik untuk mencari, atau tempel emoji langsung di kolom cari
        </p>
      ) : results.length === 0 ? (
        <p className="py-3 text-center text-sm text-muted-foreground rounded-lg border">
          Tidak ditemukan
        </p>
      ) : (
        <div className="rounded-lg border p-2 max-h-48 overflow-y-auto">
          <div className="grid grid-cols-10 gap-0.5">
            {results.map(icon => (
              <IconBtn key={icon} icon={icon} selected={value === icon} onClick={() => onChange(icon)} />
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function IconBtn({ icon, selected, onClick }: { icon: string; selected: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'flex h-8 w-8 items-center justify-center rounded text-lg hover:bg-accent transition-colors',
        selected && 'bg-primary/20 ring-1 ring-primary'
      )}
    >
      {icon}
    </button>
  )
}
