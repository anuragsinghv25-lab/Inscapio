import { expect, test } from "@playwright/test";

const VIEWPORTS = [{ width: 320, height: 640 }, { width: 375, height: 740 }, { width: 430, height: 740 }, { width: 1280, height: 800 }] as const;

for (const vp of VIEWPORTS) {
  test.describe(`climate pacing at ${vp.width}`, () => {
    test.use({ viewport: vp });
    test.beforeEach(({}, info) => { test.skip(info.project.name !== "desktop", "viewport-parametrised: runs once"); });

    test("the city selector starts right after the hero, the chart within about one screen, and the illustrative note directly under the chart", async ({ page }) => {
      await page.goto("/experiences/climate", { waitUntil: "networkidle" });
      const y = await page.evaluate(() => {
        const top = (e: Element) => e.getBoundingClientRect().top + scrollY;
        const hero = document.querySelector("header")!;
        const chart = document.querySelector("#explore svg[role=img]")!;
        const note = [...document.querySelectorAll("#explore p")].find((p) => p.textContent?.includes("A demo, not a forecast."))!;
        return {
          heroBottom: top(hero) + hero.getBoundingClientRect().height,
          chips: top(document.querySelector("#explore [role=group]")!),
          chart: top(chart), chartBottom: top(chart) + chart.getBoundingClientRect().height, note: top(note),
        };
      });
      // Before Stage 2 these were about 1.8 to 2.4 screens after the hero (measured on main at 320, 375, 430 and 1280 px).
      expect(y.chips - y.heroBottom, "city selector").toBeLessThan(vp.height * 0.4);
      expect(y.chart - y.heroBottom, "chart").toBeLessThan(vp.height * 1.25);
      expect(y.note, "note below the chart").toBeGreaterThanOrEqual(y.chartBottom - 1);
      expect(y.note - y.chartBottom, "note adjacent to chart").toBeLessThan(vp.height * 0.8);
    });
  });
}

test.describe("climate behaviour is unchanged", () => {
  test.beforeEach(({}, info) => { test.skip(info.project.name !== "desktop", "runs once"); });
  test("Begin now lands on the chart section and the prediction still works", async ({ page }) => {
    await page.goto("/experiences/climate", { waitUntil: "networkidle" });
    await page.getByRole("link", { name: "Begin" }).click();
    await expect(page).toHaveURL(/#explore$/);
    await page.getByRole("button", { name: "Madrid", exact: true }).first().click();
    await expect(page.getByRole("slider")).toBeVisible();
  });
});

test.describe("claims list", () => {
  test.beforeEach(({}, info) => { test.skip(info.project.name !== "desktop", "runs once"); });
  test("shows the hint once, rows are at least 44px tall, and a row opens and closes", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 740 });
    await page.goto("/experiences/whose-body-is-it", { waitUntil: "networkidle" });
    const sec = page.locator("section#chapter-7");
    await expect(sec.getByText("Tap for a fair answer")).toHaveCount(1);
    const rows = sec.locator("button[aria-expanded]");
    await expect(rows).toHaveCount(16);
    const h = await rows.first().boundingBox();
    expect(h!.height).toBeGreaterThanOrEqual(44);
    const total = await sec.locator("button[aria-expanded]").evaluateAll((els) => els.reduce((n, e) => n + e.getBoundingClientRect().height, 0));
    await rows.first().click();
    await expect(rows.first()).toHaveAttribute("aria-expanded", "true");
    await rows.first().click();
    await expect(rows.first()).toHaveAttribute("aria-expanded", "false");
    expect(total).toBeLessThan(16 * 130); // compact: well under the old card stack
  });
});

test.describe("claims without JavaScript", () => {
  test.use({ javaScriptEnabled: false, viewport: { width: 375, height: 740 } });
  test("all answers are shown and no dead hint or indicator is offered", async ({ page }) => {
    await page.goto("/experiences/whose-body-is-it");
    await expect(page.getByText("Tap for a fair answer")).toBeHidden();
    await expect(page.getByText(/certainty of getting caught works better/)).toBeVisible();
  });
});
