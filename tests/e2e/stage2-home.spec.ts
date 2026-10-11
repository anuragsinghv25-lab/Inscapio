import { expect, test } from "@playwright/test";
import { trackErrors } from "./helpers";

/** Stage 2 · homepage first screen. Viewport-parametrised, so it runs once (on the desktop project). */
const VIEWPORTS = [
  { width: 320, height: 640 },
  { width: 375, height: 740 },
  { width: 430, height: 740 },
  { width: 1280, height: 800 },
] as const;

test.beforeEach(({}, info) => {
  test.skip(info.project.name !== "desktop", "viewport-parametrised: runs once");
});

for (const vp of VIEWPORTS) {
  test.describe(`home first screen at ${vp.width} × ${vp.height}`, () => {
    test.use({ viewport: vp });

    test("headline, positioning, count line and slider are fully inside the first screen", async ({ page }) => {
      const errors = trackErrors(page);
      await page.goto("/", { waitUntil: "networkidle" });
      await page.waitForTimeout(3300); // let the one-off wipe settle
      for (const sel of ["h1", "p:has-text('Where knowledge becomes')", "p:has-text('Two experiences')", "#wipe"]) {
        const box = await page.locator(sel).first().boundingBox();
        expect(box, sel).not.toBeNull();
        expect(box!.y, sel).toBeGreaterThanOrEqual(0);
        expect(box!.y + box!.height, `${sel} bottom within ${vp.height}`).toBeLessThanOrEqual(vp.height);
        expect(box!.x + box!.width, `${sel} right edge`).toBeLessThanOrEqual(vp.width + 0.5);
      }
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(vp.width);
      expect(errors).toEqual([]);
    });

    test("no text in the strip is truncated by its container", async ({ page }) => {
      await page.goto("/", { waitUntil: "networkidle" });
      await page.waitForTimeout(3300);
      const result = await page.evaluate(() => {
        const strip = document.querySelector<HTMLElement>("[role=group][aria-label*='same idea']")!;
        const r = strip.getBoundingClientRect();
        const bad: string[] = [];
        for (const el of strip.querySelectorAll<HTMLElement>("h2, p, li")) {
          const b = el.getBoundingClientRect();
          if (b.right > r.right + 1 || b.bottom > r.bottom + 1 || b.left < r.left - 1) bad.push(el.textContent!.slice(0, 40));
        }
        return { bad, clipped: strip.scrollHeight > strip.clientHeight + 1 };
      });
      expect(result.bad).toEqual([]);
      expect(result.clipped).toBe(false);
    });

    test("at rest, the wipe seam does not cut through the text of either pane", async ({ page }) => {
      test.skip(vp.width < 900, "narrow screens rest on the explore side; the read pane is fully covered by design");
      await page.goto("/", { waitUntil: "networkidle" });
      await page.waitForTimeout(3300);
      const { seam, headlineRight, readLeft } = await page.evaluate(() => {
        const rule = document.querySelector("[role=group][aria-label*='same idea'] > div:last-child")!.getBoundingClientRect();
        const hl = document.querySelector("[role=group][aria-label*='same idea'] > div:nth-child(2) > p")!.getBoundingClientRect();
        const h2 = document.querySelector("[role=group][aria-label*='same idea'] h2")!.getBoundingClientRect();
        return { seam: rule.left + rule.width / 2, headlineRight: hl.right, readLeft: h2.left };
      });
      expect(headlineRight).toBeLessThanOrEqual(seam + 1);
      expect(readLeft).toBeGreaterThanOrEqual(seam - 1);
    });
  });
}

test.describe("home without JavaScript", () => {
  test.use({ javaScriptEnabled: false, viewport: { width: 375, height: 740 } });
  test("states the premise, shows both halves and offers no dead control", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("heading", { level: 1 })).toContainText("Explore it.");
    await expect(page.getByText("Two experiences to explore below.")).toBeVisible();
    await expect(page.getByRole("heading", { name: "What will your city feel like in 2070?" }).first()).toBeVisible();
    await expect(page.getByText(/in 2070 feels like .* does today\./).first()).toBeVisible();
    await expect(page.locator("#wipe")).toBeHidden();
    await expect(page.getByRole("link", { name: /Enter experience/ }).first()).toBeVisible();
  });
});

test.describe("home with reduced motion", () => {
  test.use({ viewport: { width: 1280, height: 800 } });
  test("rests at the same place without animating, slider agrees with the wipe", async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.goto("/", { waitUntil: "networkidle" });
    await page.waitForTimeout(300);
    expect(await page.locator("#wipe").inputValue()).toBe("50");
    const v = await page.locator("[role=group][aria-label*='same idea']").evaluate((e) => getComputedStyle(e).getPropertyValue("--v").trim());
    expect(v).toBe("50%");
  });
});
