import { useState, useEffect, useRef } from 'react'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { CalendarIcon } from 'lucide-react'

function toDisplay(v: string) {
  if (!v) return ''
  const [y, m, d] = v.split('-')
  return `${d}-${m}-${y}`
}

function toISO(v: string) {
  if (!v || v.length < 10) return ''
  const parts = v.split('-')
  if (parts.length !== 3) return ''
  const [d, m, y] = parts
  if (!d || !m || !y || y.length !== 4) return ''
  return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`
}

interface DateInputProps {
  value: string
  onChange: (v: string) => void
  className?: string
}

export default function DateInput({ value, onChange, className }: DateInputProps) {
  const [raw, setRaw] = useState(toDisplay(value))
  const nativeRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    setRaw(toDisplay(value))
  }, [value])

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    let v = e.target.value.replace(/[^\d]/g, '')
    if (v.length > 2) v = v.slice(0, 2) + '-' + v.slice(2)
    if (v.length > 5) v = v.slice(0, 5) + '-' + v.slice(5)
    if (v.length > 10) v = v.slice(0, 10)
    setRaw(v)
    const iso = toISO(v)
    if (iso) onChange(iso)
  }

  const handleBlur = () => {
    const iso = toISO(raw)
    if (iso) setRaw(toDisplay(iso))
    else if (!raw) setRaw('')
  }

  const handleNativeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const iso = e.target.value
    if (iso) {
      onChange(iso)
      setRaw(toDisplay(iso))
    }
  }

  return (
    <div className={`relative flex items-center ${className ?? ''}`}>
      <Input
        value={raw}
        onChange={handleChange}
        onBlur={handleBlur}
        placeholder="dd-mm-yyyy"
        maxLength={10}
        className="pr-9"
      />
      <Button
        type="button"
        variant="ghost"
        size="icon"
        className="absolute right-0 h-full px-2 text-muted-foreground hover:text-foreground"
        onClick={() => nativeRef.current?.showPicker()}
      >
        <CalendarIcon size={15} />
      </Button>
      <input
        ref={nativeRef}
        type="date"
        value={value}
        onChange={handleNativeChange}
        className="sr-only"
        tabIndex={-1}
      />
    </div>
  )
}
