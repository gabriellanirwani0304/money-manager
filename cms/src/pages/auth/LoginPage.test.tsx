import { describe, it, expect, vi, beforeEach } from 'vitest'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { render } from '@/test/utils'
import LoginPage from './LoginPage'

vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  logout: vi.fn(),
}))

vi.mock('react-router-dom', async (importOriginal) => {
  const actual = await importOriginal<typeof import('react-router-dom')>()
  return {
    ...actual,
    Navigate: ({ to }: { to: string }) => <div data-testid="navigate" data-to={to} />,
    useNavigate: () => vi.fn(),
  }
})

import * as authApi from '@/api/auth'

beforeEach(() => {
  localStorage.clear()
  vi.clearAllMocks()
})

describe('LoginPage', () => {
  it('renders email and password fields', () => {
    render(<LoginPage />)
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument()
  })

  it('renders the submit button', () => {
    render(<LoginPage />)
    expect(screen.getByRole('button', { name: /masuk/i })).toBeInTheDocument()
  })

  it('shows loading state during login', async () => {
    let resolve!: (v: unknown) => void
    vi.mocked(authApi.login).mockReturnValueOnce(
      new Promise((r) => { resolve = r }) as never,
    )

    const user = userEvent.setup()
    render(<LoginPage />)
    await user.type(screen.getByLabelText(/email/i), 'demo@example.com')
    await user.type(screen.getByLabelText(/password/i), 'password123')
    await user.click(screen.getByRole('button', { name: /masuk/i }))

    expect(screen.getByRole('button', { name: /memuat/i })).toBeDisabled()
    resolve({ data: { data: { access_token: 'a', refresh_token: 'r' } } })
  })

  it('shows error message on failed login', async () => {
    vi.mocked(authApi.login).mockRejectedValueOnce({
      response: { data: { message: 'Email atau password salah' } },
    })

    const user = userEvent.setup()
    render(<LoginPage />)
    await user.type(screen.getByLabelText(/email/i), 'wrong@example.com')
    await user.type(screen.getByLabelText(/password/i), 'wrongpass')
    await user.click(screen.getByRole('button', { name: /masuk/i }))

    await waitFor(() => {
      expect(screen.getByText(/email atau password salah/i)).toBeInTheDocument()
    })
  })

  it('redirects to home when already logged in', () => {
    localStorage.setItem('access_token', 'existing-token')
    render(<LoginPage />)
    expect(screen.getByTestId('navigate')).toHaveAttribute('data-to', '/')
  })
})
