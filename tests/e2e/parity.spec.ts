/**
 * Parity against the FROZEN prototype (prototype/v0/index.html), loaded from disk and driven in a real browser.
 * What this proves: v0's own model outputs equal the shipped dataset; displayed climate outputs equal v0's for a
 * sample of city×year; prediction options and wording equal v0's for every city; and every text item in
 * each Whose Body chapter, the home page and About also appears in the new page.
 * What it does NOT prove: pixel parity or identical timing/animation. Screenshots are saved for human review.
 */
import { readFileSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { expect, test, type Page } from "@playwright/test";
import { norm } from "./helpers";

/* Globals defined by v0's inline script; they exist only inside the v0 page (used within page.evaluate). */
/* eslint-disable @typescript-eslint/no-explicit-any */
declare const C: any[];
declare const temp: (c: any, m: number, g: number) => number;
declare const stats: (c: any, g: number) => { w: number; k: number };
declare const kind: (c: any, g: number) => string;
declare const feels: (c: any, g: number) => { n: string };

const V0 = pathToFileURL(resolve("prototype/v0/index.html")).href;
const SHOTS = resolve("test-results/parity");

/** Whole-page text, excluding script payloads (Next inlines its flight data in <script>). */
const pageText = (page: Page) =>
  page.evaluate(() => {
    const c = document.body.cloneNode(true) as HTMLElement;
    c.querySelectorAll("script, style").forEach((n) => n.remove());
    return c.textContent ?? "";
  });

async function openV0(page: Page, hash: string) {
  await page.route(/^https?:/, (r) => r.abort()); // v0 pulls Google Fonts; fall back to local fonts
  await page.goto(`${V0}#/${hash}`, { waitUntil: "domcontentloaded" });
  await page.waitForSelector(".view:not([hidden])");
  await page.waitForTimeout(300);
}

const dataset = JSON.parse(readFileSync("src/content/experiences/climate/datasets/city-temperatures.json", "utf8")) as {
  groups: { id: string; label: string }[];
  steps: number[];
  values: Record<string, number[][]>;
  derived: Record<string, { match: string; category: string; warm: number; high: number; low: number }[]>;
};
const label = (id: string) => dataset.groups.find((g) => g.id === id)!.label;

test.describe("climate model parity (v0 globals vs shipped dataset)", () => {
  test.skip(({ viewport }) => (viewport?.width ?? 0) < 1000, "viewport independent: runs once, on desktop");

  test("all 20 cities × 45 years: monthly values, analogue, type, warmth, warmest/coldest month", async ({ page }) => {
    await openV0(page, "experiences/climate");
    const v0 = await page.evaluate(() => {
      // v0's top-level consts (C, temp, stats, kind, feels) are visible to evaluate() as global bindings.
      /* eslint-disable */
      return C.map((c: any) => Array.from({ length: 45 }, (_, i) => {
        const g = i / 44;
        const s = stats(c, g);
        return {
          name: c.n,
          months: Array.from({ length: 12 }, (_, m) => temp(c, m, g)),
          match: feels(c, g).n,
          kind: kind(c, g),
          warm: Math.min(1, (c.dT * g) / 3),
          w: s.w,
          k: s.k,
        };
      }));
    });
    expect(v0).toHaveLength(20);
    let compared = 0, worstTemp = 0;
    for (const city of v0 as any[][]) {
      const id = dataset.groups.find((g) => g.label === city[0].name)!.id;
      expect(dataset.groups.find((g) => g.id === id)).toBeTruthy();
      city.forEach((row, i) => {
        const d = dataset.derived[id]![i]!;
        expect(label(d.match), `${row.name} ${2026 + i} analogue`).toBe(row.match);
        expect(d.category, `${row.name} ${2026 + i} type`).toBe(row.kind);
        expect(Math.abs(d.warm - row.warm)).toBeLessThan(1e-5);
        expect(Math.abs(d.high - row.w)).toBeLessThan(1e-5);
        expect(Math.abs(d.low - row.k)).toBeLessThan(1e-5);
        row.months.forEach((t: number, m: number) => {
          const diff = Math.abs(dataset.values[id]![i]![m]! - t);
          worstTemp = Math.max(worstTemp, diff);
          expect(diff).toBeLessThanOrEqual(0.0051);
        });
        compared++;
      });
    }
    expect(compared).toBe(900);
    console.log(`climate parity: ${compared} city-years compared, worst monthly deviation ${worstTemp.toFixed(4)}°`);
  });
});

test.describe("climate displayed output parity (v0 DOM vs new DOM)", () => {
  test.skip(({ viewport }) => (viewport?.width ?? 0) < 1000, "viewport independent: runs once, on desktop");
  const YEARS = [2026, 2030, 2041, 2055, 2070];

  test("headline, big year and stat tiles match for every city at five years", async ({ browser }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    const v0 = await ctx.newPage();
    const app = await ctx.newPage();
    await openV0(v0, "experiences/climate");
    await app.goto("/experiences/climate", { waitUntil: "networkidle" });
    let n = 0;
    for (const g of dataset.groups) {
      await v0.locator("#cc").getByRole("button", { name: g.label, exact: true }).click();
      await app.getByRole("group", { name: "Choose a city" }).getByRole("button", { name: g.label, exact: true }).click();
      for (const y of YEARS) {
        await v0.locator("#sl").fill(String(y));
        await app.getByRole("slider").fill(String(y - 2026));
        const a = [norm(await v0.locator("#yr").innerText()), norm(await v0.locator("#an").innerText()), norm(await v0.locator("#stt").innerText())];
        const b = [norm(await app.getByTestId("scrubber-step").innerText()), norm(await app.getByTestId("scrubber-headline").innerText()), norm(await app.getByTestId("scrubber-stats").innerText())];
        expect(b, `${g.label} ${y}`).toEqual(a);
        n++;
      }
    }
    console.log(`displayed-output parity: ${n} city-year states identical`);
    await ctx.close();
  });

  test("prediction question, options and reveal text match v0 for every city (right and wrong answers)", async ({ browser }) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    const v0 = await ctx.newPage();
    const app = await ctx.newPage();
    await openV0(v0, "experiences/climate");
    await app.goto("/experiences/climate", { waitUntil: "networkidle" });
    for (const g of dataset.groups) {
      await v0.locator("#cc").getByRole("button", { name: g.label, exact: true }).click();
      await app.getByRole("group", { name: "Choose a city" }).getByRole("button", { name: g.label, exact: true }).click();
      const q0 = norm(await v0.locator("#gq").innerText());
      const o0 = (await v0.locator("#go2 button").allInnerTexts()).map(norm);
      const opts = app.getByTestId("scrubber-options").getByRole("button");
      const o1 = (await opts.allInnerTexts()).map(norm);
      expect(o1, `${g.label} options`).toEqual(o0);
      for (let i = 0; i < o0.length; i++) {
        await v0.locator("#go2 button").nth(i).click();
        await opts.nth(i).click();
        const r0 = norm(await v0.locator("#gr").innerText());
        const r1 = norm(await app.locator("[aria-live=polite]", { hasText: /In this demo model/ }).first().innerText());
        expect(r1, `${g.label} answer ${o0[i]}`).toBe(r0);
      }
      expect(norm(await app.getByText(/^Before you drag:/).innerText()), g.label).toBe(q0);
    }
    await ctx.close();
  });
});

