import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";
import { trackErrors } from "./helpers";

const BODY = "/experiences/whose-body-is-it";
const CLIMATE = "/experiences/climate";
const root = (page: Page) => page.locator("#experience-root");

test.describe("outline and length line", () => {
  test.beforeEach(({}, info) => { test.skip(info.project.name !== "desktop", "viewport-independent: runs once"); });

  test("hero states size and structure; the list opens and links land on a focused section", async ({ page }) => {
    await page.goto(BODY, { waitUntil: "networkidle" });
    const summary = page.locator("details summary").first();
    await expect(summary).toHaveText(/12 sections · about \d+ min read · 6 interactive/);
    await summary.click();
    await page.getByRole("navigation", { name: "Sections of this experience" }).first().getByRole("link", { name: /Chapter 7/ }).click();
    await expect.poll(() => page.evaluate(() => document.activeElement?.id)).toBe("chapter-7");
    await expect.poll(() => page.locator("#chapter-7").evaluate((e) => e.getBoundingClientRect().top)).toBeLessThan(200);
  });

  test("the bar's Sections control: opens, marks the current section, closes on Escape and returns focus", async ({ page }) => {
    await page.goto(BODY, { waitUntil: "networkidle" });
    await page.locator("#chapter-5").scrollIntoViewIfNeeded();
    await page.evaluate(() => document.getElementById("chapter-5")!.scrollIntoView());
    const btn = page.getByRole("button", { name: "Sections" });
    await expect(btn).toHaveAttribute("aria-expanded", "false");
    await btn.click();
    await expect(btn).toHaveAttribute("aria-expanded", "true");
    const panel = page.getByRole("navigation", { name: "Sections of this experience" }).last();
    await expect(panel.locator("[aria-current=location]")).toContainText("Chapter 5");
    await page.keyboard.press("Tab");
    await expect(panel.getByRole("link").first()).toBeFocused();
    await page.keyboard.press("Escape");
    await expect(btn).toHaveAttribute("aria-expanded", "false");
    await expect(btn).toBeFocused();
  });

  test("choosing a section from the bar scrolls there and closes the panel", async ({ page }) => {
    await page.goto(BODY, { waitUntil: "networkidle" });
    await page.getByRole("button", { name: "Sections" }).click();
    await page.getByRole("navigation", { name: "Sections of this experience" }).last().getByRole("link", { name: /Chapter 10/ }).click();
    await expect(page.getByRole("button", { name: "Sections" })).toHaveAttribute("aria-expanded", "false");
    await expect.poll(() => page.evaluate(() => document.getElementById("chapter-10")!.getBoundingClientRect().top)).toBeLessThan(200);
  });

  test("short experiences get the hero outline but no bar control", async ({ page }) => {
    await page.goto(CLIMATE, { waitUntil: "networkidle" });
    await expect(page.locator("details summary").first()).toHaveText(/3 sections · about \d+ min read · 1 interactive/);
    await expect(page.getByRole("button", { name: "Sections" })).toHaveCount(0);
  });
});

test.describe("outline without JavaScript", () => {
  test.use({ javaScriptEnabled: false, viewport: { width: 375, height: 740 } });
  test("hero outline works, bar control is hidden", async ({ page }) => {
    await page.goto(BODY);
    await page.locator("details summary").first().click();
    await expect(page.getByRole("link", { name: /Chapter 3/ }).first()).toBeVisible();
    await expect(page.getByRole("button", { name: "Sections" })).toBeHidden();
  });
});

for (const vp of [{ width: 320, height: 640 }, { width: 375, height: 740 }, { width: 430, height: 740 }, { width: 1280, height: 800 }]) {
  test.describe(`bar and sections panel at ${vp.width}`, () => {
    test.use({ viewport: vp });
    test.beforeEach(({}, info) => { test.skip(info.project.name !== "desktop", "viewport-parametrised: runs once"); });
    test("controls fit on one row with usable targets; panel stays inside the screen", async ({ page }) => {
      await page.goto(BODY, { waitUntil: "networkidle" });
      const bar = page.getByRole("navigation", { name: "Experience controls" });
      expect(await bar.evaluate((e) => e.scrollWidth <= e.clientWidth)).toBe(true);
      for (const name of ["Sections", "Deeper", "Bigger text", "Smaller text", "Switch between light and dark", "Back to InScapio home"]) {
        const box = await page.getByRole(name === "Back to InScapio home" ? "link" : "button", { name, exact: name === "Sections" || name === "Deeper" }).first().boundingBox();
        expect(box, name).not.toBeNull();
        expect(box!.x, name).toBeGreaterThanOrEqual(0);
        expect(box!.x + box!.width, name).toBeLessThanOrEqual(vp.width);
        expect(box!.height, name).toBeGreaterThanOrEqual(44);
        expect(box!.width, name).toBeGreaterThanOrEqual(24);
      }
      await page.getByRole("button", { name: "Sections" }).click();
      const p = await page.getByRole("navigation", { name: "Sections of this experience" }).last().boundingBox();
      expect(p!.x).toBeGreaterThanOrEqual(0);
      expect(p!.x + p!.width).toBeLessThanOrEqual(vp.width);
      expect(p!.y + p!.height).toBeLessThanOrEqual(vp.height);
    });
  });
}

