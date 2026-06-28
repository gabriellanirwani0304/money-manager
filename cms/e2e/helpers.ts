import { type Page } from '@playwright/test'

export const DEMO_EMAIL = 'demo@moneymate.dev'
export const DEMO_PASSWORD = 'password123'

export const BASE_URL = process.env.API_BASE_URL ?? 'http://localhost:8080'

/**
 * Inject fake JWT tokens into localStorage so E2E tests can skip the login
 * UI when testing authenticated pages. The token only needs to be structurally
 * valid (base64 JSON segments) — the CMS only decodes it client-side.
 */
export async function injectFakeAuth(page: Page, userID = 'test-user-id') {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
  const payload = btoa(JSON.stringify({ sub: userID, type: 'access', exp: 9999999999 }))
  const fakeToken = `${header}.${payload}.fakesig`
  await page.addInitScript((tok) => {
    localStorage.setItem('access_token', tok)
    localStorage.setItem('refresh_token', 'fake-refresh-token')
  }, fakeToken)
}

/** Login through the UI. Requires the backend to be running with seed data. */
export async function loginViaUI(page: Page, email = DEMO_EMAIL, password = DEMO_PASSWORD) {
  await page.goto('/login')
  await page.getByLabel(/email/i).fill(email)
  await page.getByLabel(/password/i).fill(password)
  await page.getByRole('button', { name: /masuk/i }).click()
  await page.waitForURL('/')
}
