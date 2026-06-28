import { describe, it, expect, vi, beforeEach } from 'vitest'
import { screen, waitFor } from '@testing-library/react'
import { render } from '@/test/utils'
import DashboardPage from './DashboardPage'

vi.mock('@/api/reports', () => ({
  getDashboard: vi.fn(),
  getCategoryBreakdown: vi.fn(),
  getMonthlyTrend: vi.fn(),
}))

vi.mock('@/api/accounts', () => ({
  listAccounts: vi.fn(),
}))

import * as reportsApi from '@/api/reports'
import * as accountsApi from '@/api/accounts'

const mockDashboard = {
  income: 10_000_000,
  expense: 3_500_000,
  balance: 6_500_000,
  recent_transactions: [],
  budget_alerts: [],
  top_expenses: [],
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(reportsApi.getDashboard).mockResolvedValue({
    data: { data: mockDashboard },
  } as never)
  vi.mocked(reportsApi.getCategoryBreakdown).mockResolvedValue({
    data: { data: [] },
  } as never)
  vi.mocked(reportsApi.getMonthlyTrend).mockResolvedValue({
    data: { data: [] },
  } as never)
  vi.mocked(accountsApi.listAccounts).mockResolvedValue({
    data: { data: [{ id: 'a1', name: 'BCA', balance: 5_000_000 }, { id: 'a2', name: 'GoPay', balance: 500_000 }] },
  } as never)
})

describe('DashboardPage', () => {
  it('renders page title', () => {
    render(<DashboardPage />)
    expect(screen.getByText('Dashboard')).toBeInTheDocument()
  })

  it('shows skeleton while loading', () => {
    vi.mocked(reportsApi.getDashboard).mockReturnValueOnce(new Promise(() => {}) as never)
    render(<DashboardPage />)
    const skeletons = document.querySelectorAll('[data-slot="skeleton"]')
    expect(skeletons.length).toBeGreaterThan(0)
  })

  it('renders income card after data loads', async () => {
    render(<DashboardPage />)
    await waitFor(() => {
      expect(screen.getByText(/rp\s*10\.000\.000/i)).toBeInTheDocument()
    })
  })

  it('renders total saldo from accounts', async () => {
    render(<DashboardPage />)
    await waitFor(() => {
      expect(screen.getByText(/rp\s*5\.500\.000/i)).toBeInTheDocument()
    })
  })

  it('renders net bersih', async () => {
    render(<DashboardPage />)
    await waitFor(() => {
      expect(screen.getByText(/rp\s*6\.500\.000/i)).toBeInTheDocument()
    })
  })

  it('handles API error gracefully without crashing', async () => {
    vi.mocked(reportsApi.getDashboard).mockRejectedValueOnce(new Error('network'))
    render(<DashboardPage />)
    await waitFor(() => {
      expect(screen.getByText('Dashboard')).toBeInTheDocument()
    })
  })
})
