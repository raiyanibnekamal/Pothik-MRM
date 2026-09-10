import { test, expect } from "@playwright/test"

test("admin login mock → dashboard", async ({ page }) => {
  await page.goto("/login")
  await page.locator('input[autocomplete="username"]').fill("0152170004")
  await page.locator('input[autocomplete="current-password"]').fill("123456")
  await page.getByRole("button", { name: /sign in|প্রবেশ/i }).click()
  await expect(page.locator("aside nav")).toBeVisible({ timeout: 15_000 })
  await expect(page.getByText(/rides today|আজকের রাইড/i)).toBeVisible({ timeout: 15_000 })
})
