import { describe, it, expect, beforeEach, vi } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { useAuth } from './useAuth'

vi.mock('@/api/auth', () => ({
  login: vi.fn(),
  logout: vi.fn(),
}))

import * as authApi from '@/api/auth'

beforeEach(() => {
  localStorage.clear()
  vi.clearAllMocks()
})

describe('useAuth', () => {
  describe('isLoggedIn', () => {
    it('returns false when no token in localStorage', () => {
      const { result } = renderHook(() => useAuth())
      expect(result.current.isLoggedIn()).toBe(false)
    })

    it('returns true when access_token exists', () => {
      localStorage.setItem('access_token', 'tok')
      const { result } = renderHook(() => useAuth())
      expect(result.current.isLoggedIn()).toBe(true)
    })
  })

  describe('login', () => {
    it('saves tokens and returns true on success', async () => {
      vi.mocked(authApi.login).mockResolvedValueOnce({
        data: { data: { access_token: 'acc', refresh_token: 'ref' } },
      } as never)

      const { result } = renderHook(() => useAuth())
      let ok: boolean
      await act(async () => {
        ok = await result.current.login('user@example.com', 'password')
      })
      expect(ok!).toBe(true)
      expect(localStorage.getItem('access_token')).toBe('acc')
      expect(localStorage.getItem('refresh_token')).toBe('ref')
    })

    it('sets error and returns false on API failure', async () => {
      vi.mocked(authApi.login).mockRejectedValueOnce({
        response: { data: { message: 'Invalid credentials' } },
      })

      const { result } = renderHook(() => useAuth())
      let ok: boolean
      await act(async () => {
        ok = await result.current.login('x@x.com', 'wrong')
      })
      expect(ok!).toBe(false)
      expect(result.current.error).toBe('Invalid credentials')
      expect(localStorage.getItem('access_token')).toBeNull()
    })

    it('uses fallback error message when response has no message', async () => {
      vi.mocked(authApi.login).mockRejectedValueOnce(new Error('network'))

      const { result } = renderHook(() => useAuth())
      await act(async () => {
        await result.current.login('x@x.com', 'pw')
      })
      expect(result.current.error).toBe('Login gagal')
    })

    it('sets loading true during request then false after', async () => {
      let resolveFn!: (v: unknown) => void
      vi.mocked(authApi.login).mockReturnValueOnce(
        new Promise((res) => { resolveFn = res }) as never,
      )

      const { result } = renderHook(() => useAuth())
      act(() => {
        result.current.login('x@x.com', 'pw')
      })
      expect(result.current.loading).toBe(true)
      await act(async () => {
        resolveFn({ data: { data: { access_token: 'a', refresh_token: 'r' } } })
      })
      expect(result.current.loading).toBe(false)
    })
  })

  describe('logout', () => {
    it('calls logout API and clears localStorage', async () => {
      vi.mocked(authApi.logout).mockResolvedValueOnce({} as never)
      localStorage.setItem('access_token', 'tok')
      localStorage.setItem('refresh_token', 'ref')

      const { result } = renderHook(() => useAuth())
      await act(async () => {
        await result.current.logout()
      })
      expect(authApi.logout).toHaveBeenCalledWith('ref')
      expect(localStorage.getItem('access_token')).toBeNull()
    })

    it('clears localStorage even if API throws', async () => {
      vi.mocked(authApi.logout).mockRejectedValueOnce(new Error('net'))
      localStorage.setItem('access_token', 'tok')
      localStorage.setItem('refresh_token', 'ref')

      const { result } = renderHook(() => useAuth())
      await act(async () => {
        await result.current.logout()
      })
      expect(localStorage.getItem('access_token')).toBeNull()
    })

    it('skips API call if no refresh token', async () => {
      const { result } = renderHook(() => useAuth())
      await act(async () => {
        await result.current.logout()
      })
      expect(authApi.logout).not.toHaveBeenCalled()
    })
  })
})
