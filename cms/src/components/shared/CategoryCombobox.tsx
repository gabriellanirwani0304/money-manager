import { SearchableSelect } from '@/components/shared/SearchableSelect'
import type { Category } from '@/api/categories'

interface Props {
  value: string
  onChange: (id: string) => void
  categories: Category[]
  placeholder?: string
  disabled?: boolean
  allowEmpty?: boolean
  emptyLabel?: string
}

export function CategoryCombobox({ value, onChange, categories, placeholder = 'Pilih kategori', disabled, allowEmpty, emptyLabel = 'Semua Kategori' }: Props) {
  const options = categories.map(c => ({
    value: c.id,
    label: c.name,
    icon: c.icon ?? undefined,
  }))

  return (
    <SearchableSelect
      value={value}
      onChange={onChange}
      options={options}
      placeholder={placeholder}
      disabled={disabled}
      allowEmpty={allowEmpty}
      emptyLabel={emptyLabel}
    />
  )
}
