import { test, expect } from "@playwright/test"

test("admin login mock → dashboard", async ({ page }) => {
  await page.goto("/login")
  await page.getByLabel(/email/i).fill("ops@bdrideshare.com")
  await page.getByLabel(/password/i).fill("Admin@1234")
  await page.getByRole("button", { name: /sign in|login|লগইন/i }).click()
  await expect(page).toHaveURL(/\//)
  await expect(page.getByText(/dashboard|ড্যাশবোর্ড/i)).toBeVisible({ timeout: 10_000 })
})
