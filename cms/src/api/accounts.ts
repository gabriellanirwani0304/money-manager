import api from './client'

export interface Account {
  id: string
  user_id: string
  name: string
  type: string
  balance: number
  icon?: string
  color?: string
}

export const listAccounts = () =>
  api.get<{ data: Account[] }>('/accounts')

export const createAccount = (body: Partial<Account>) =>
  api.post<{ data: Account }>('/accounts', body)

export const updateAccount = (id: string, body: Partial<Account>) =>
  api.put<{ data: Account }>(`/accounts/${id}`, body)

export const setBalance = (id: string, balance: number) =>
  api.patch<{ data: Account }>(`/accounts/${id}/balance`, { balance })

export const deleteAccount = (id: string) =>
  api.delete(`/accounts/${id}`)
