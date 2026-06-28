import { describe, it, expect, vi, beforeEach } from 'vitest'
import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { render } from '@/test/utils'
import CategoriesPage from './CategoriesPage'

vi.mock('@/api/categories', () => ({
  listCategories: vi.fn(),
  createCategory: vi.fn(),
  updateCategory: vi.fn(),
  deleteCategory: vi.fn(),
}))

vi.mock('sonner', () => ({ toast: { success: vi.fn(), error: vi.fn() } }))

import * as catApi from '@/api/categories'
import { toast } from 'sonner'

const mockCategories = [
  {
    id: 'c1',
    user_id: 'u1',
    name: 'Makanan',
    type: 'expense' as const,
    icon: '🍔',
    is_default: false,
  },
  {
    id: 'c2',
    user_id: 'u1',
    name: 'Gaji',
    type: 'income' as const,
    icon: '💼',
    is_default: false,
  },
]

const mockListResponse = (cats: typeof mockCategories) => ({
  data: {
    data: {
      categories: cats,
      pagination: { page: 1, limit: 10, total: cats.length, total_pages: 1 },
    },
  },
})

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(catApi.listCategories).mockResolvedValue(mockListResponse(mockCategories) as never)
  vi.mocked(catApi.createCategory).mockResolvedValue({
    data: { data: mockCategories[0] },
  } as never)
  vi.mocked(catApi.updateCategory).mockResolvedValue({
    data: { data: mockCategories[0] },
  } as never)
  vi.mocked(catApi.deleteCategory).mockResolvedValue({} as never)
})

describe('CategoriesPage', () => {
  it('renders categories from API', async () => {
    render(<CategoriesPage />)
    await waitFor(() => {
      expect(screen.getByText('Makanan')).toBeInTheDocument()
      expect(screen.getByText('Gaji')).toBeInTheDocument()
    })
  })

  it('shows "Belum ada kategori" when list is empty', async () => {
    vi.mocked(catApi.listCategories).mockResolvedValueOnce(mockListResponse([]) as never)
    render(<CategoriesPage />)
    await waitFor(() => {
      expect(screen.getByText(/belum ada kategori/i)).toBeInTheDocument()
    })
  })

  it('opens create dialog on Tambah click', async () => {
    const user = userEvent.setup()
    render(<CategoriesPage />)
    await waitFor(() => screen.getByText('Makanan'))
    await user.click(screen.getByRole('button', { name: /tambah/i }))
    expect(screen.getByText('Tambah Kategori')).toBeInTheDocument()
  })

  it('creates a category and calls the API', async () => {
    const user = userEvent.setup()
    render(<CategoriesPage />)
    await waitFor(() => screen.getByText('Makanan'))

    await user.click(screen.getByRole('button', { name: /tambah/i }))

    // Dialog should be open
    const dialog = screen.getByText('Tambah Kategori').closest('[role="dialog"]')
      ?? document.querySelector('[data-slot="dialog-content"]')
      ?? document.body

    const nameInput = within(dialog as HTMLElement).getAllByRole('textbox')[0]
    await user.clear(nameInput)
    await user.type(nameInput, 'Kesehatan')

    await user.click(screen.getByRole('button', { name: /simpan/i }))

    await waitFor(() => {
      expect(catApi.createCategory).toHaveBeenCalledWith(
        expect.objectContaining({ name: 'Kesehatan' }),
      )
      expect(toast.success).toHaveBeenCalledWith('Kategori ditambahkan')
    })
  })

  it('opens edit dialog on Pencil click', async () => {
    const user = userEvent.setup()
    render(<CategoriesPage />)
    await waitFor(() => screen.getByText('Makanan'))

    const iconButtons = screen.getAllByRole('button', { name: '' })
    const pencilBtn = iconButtons[0]
    await user.click(pencilBtn)

    await waitFor(() => {
      expect(screen.getByText('Edit Kategori')).toBeInTheDocument()
    })
  })

  it('calls deleteCategory after confirm', async () => {
    const user = userEvent.setup()
    render(<CategoriesPage />)
    await waitFor(() => screen.getByText('Makanan'))

    // Each row has 2 icon buttons (pencil, trash) — trash is index 1 for first row
    const iconButtons = screen.getAllByRole('button', { name: '' })
    await user.click(iconButtons[1])

    await waitFor(() => {
      expect(screen.getByText('Hapus Kategori')).toBeInTheDocument()
    })

    await user.click(screen.getByRole('button', { name: /hapus/i }))

    await waitFor(() => {
      expect(catApi.deleteCategory).toHaveBeenCalledWith('c1')
      expect(toast.success).toHaveBeenCalledWith('Kategori dihapus')
    })
  })
})
