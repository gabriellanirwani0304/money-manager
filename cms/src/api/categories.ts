import api from './client'

export interface Category {
  id: string
  user_id: string
  name: string
  type: 'income' | 'expense'
  icon?: string
  color?: string
  is_default?: boolean
}

export interface CategoryFilter {
  page?: number
  limit?: number
  type?: string
  search?: string
}

export interface CategoryPagination {
  page: number
  limit: number
  total: number
  total_pages: number
}

export interface CategoryListResult {
  categories: Category[]
  pagination: CategoryPagination
}

export const listCategories = (filter: CategoryFilter = {}) => {
  const params = new URLSearchParams()
  Object.entries(filter).forEach(([k, v]) => v !== undefined && v !== '' && params.set(k, String(v)))
  return api.get<{ data: CategoryListResult }>(`/categories?${params}`)
}

export const createCategory = (body: Partial<Category>) =>
  api.post<{ data: Category }>('/categories', body)

export const updateCategory = (id: string, body: Partial<Category>) =>
  api.put<{ data: Category }>(`/categories/${id}`, body)

export const deleteCategory = (id: string) =>
  api.delete(`/categories/${id}`)