test.describe("persisted reading preferences", () => {
  test.beforeEach(({}, info) => { test.skip(info.project.name !== "desktop", "viewport-independent: runs once"); });

  test("Deeper, text size and theme survive a reload and carry to another experience", async ({ page }) => {
    await page.goto(BODY, { waitUntil: "networkidle" });
    await page.getByRole("button", { name: "Deeper", exact: true }).click();
    await page.getByRole("button", { name: "Bigger text" }).click();
    await page.getByRole("button", { name: "Switch between light and dark" }).click();
    const fs = await root(page).evaluate((e) => (e as HTMLElement).style.getPropertyValue("--fs"));
    const mode = await root(page).getAttribute("data-mode");
    await page.reload({ waitUntil: "networkidle" });
    await expect(root(page)).toHaveAttribute("data-deeper", "true");
    await expect(root(page)).toHaveAttribute("data-mode", mode!);
    expect(await root(page).evaluate((e) => (e as HTMLElement).style.getPropertyValue("--fs"))).toBe(fs);
    await page.goto(CLIMATE, { waitUntil: "networkidle" });
    await expect(root(page)).toHaveAttribute("data-deeper", "true");
  });

  test("ignores corrupt stored values and clamps text size", async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem("inscapio:prefs", JSON.stringify({ deeper: "yes", fs: 999, mode: "purple" })));
    await page.goto(BODY, { waitUntil: "networkidle" });
    await expect(root(page)).toHaveAttribute("data-deeper", "false");
    expect(await root(page).evaluate((e) => (e as HTMLElement).style.getPropertyValue("--fs"))).toBe("26px");
    await expect(root(page)).not.toHaveAttribute("data-mode", "purple");
  });

  test("works when storage is blocked: controls still function, no errors", async ({ page }) => {
    const errors = trackErrors(page);
    await page.addInitScript(() => {
      const boom = () => { throw new DOMException("blocked", "SecurityError"); };
      Storage.prototype.getItem = boom; Storage.prototype.setItem = boom;
    });
    await page.goto(BODY, { waitUntil: "networkidle" });
    await page.getByRole("button", { name: "Deeper", exact: true }).click();
    await expect(root(page)).toHaveAttribute("data-deeper", "true");
    expect(errors).toEqual([]);
  });
});

test.describe("end state and the promotion hold (Q-16)", () => {
  test.beforeEach(({}, info) => { test.skip(info.project.name !== "desktop", "viewport-independent: runs once"); });

  test("Whose Body Is It? ends by offering the climate experience", async ({ page }) => {
    await page.goto(BODY, { waitUntil: "networkidle" });
    const end = page.locator("section[aria-labelledby=end-title]");
    await expect(end.getByRole("heading", { name: "You’ve reached the end." })).toBeVisible();
    await end.getByRole("link", { name: /What will your city feel like in 2070\?/ }).click();
    await expect(page).toHaveURL(/\/experiences\/climate$/);
  });

  test("Climate never links to the held experience from its end state", async ({ page }) => {
    await page.goto(CLIMATE, { waitUntil: "networkidle" });
    const end = page.locator("section[aria-labelledby=end-title]");
    await expect(end.locator("a[href*='whose-body']")).toHaveCount(0);
    await expect(end.getByRole("link", { name: /More at InScapio/ })).toHaveAttribute("href", "/");
    expect(await page.locator("main a[href*='whose-body']").count()).toBe(0);
  });
});

test.describe("axe on the new open states (necessary, not sufficient for WCAG)", () => {
  test.beforeEach(({}, info) => { test.skip(info.project.name !== "desktop", "viewport-independent: runs once"); });
  for (const mode of ["light", "dark"] as const) {
    test(`Whose Body: hero outline and Sections panel open, ${mode}`, async ({ page }) => {
      await page.emulateMedia({ colorScheme: mode });
      await page.goto(BODY, { waitUntil: "networkidle" });
      await page.locator("details summary").first().click();
      await page.getByRole("button", { name: "Sections" }).click();
      const r = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"]).analyze();
      expect(r.violations.map((v) => `${v.id}: ${v.nodes[0]?.target}`)).toEqual([]);
    });
  }
  test("Climate: hero outline open and end state", async ({ page }) => {
    await page.goto(CLIMATE, { waitUntil: "networkidle" });
    await page.locator("details summary").first().click();
    const r = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"]).analyze();
    expect(r.violations.map((v) => `${v.id}: ${v.nodes[0]?.target}`)).toEqual([]);
  });
});
