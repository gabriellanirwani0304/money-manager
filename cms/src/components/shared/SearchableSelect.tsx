import { useEffect, useRef, useState } from 'react'
import { Check, ChevronDown, Search } from 'lucide-react'

export interface SelectOption {
  value: string
  label: string
  icon?: string
  sublabel?: string
}

interface Props {
  value: string
  onChange: (value: string) => void
  options: SelectOption[]
  placeholder?: string
  disabled?: boolean
  className?: string
  /** Adds a leading "all" option (value='') */
  allowEmpty?: boolean
  emptyLabel?: string
}

export function SearchableSelect({
  value, onChange, options, placeholder = 'Pilih...', disabled,
  className = '', allowEmpty, emptyLabel = 'Semua',
}: Props) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState('')
  const ref = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  const selected = value ? options.find(o => o.value === value) : null

  const filtered = query
    ? options.filter(o => o.label.toLowerCase().includes(query.toLowerCase()))
    : options

  useEffect(() => {
    if (!open) { setQuery(''); return }
    setTimeout(() => inputRef.current?.focus(), 50)
  }, [open])

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  const select = (v: string) => { onChange(v); setOpen(false); setQuery('') }

  const triggerLabel = selected
    ? `${selected.icon ? selected.icon + ' ' : ''}${selected.label}`
    : (allowEmpty && value === '') ? emptyLabel : placeholder

  return (
    <div ref={ref} className={`relative ${className}`}>
      <button
        type="button"
        disabled={disabled}
        onClick={() => setOpen(v => !v)}
        className="flex h-9 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
      >
        <span className={selected || (allowEmpty && value === '') ? 'text-foreground' : 'text-muted-foreground'}>
          {triggerLabel}
        </span>
        <ChevronDown size={14} className="text-muted-foreground shrink-0 ml-2" />
      </button>

      {open && (
        <div className="absolute z-50 mt-1 w-full min-w-[180px] rounded-md border bg-popover shadow-md">
          <div className="flex items-center gap-2 border-b px-3 py-2">
            <Search size={13} className="text-muted-foreground shrink-0" />
            <input
              ref={inputRef}
              value={query}
              onChange={e => setQuery(e.target.value)}
              placeholder="Cari..."
              className="flex-1 bg-transparent text-sm outline-none placeholder:text-muted-foreground"
            />
          </div>
          <ul className="max-h-52 overflow-y-auto py-1">
            {allowEmpty && !query && (
              <li
                onClick={() => select('')}
                className="flex cursor-pointer items-center gap-2 px-3 py-2 text-sm hover:bg-accent hover:text-accent-foreground text-muted-foreground"
              >
                <span className="w-4 shrink-0">{value === '' && <Check size={13} className="text-primary" />}</span>
                <span>{emptyLabel}</span>
              </li>
            )}
            {filtered.length === 0 ? (
              <li className="px-3 py-2 text-sm text-muted-foreground text-center">Tidak ditemukan</li>
            ) : filtered.map(o => (
              <li
                key={o.value}
                onClick={() => select(o.value)}
                className="flex cursor-pointer items-center gap-2 px-3 py-2 text-sm hover:bg-accent hover:text-accent-foreground"
              >
                <span className="w-4 shrink-0">{o.value === value && <Check size={13} className="text-primary" />}</span>
                {o.icon && <span>{o.icon}</span>}
                <span className="flex-1">{o.label}</span>
                {o.sublabel && <span className="text-xs text-muted-foreground">{o.sublabel}</span>}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}
