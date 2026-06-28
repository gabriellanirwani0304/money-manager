import api from './client'

export interface LoginResponse {
  access_token: string
  refresh_token: string
}

export const login = (email: string, password: string) =>
  api.post<{ data: LoginResponse }>('/auth/login', { email, password })

export const logout = (refresh_token: string) =>
  api.post('/auth/logout', { refresh_token })
