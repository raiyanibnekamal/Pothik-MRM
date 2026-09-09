import { test, expect } from "@playwright/test"

test("admin login mock → dashboard", async ({ page }) => {
  await page.goto("/login")
  await page.getByLabel(/email/i).fill("ops@bdrideshare.com")
  await page.getByLabel(/password/i).fill("Admin@1234")
  await page.getByRole("button", { name: /sign in|login|প্রবেশ/i }).click()
  await expect(page).not.toHaveURL(/\/login/)
  await expect(page.getByRole("heading", { name: /dashboard|ড্যাশবোর্ড/i })).toBeVisible({
    timeout: 15_000,
  })
})
