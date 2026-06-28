import { test, expect } from '@playwright/test'
import { loginViaUI } from './helpers'

test.describe('Categories CRUD (requires backend + seed data)', () => {
  test.beforeEach(async ({ page }) => {
    await loginViaUI(page)
    await page.locator('aside').getByText('Kategori').click()
    await page.waitForURL('/categories')
  })

  test('shows category list', async ({ page }) => {
    const table = page.locator('[data-slot="table"]')
    await expect(table).toBeVisible()
    await expect(table.locator('[data-slot="table-row"]').first()).toBeVisible({ timeout: 5000 })
  })

  test('creates a new category', async ({ page }) => {
    await page.getByRole('button', { name: /tambah/i }).click()
    await expect(page.getByText('Tambah Kategori')).toBeVisible()

    const inputs = page.locator('[data-slot="dialog-content"] input[type="text"], [data-slot="dialog-content"] input:not([type])')
    await inputs.first().fill('Test Otomatis')

    await page.getByRole('button', { name: /simpan/i }).click()

    await expect(page.getByText('Kategori ditambahkan')).toBeVisible({ timeout: 5000 })
    await expect(page.getByText('Test Otomatis')).toBeVisible({ timeout: 5000 })
  })

  test('edits a category', async ({ page }) => {
    await page.waitForSelector('[data-slot="table-row"]')
    const firstEditBtn = page.locator('button[data-slot="button"]').filter({ has: page.locator('.lucide-pencil') }).first()
    await firstEditBtn.click()

    await expect(page.getByText('Edit Kategori')).toBeVisible()

    const nameInput = page.locator('[data-slot="dialog-content"] input').first()
    await nameInput.clear()
    await nameInput.fill('Edit Test')
    await page.getByRole('button', { name: /simpan/i }).click()

    await expect(page.getByText('Kategori diperbarui')).toBeVisible({ timeout: 5000 })
  })

  test('deletes a category', async ({ page }) => {
    await page.getByRole('button', { name: /tambah/i }).click()
    const inputs = page.locator('[data-slot="dialog-content"] input').first()
    await inputs.fill('Hapus Ini')
    await page.getByRole('button', { name: /simpan/i }).click()
    await expect(page.getByText('Kategori ditambahkan')).toBeVisible({ timeout: 5000 })

    const trashBtn = page.locator('button[data-slot="button"]')
      .filter({ has: page.locator('.lucide-trash-2') })
      .last()
    await trashBtn.click()

    await expect(page.getByText('Hapus Kategori')).toBeVisible()
    await page.getByRole('button', { name: /hapus/i }).click()
    await expect(page.getByText('Kategori dihapus')).toBeVisible({ timeout: 5000 })
  })
})