test.describe("text parity: every v0 text item exists in the new page", () => {
  test.skip(({ viewport }) => (viewport?.width ?? 0) < 1000, "viewport independent: runs once, on desktop");

  const items = (root: string, sel: string) => (page: Page) =>
    page.evaluate(([r, s]) => {
      const out: string[] = [];
      const scoped = s.split(",").map((x) => `${r} ${x.trim()}`).join(", ");
      for (const el of document.querySelectorAll(scoped)) {
        const t = (el.textContent || "").replace(/\s+/g, " ").trim();
        if (t) out.push(t);
      }
      return out;
    }, [root, sel] as const);

  test("Whose Body Is It?: hero, 12 chapters, footer", async ({ page, browser }) => {
    const v0 = await (await browser.newContext()).newPage();
    await openV0(v0, "experiences/whose-body-is-it");
    await page.goto("/experiences/whose-body-is-it", { waitUntil: "networkidle" });
    const SEL = "h1, h2, p, .tag, .say, .card, th, td, button:not(#dm):not(#fa):not(#fs):not(#th), h3";
    let checked = 0;
    const hero = await items("#xp1 .hero", "h1, p, a")(v0);
    const ourHero = norm(await page.locator("header").first().innerText());
    for (const t of hero) { expect(ourHero, `hero: ${t.slice(0, 40)}`).toContain(norm(t)); checked++; }
    for (let n = 1; n <= 12; n++) {
      const v0Items = await items(`#xp1 #c${n}`, SEL)(v0);
      const ours = norm(await page.locator(`section#chapter-${n}`).evaluate((e) => e.textContent ?? ""));
      for (const t of v0Items) { expect(ours, `chapter ${n}: "${t.slice(0, 50)}"`).toContain(norm(t)); checked++; }
    }
    const foot = await items("#xp1 > footer", "p")(v0);
    const ourFoot = norm(await page.locator("main > footer").evaluate((e) => e.textContent ?? ""));
    for (const t of foot) { expect(ourFoot).toContain(norm(t)); checked++; }
    console.log(`Whose Body text parity: ${checked} v0 text items found in the new page`);
    expect(checked).toBeGreaterThan(150);
  });

  test("Climate: hero, sections, notes", async ({ page, browser }) => {
    const v0 = await (await browser.newContext()).newPage();
    await openV0(v0, "experiences/climate");
    await page.goto("/experiences/climate", { waitUntil: "networkidle" });
    const v0Items = await items("#cl section.cs", "h1, h2, p:not(#gq):not(#gr):not(#an), .q3 div, .dp, .dm, .go, label")(v0);
    const ours = norm(await page.locator("main").evaluate((e) => e.textContent ?? ""));
    for (const t of v0Items) expect(ours, `"${t.slice(0, 60)}"`).toContain(norm(t.replace(/^Year\s*\d{4}$/, "Year")));
    expect(v0Items.length).toBeGreaterThan(10);
  });

  test("Home and About copy", async ({ page, browser }) => {
    const v0 = await (await browser.newContext()).newPage();
    await openV0(v0, "");
    await page.goto("/", { waitUntil: "networkidle" });
    const homeItems = await items("#home", "h1, h2, p, a, button, label, li")(v0);
    const ours = norm(await pageText(page));
    // v0's wipe-slider caption states change as the reader drags; the rest is static copy.
    for (const t of homeItems) expect(ours, `home: "${t.slice(0, 60)}"`).toContain(norm(t));
    await openV0(v0, "about");
    await page.goto("/about", { waitUntil: "networkidle" });
    const aboutItems = await items("#about", "h1, p, button, a")(v0);
    const oursAbout = norm(await pageText(page));
    for (const t of aboutItems) expect(oursAbout, `about: "${t.slice(0, 60)}"`).toContain(norm(t));
  });
});

test.describe("screenshots for human review (not asserted)", () => {
  const views = [["home", "", "/"], ["about", "about", "/about"], ["body", "experiences/whose-body-is-it", "/experiences/whose-body-is-it"], ["climate", "experiences/climate", "/experiences/climate"]] as const;
  for (const [name, hash, path] of views) {
    test(`${name}: v0 and new, full page`, async ({ page, browser }, ti) => {
      mkdirSync(SHOTS, { recursive: true });
      const v0 = await browser.newPage({ viewport: page.viewportSize()! });
      await openV0(v0, hash);
      await v0.waitForTimeout(2800);
      await v0.screenshot({ path: `${SHOTS}/${ti.project.name}-${name}-v0.png`, fullPage: true });
      await page.goto(path, { waitUntil: "networkidle" });
      await page.waitForTimeout(2800);
      await page.screenshot({ path: `${SHOTS}/${ti.project.name}-${name}-new.png`, fullPage: true });
    });
  }
});
