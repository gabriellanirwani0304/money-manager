import { test, expect } from '@playwright/test'
import { DEMO_EMAIL, DEMO_PASSWORD } from './helpers'

test.describe('Auth', () => {
  test.beforeEach(async ({ page }) => {
    await page.context().clearCookies()
    await page.evaluate(() => localStorage.clear())
  })

  test('login page renders correctly', async ({ page }) => {
    await page.goto('/login')
    await expect(page.getByText('MoneyMate CMS')).toBeVisible()
    await expect(page.getByLabel(/email/i)).toBeVisible()
    await expect(page.getByLabel(/password/i)).toBeVisible()
    await expect(page.getByRole('button', { name: /masuk/i })).toBeVisible()
  })

  test('unauthenticated user is redirected to /login', async ({ page }) => {
    await page.goto('/')
    await expect(page).toHaveURL(/\/login/)
  })

  test('shows error on invalid credentials', async ({ page }) => {
    await page.goto('/login')
    await page.getByLabel(/email/i).fill('wrong@example.com')
    await page.getByLabel(/password/i).fill('wrongpassword')
    await page.getByRole('button', { name: /masuk/i }).click()
    await expect(page.locator('p.text-destructive')).toBeVisible({ timeout: 5000 })
  })

  test('successful login navigates to dashboard', async ({ page }) => {
    await page.goto('/login')
    await page.getByLabel(/email/i).fill(DEMO_EMAIL)
    await page.getByLabel(/password/i).fill(DEMO_PASSWORD)
    await page.getByRole('button', { name: /masuk/i }).click()
    await expect(page).toHaveURL('/', { timeout: 10_000 })
    await expect(page.getByText('Dashboard')).toBeVisible()
  })

  test('logout clears session and redirects to login', async ({ page }) => {
    await page.goto('/login')
    await page.getByLabel(/email/i).fill(DEMO_EMAIL)
    await page.getByLabel(/password/i).fill(DEMO_PASSWORD)
    await page.getByRole('button', { name: /masuk/i }).click()
    await page.waitForURL('/')

    await page.getByRole('button', { name: /keluar/i }).click()
    await expect(page).toHaveURL(/\/login/)
    expect(await page.evaluate(() => localStorage.getItem('access_token'))).toBeNull()
  })
})
