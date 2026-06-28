import { test, expect } from '@playwright/test'
import { loginViaUI } from './helpers'

test.describe('Navigation (requires backend + seed data)', () => {
  test.beforeEach(async ({ page }) => {
    await loginViaUI(page)
  })

  test('sidebar contains all nav links', async ({ page }) => {
    const sidebar = page.locator('aside')
    await expect(sidebar.getByText('Dashboard')).toBeVisible()
    await expect(sidebar.getByText('Transaksi')).toBeVisible()
    await expect(sidebar.getByText('Kategori')).toBeVisible()
    await expect(sidebar.getByText('Anggaran')).toBeVisible()
    await expect(sidebar.getByText('Rekening')).toBeVisible()
    await expect(sidebar.getByText('Laporan')).toBeVisible()
  })

  test('navigates to Transaksi page', async ({ page }) => {
    await page.locator('aside').getByText('Transaksi').click()
    await expect(page).toHaveURL('/transactions')
    await expect(page.getByRole('heading', { name: 'Transaksi' })).toBeVisible()
  })

  test('navigates to Kategori page', async ({ page }) => {
    await page.locator('aside').getByText('Kategori').click()
    await expect(page).toHaveURL('/categories')
    await expect(page.getByRole('heading', { name: 'Kategori' })).toBeVisible()
  })

  test('navigates to Anggaran page', async ({ page }) => {
    await page.locator('aside').getByText('Anggaran').click()
    await expect(page).toHaveURL('/budgets')
    await expect(page.getByRole('heading', { name: 'Anggaran' })).toBeVisible()
  })

  test('navigates to Rekening page', async ({ page }) => {
    await page.locator('aside').getByText('Rekening').click()
    await expect(page).toHaveURL('/accounts')
    await expect(page.getByRole('heading', { name: 'Rekening' })).toBeVisible()
  })

  test('navigates to Laporan page', async ({ page }) => {
    await page.locator('aside').getByText('Laporan').click()
    await expect(page).toHaveURL('/reports')
    await expect(page.getByRole('heading', { name: 'Laporan' })).toBeVisible()
  })
})
