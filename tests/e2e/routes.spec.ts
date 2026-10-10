import { expect, test } from "@playwright/test";
import { ROUTES, trackErrors } from "./helpers";

for (const route of ROUTES) {
  test(`${route}: loads, no console errors, no horizontal overflow`, async ({ page }) => {
    const errors = trackErrors(page);
    const res = await page.goto(route, { waitUntil: "networkidle" });
    expect(res?.status()).toBe(200);
    await expect(page.locator("h1").first()).toBeVisible();
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(0);
    expect(errors).toEqual([]);
  });
}

test("unknown route shows a sensible not-found page with a way home", async ({ page }) => {
  const res = await page.goto("/no-such-page");
  expect(res?.status()).toBe(404);
  await expect(page.getByRole("heading", { name: "Page not found" })).toBeVisible();
  await page.getByRole("link", { name: "Back to InScapio" }).click();
  await expect(page).toHaveURL("/");
});

test("unknown experience slug is a 404, not an error", async ({ page }) => {
  const res = await page.goto("/experiences/nope");
  expect(res?.status()).toBe(404);
});

test("v0 hash aliases are real redirects and URLs contain no hash routing", async ({ page }) => {
  await page.goto("/body");
  await expect(page).toHaveURL(/\/experiences\/whose-body-is-it$/);
  await page.goto("/climate");
  await expect(page).toHaveURL(/\/experiences\/climate$/);
});

test("titles are per-page", async ({ page }) => {
  await page.goto("/experiences/climate");
  await expect(page).toHaveTitle(/What will your city feel like in 2070\? — InScapio/);
  await page.goto("/about");
  await expect(page).toHaveTitle(/What is InScapio\? — InScapio/);
});

test("navigation: home → experience → back", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("link", { name: "Enter experience →" }).first().click();
  await expect(page).toHaveURL(/\/experiences\/whose-body-is-it$/);
  await page.getByRole("link", { name: "Back to InScapio home" }).click();
  await expect(page).toHaveURL("/");
});

test("skip link moves focus to main content", async ({ page }) => {
  await page.goto("/about");
  await page.keyboard.press("Tab");
  await expect(page.getByRole("link", { name: "Skip to content" })).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("main")).toBeFocused();
});
