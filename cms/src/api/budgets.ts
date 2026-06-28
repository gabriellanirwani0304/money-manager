import api from './client'

export interface Budget {
  id: string
  user_id: string
  category_id: string
  amount: number        // used for create/update requests
  budget_amount?: number // returned by list API
  month: number
  year: number
  spent?: number
  remaining?: number
  percentage?: number
  status?: 'safe' | 'warning' | 'danger' | 'exceeded'
  category?: { id: string; name: string; icon?: string; color?: string }
}

export const listBudgets = (month?: number, year?: number) => {
  const params = new URLSearchParams()
  if (month) params.set('month', String(month))
  if (year) params.set('year', String(year))
  return api.get<{ data: Budget[] }>(`/budgets?${params}`)
}

export const createBudget = (body: Partial<Budget>) =>
  api.post<{ data: Budget }>('/budgets', body)

export const updateBudget = (id: string, body: Partial<Budget>) =>
  api.put<{ data: Budget }>(`/budgets/${id}`, body)

export const deleteBudget = (id: string) =>
  api.delete(`/budgets/${id}`)
