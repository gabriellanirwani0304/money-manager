import api from './client'

export const getMonthlySummary = (month: number, year: number) =>
  api.get(`/reports/summary?month=${month}&year=${year}`)

export const getMonthlyTrend = () =>
  api.get('/reports/monthly')

export const getCategoryBreakdown = (type: string, month: number, year: number) =>
  api.get(`/reports/by-category?type=${type}&month=${month}&year=${year}`)

export const getInsights = (month: number, year: number) =>
  api.get(`/reports/insights?month=${month}&year=${year}`)

export const getDashboard = (month: number, year: number) =>
  api.get(`/dashboard?month=${month}&year=${year}`)
