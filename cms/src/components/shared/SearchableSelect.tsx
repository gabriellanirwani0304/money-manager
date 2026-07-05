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
  const [highlighted, setHighlighted] = useState(0)
  const ref = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const listRef = useRef<HTMLUListElement>(null)

  const selected = value ? options.find(o => o.value === value) : null

  const filtered = query
    ? options.filter(o => o.label.toLowerCase().includes(query.toLowerCase()))
    : options

  const listOptions: SelectOption[] = [
    ...(allowEmpty && !query ? [{ value: '', label: emptyLabel }] : []),
    ...filtered,
  ]

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

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setHighlighted(h => {
        const next = Math.min(h + 1, listOptions.length - 1)
        listRef.current?.children[next]?.scrollIntoView({ block: 'nearest' })
        return next
      })
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setHighlighted(h => {
        const next = Math.max(h - 1, 0)
        listRef.current?.children[next]?.scrollIntoView({ block: 'nearest' })
        return next
      })
    } else if (e.key === 'Enter') {
      e.preventDefault()
      const opt = listOptions[highlighted]
      if (opt) {
        select(opt.value)
        setTimeout(() => {
          const focusable = Array.from(document.querySelectorAll<HTMLElement>(
            'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
          ))
          const trigger = ref.current?.querySelector<HTMLElement>('button')
          if (!trigger) return
          const idx = focusable.indexOf(trigger)
          focusable[idx + 1]?.focus()
        }, 0)
      }
    } else if (e.key === 'Escape') {
      setOpen(false)
    } else if (e.key === 'Tab') {
      e.preventDefault()
      setOpen(false)
      setTimeout(() => {
        const focusable = Array.from(document.querySelectorAll<HTMLElement>(
          'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
        ))
        const trigger = ref.current?.querySelector<HTMLElement>('button')
        if (!trigger) return
        const idx = focusable.indexOf(trigger)
        const target = e.shiftKey ? focusable[idx - 1] : focusable[idx + 1]
        target?.focus()
      }, 0)
    }
  }

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
              onChange={e => { setQuery(e.target.value); setHighlighted(0) }}
              onKeyDown={handleKeyDown}
              placeholder="Cari..."
              className="flex-1 bg-transparent text-sm outline-none placeholder:text-muted-foreground"
            />
          </div>
          <ul ref={listRef} className="max-h-52 overflow-y-auto py-1">
            {listOptions.length === 0 ? (
              <li className="px-3 py-2 text-sm text-muted-foreground text-center">Tidak ditemukan</li>
            ) : listOptions.map((o, idx) => (
              <li
                key={o.value}
                onClick={() => select(o.value)}
                onMouseEnter={() => setHighlighted(idx)}
                className={`flex cursor-pointer items-center gap-2 px-3 py-2 text-sm ${
                  idx === highlighted ? 'bg-accent text-accent-foreground' : 'hover:bg-accent hover:text-accent-foreground'
                } ${o.value === '' ? 'text-muted-foreground' : ''}`}
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
