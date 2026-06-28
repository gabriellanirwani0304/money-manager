import { describe, it, expect } from 'vitest'
import { render, screen } from '@/test/utils'
import PageHeader from './PageHeader'

describe('PageHeader', () => {
  it('renders title', () => {
    render(<PageHeader title="Transaksi" />)
    expect(screen.getByText('Transaksi')).toBeInTheDocument()
  })

  it('renders description when provided', () => {
    render(<PageHeader title="T" description="Sub text" />)
    expect(screen.getByText('Sub text')).toBeInTheDocument()
  })

  it('renders action slot', () => {
    render(<PageHeader title="T" action={<button>Tambah</button>} />)
    expect(screen.getByRole('button', { name: 'Tambah' })).toBeInTheDocument()
  })

  it('does not render description when omitted', () => {
    const { container } = render(<PageHeader title="T" />)
    expect(container.querySelector('p')).toBeNull()
  })
})
