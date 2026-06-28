import api from './client'

export interface Transaction {
  id: string
  category_id?: string | null
  account_id?: string
  to_account_id?: string
  type: 'income' | 'expense' | 'transfer'
  amount: number
  description?: string
  date: string
  category?: { id: string; name: string; icon?: string }
  account?: { id: string; name: string }
  to_account?: { id: string; name: string }
}

export interface ListFilter {
  page?: number
  limit?: number
  type?: string
  category_id?: string
  account_id?: string
  start_date?: string
  end_date?: string
  search?: string
}

export interface ListPagination {
  page: number
  limit: number
  total: number
  total_pages: number
}

export interface ListResult {
  transactions: Transaction[]
  pagination: ListPagination
  summary: { total_income: number; total_expense: number }
}

export const listTransactions = (filter: ListFilter = {}) => {
  const params = new URLSearchParams()
  Object.entries(filter).forEach(([k, v]) => v !== undefined && params.set(k, String(v)))
  return api.get<{ data: ListResult }>(`/transactions?${params}`)
}

export const getTransaction = (id: string) =>
  api.get<{ data: Transaction }>(`/transactions/${id}`)

export const createTransaction = (body: Partial<Transaction>) =>
  api.post<{ data: Transaction }>('/transactions', body)

export const updateTransaction = (id: string, body: Partial<Transaction>) =>
  api.put<{ data: Transaction }>(`/transactions/${id}`, body)

export const deleteTransaction = (id: string) =>
  api.delete(`/transactions/${id}`)

export const exportCSV = (start: string, end: string) =>
  api.get(`/transactions/export?start_date=${start}&end_date=${end}`, { responseType: 'blob' })

export interface BatchError { index: number; message: string }
export interface BatchCreateResult { imported: number; failed: number; errors: BatchError[] }

export const batchCreateTransactions = (transactions: Partial<Transaction>[]) =>
  api.post<{ data: BatchCreateResult }>('/transactions/batch', { transactions })
