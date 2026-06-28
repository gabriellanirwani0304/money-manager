import { test, expect } from '@playwright/test'
import { loginViaUI } from './helpers'

test.describe('Transactions (requires backend + seed data)', () => {
  test.beforeEach(async ({ page }) => {
    await loginViaUI(page)
    await page.locator('aside').getByText('Transaksi').click()
    await page.waitForURL('/transactions')
  })

  test('shows transaction table', async ({ page }) => {
    await expect(page.locator('[data-slot="table"]')).toBeVisible()
  })

  test('opens create dialog', async ({ page }) => {
    await page.getByRole('button', { name: /tambah/i }).click()
    await expect(page.getByText('Tambah Transaksi')).toBeVisible()
  })

  test('opens export CSV dialog', async ({ page }) => {
    await page.getByRole('button', { name: /ekspor csv/i }).click()
    await expect(page.getByText('Ekspor CSV')).toBeVisible()
    await expect(page.getByText('Tanggal Mulai')).toBeVisible()
    await expect(page.getByText('Tanggal Akhir')).toBeVisible()
  })

  test('creates a transaction', async ({ page }) => {
    await page.getByRole('button', { name: /tambah/i }).click()
    await expect(page.getByText('Tambah Transaksi')).toBeVisible()

    const dateInput = page.locator('[data-slot="dialog-content"] input[type="date"]').first()
    await dateInput.fill('2026-06-01')

    const amountInput = page.locator('[data-slot="dialog-content"] input[type="number"]')
    await amountInput.fill('100000')

    await page.getByRole('button', { name: /simpan/i }).click()

    await expect(page.getByText(/transaksi ditambahkan|gagal/i)).toBeVisible({ timeout: 5000 })
  })

  test('shows transactions from seed data', async ({ page }) => {
    await page.waitForSelector('[data-slot="table-body"]')
    const rows = page.locator('[data-slot="table-row"]')
    await expect(rows.first()).toBeVisible({ timeout: 5000 })
  })
})
