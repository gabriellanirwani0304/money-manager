import { test, expect } from '@playwright/test'
import { loginViaUI } from './helpers'

test.describe('Dashboard (requires backend + seed data)', () => {
  test.beforeEach(async ({ page }) => {
    await loginViaUI(page)
  })

  test('shows 4 summary cards', async ({ page }) => {
    const cards = page.locator('[data-slot="card"]')
    await expect(cards).toHaveCount(4, { timeout: 8000 })
  })

  test('shows card titles', async ({ page }) => {
    await expect(page.getByText('Total Saldo')).toBeVisible({ timeout: 5000 })
    await expect(page.getByText('Pemasukan')).toBeVisible()
    await expect(page.getByText('Pengeluaran')).toBeVisible()
    await expect(page.getByText('Selisih Bersih')).toBeVisible()
  })

  test('cards show numeric values (not just skeletons)', async ({ page }) => {
    await expect(page.locator('[data-slot="skeleton"]')).toHaveCount(0, { timeout: 8000 })
    const cards = page.locator('[data-slot="card-content"]')
    const count = await cards.count()
    expect(count).toBeGreaterThan(0)
  })
})
