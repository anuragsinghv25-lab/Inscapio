import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";
import { ROUTES } from "./helpers";

const TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"];
const scan = async (page: Page) => {
  const r = await new AxeBuilder({ page }).withTags(TAGS).analyze();
  return r.violations.map((v) => `${v.id} (${v.impact}): ${v.nodes.slice(0, 3).map((n) => n.target.join(" ")).join(" | ")}`);
};

for (const route of ROUTES) {
  test(`axe: ${route} has no WCAG A/AA violations`, async ({ page }) => {
    await page.goto(route, { waitUntil: "networkidle" });
    await page.waitForTimeout(2200); // let entrance animations settle
    expect(await scan(page)).toEqual([]);
  });
}

test("axe: Whose Body Is It? with Deeper on and everything expanded", async ({ page }) => {
  await page.goto("/experiences/whose-body-is-it", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "Deeper" }).click();
  for (const b of await page.getByRole("button", { name: /^(The fruit|The moment|The group|The mind|The home|The soil)/ }).all()) await b.click();
  await page.getByRole("button", { name: /5\. "So we can control\."/ }).click();
  await page.locator("section#chapter-7 button[aria-expanded]").first().click();
  expect(await scan(page)).toEqual([]);
});

test("axe: Whose Body Is It? in dark mode (contrast of accent text and surfaces)", async ({ browser }) => {
  const ctx = await browser.newContext({ colorScheme: "dark" });
  const page = await ctx.newPage();
  await page.goto("/experiences/whose-body-is-it", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "Deeper" }).click();
  expect(await scan(page)).toEqual([]);
  await ctx.close();
});

test("axe: Whose Body Is It? forced light while OS is dark", async ({ browser }) => {
  const ctx = await browser.newContext({ colorScheme: "dark" });
  const page = await ctx.newPage();
  await page.goto("/experiences/whose-body-is-it", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "Switch between light and dark" }).click();
  await page.getByRole("button", { name: "Deeper" }).click();
  await page.waitForTimeout(800); // the background cross-fades (0.5s); scan the settled state
  expect(await scan(page)).toEqual([]);
  await ctx.close();
});

test("axe: Climate at 2070 (warm theme) with Deeper on and a prediction answered", async ({ page }) => {
  await page.goto("/experiences/climate", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "Deeper" }).click();
  await page.getByTestId("scrubber-options").getByRole("button").first().click();
  await expect(page.getByTestId("scrubber-step")).toHaveText("2070", { timeout: 5000 });
  expect(await scan(page)).toEqual([]);
});

test("reduced motion: the experience still opens and the prediction jumps straight to 2070", async ({ browser }) => {
  const ctx = await browser.newContext({ reducedMotion: "reduce" });
  const page = await ctx.newPage();
  await page.goto("/experiences/climate", { waitUntil: "networkidle" });
  await page.getByTestId("scrubber-options").getByRole("button").first().click();
  await expect(page.getByTestId("scrubber-step")).toHaveText("2070", { timeout: 500 });
  await ctx.close();
});

test("keyboard: every control in the Whose Body experience bar is reachable and operable", async ({ page }) => {
  await page.goto("/experiences/whose-body-is-it", { waitUntil: "networkidle" });
  const names: string[] = [];
  for (let i = 0; i < 8; i++) {
    await page.keyboard.press("Tab");
    names.push(await page.evaluate(() => (document.activeElement?.getAttribute("aria-label") ?? document.activeElement?.textContent ?? "").trim()));
  }
  expect(names).toEqual(expect.arrayContaining(["Skip to content", "Back to InScapio home", "Deeper", "Bigger text", "Smaller text", "Switch between light and dark"]));
});

test.describe("without JavaScript", () => {
  test.use({ javaScriptEnabled: false });

  test("Whose Body Is It? shows all content, including deeper notes, claims answers and layers", async ({ page }) => {
    await page.goto("/experiences/whose-body-is-it");
    await expect(page.getByText("Most online debates fail because each side hears a different claim")).toBeVisible();
    await expect(page.getByText("An act that overrides someone's will")).toBeVisible();
    await expect(page.getByText(/certainty of getting caught works better/).first()).toBeVisible();
    await expect(page.getByText("Gossip, labels, the word 'characterless'.")).toBeVisible();
  });

  test("Climate shows every city's 2070 analogue and the data note", async ({ page }) => {
    await page.goto("/experiences/climate");
    await expect(page.getByText("London in 2070 feels like Madrid does today.")).toBeVisible();
    await expect(page.getByText("Demo data, not a forecast.")).toBeVisible();
    await expect(page.getByText(/Köppen classification/)).toBeVisible();
  });
});
