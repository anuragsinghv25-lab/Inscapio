import { expect, test } from "@playwright/test";
import { trackErrors } from "./helpers";

test.describe("Whose Body Is It?", () => {
  test.beforeEach(async ({ page }) => { await page.goto("/experiences/whose-body-is-it", { waitUntil: "networkidle" }); });

  test("Deeper reveals and hides the deeper notes", async ({ page }) => {
    const note = page.getByText("Most online debates fail because each side hears a different claim");
    await expect(note).toBeHidden();
    const toggle = page.getByRole("button", { name: /^(Deeper|Simple)$/ });
    await toggle.click();
    await expect(toggle).toHaveText("Simple");
    await expect(toggle).toHaveAttribute("aria-pressed", "true");
    await expect(note).toBeVisible();
    await toggle.click();
    await expect(note).toBeHidden();
  });

  test("text size and theme controls change the page", async ({ page }) => {
    const root = page.locator("#experience-root");
    await page.getByRole("button", { name: "Bigger text" }).click();
    expect(await root.evaluate((e) => (e as HTMLElement).style.getPropertyValue("--fs"))).toBe("21px");
    await page.getByRole("button", { name: "Smaller text" }).click();
    await page.getByRole("button", { name: "Smaller text" }).click();
    expect(await root.evaluate((e) => (e as HTMLElement).style.getPropertyValue("--fs"))).toBe("17px");
    await page.getByRole("button", { name: "Switch between light and dark" }).click();
    await expect(root).toHaveAttribute("data-mode", "dark");
    await page.getByRole("button", { name: "Switch between light and dark" }).click();
    await expect(root).toHaveAttribute("data-mode", "light");
  });

  test("the layers accordion opens and closes", async ({ page }) => {
    const layer = page.getByRole("button", { name: "The fruit: the harm" });
    await expect(layer).toHaveAttribute("aria-expanded", "false");
    await layer.click();
    await expect(layer).toHaveAttribute("aria-expanded", "true");
    await expect(page.getByText("An act that overrides someone's will")).toBeVisible();
  });

  test("steppers highlight steps up to the chosen one and show only its note", async ({ page }) => {
    await page.getByRole("button", { name: /3\. "So we can judge\."/ }).click();
    await expect(page.getByText("Gossip, labels, the word 'characterless'.")).toBeVisible();
    await expect(page.getByText("A private opinion about clothes")).toBeHidden();
    await expect(page.getByRole("button", { name: /1\. "That is wrong\."/ })).toHaveAttribute("aria-expanded", "false");
  });

  test("classify: all six statements, score and closing line", async ({ page }) => {
    const box = page.locator("section#chapter-6");
    // Answers in v0 order: s b b s b s
    for (const a of ["Safety advice", "Blame", "Blame", "Safety advice", "Blame", "Safety advice"]) {
      await box.getByRole("button", { name: a, exact: true }).click();
    }
    await expect(box.getByText("You scored 6 of 6. The same words can be care or blame depending on who they punish.")).toBeVisible();
    await expect(box.getByRole("button", { name: "Blame", exact: true })).toHaveCount(0);
  });

  test("classify: wrong answer gives corrective feedback and lowers the score", async ({ page }) => {
    const box = page.locator("section#chapter-6");
    await box.getByRole("button", { name: "Blame", exact: true }).click(); // statement 1 is safety advice
    await expect(box.getByText(/Not quite\. Right\. It is an offer of practical help/)).toBeVisible();
  });

  test("claims: filter by theme and open an answer", async ({ page }) => {
    const sec = page.locator("section#chapter-7");
    await expect(sec.locator("button[aria-expanded]")).toHaveCount(16);
    await sec.getByRole("button", { name: "About law and society", pressed: false }).click();
    await expect(sec.locator("button[aria-expanded]")).toHaveCount(4);
    const first = sec.locator("button[aria-expanded]").first();
    await first.click();
    await expect(first).toHaveAttribute("aria-expanded", "true");
    await expect(first.getByText(/certainty of getting caught works better/)).toBeVisible();
  });

  test("persona selector swaps the guidance", async ({ page }) => {
    const sec = page.locator("section#chapter-12");
    const out = sec.locator("[aria-live=polite]");
    await expect(out).toContainText("Know the names of your body parts.");
    await sec.getByRole("button", { name: "A parent" }).click();
    await expect(out).toContainText("Teach your sons and daughters the same rule about bodies.");
  });

  test("helplines are present", async ({ page }) => {
    const help = page.locator("aside", { hasText: "needs help (India)" });
    for (const n of ["112", "181", "1098", "1930"]) await expect(help).toContainText(n);
  });

  test("'Jump to the arguments' lands on chapter 7", async ({ page }) => {
    await page.getByRole("link", { name: "Jump to the arguments" }).click();
    await expect(page).toHaveURL(/#chapter-7$/);
    await expect(page.getByRole("heading", { name: "What people say on X, and honest answers" })).toBeInViewport();
  });

  test("the feedback form needs an answer, then saves locally", async ({ page, context }) => {
    await context.grantPermissions(["clipboard-read", "clipboard-write"]).catch(() => {});
    await page.getByRole("button", { name: "Send feedback" }).click();
    await expect(page.getByText("Add an answer first.")).toBeVisible();
    await page.getByRole("button", { name: "Yes" }).first().click();
    await page.getByRole("button", { name: "Send feedback" }).click();
    await expect(page.getByText(/^Thanks\./)).toBeVisible();
    const stored = await page.evaluate(() => JSON.parse(localStorage.getItem("inscapio") || "[]"));
    expect(stored.at(-1)).toMatchObject({ key: "whose-body-is-it", share: "Yes" });
  });
});

test.describe("Climate", () => {
  test.beforeEach(async ({ page }) => { await page.goto("/experiences/climate", { waitUntil: "networkidle" }); });

  test("London starts at 2026 and the slider moves it to 2070 → Madrid", async ({ page }) => {
    const errors = trackErrors(page);
    await expect(page.getByTestId("scrubber-step")).toHaveText("2026");
    await expect(page.getByTestId("scrubber-headline")).toHaveText(/^London today\./);
    await page.getByRole("slider").fill("44");
    await expect(page.getByTestId("scrubber-step")).toHaveText("2070");
    await expect(page.getByTestId("scrubber-headline")).toHaveText("In 2070, London feels most like Madrid does today.");
    expect(errors).toEqual([]);
  });

  test("slider works with the keyboard", async ({ page }) => {
    const slider = page.getByRole("slider");
    await slider.focus();
    await page.keyboard.press("ArrowRight");
    await page.keyboard.press("ArrowRight");
    await expect(page.getByTestId("scrubber-step")).toHaveText("2028");
    await expect(slider).toHaveAttribute("aria-valuetext", "2028");
  });

  test("choosing another city resets the year and prediction", async ({ page }) => {
    await page.getByRole("slider").fill("20");
    await page.getByRole("button", { name: "Tokyo" }).click();
    await expect(page.getByTestId("scrubber-step")).toHaveText("2026");
    await expect(page.getByTestId("scrubber-headline")).toHaveText(/^Tokyo today\./);
    await expect(page.getByRole("button", { name: "Tokyo" })).toHaveAttribute("aria-pressed", "true");
  });

  test("prediction: three options; the right one is marked and the year runs to 2070", async ({ page }) => {
    const opts = page.getByTestId("scrubber-options").getByRole("button");
    await expect(opts).toHaveCount(3);
    await opts.filter({ hasText: "Madrid" }).click();
    await expect(page.getByText(/^Close\. In this demo model it’s Madrid\./)).toBeVisible();
    await expect(page.getByTestId("scrubber-step")).toHaveText("2070", { timeout: 5000 });
  });

  test("prediction: a wrong guess is called out and still reveals the answer", async ({ page }) => {
    const opts = page.getByTestId("scrubber-options").getByRole("button");
    const wrong = opts.filter({ hasNotText: "Madrid" }).first();
    await wrong.click();
    await expect(page.getByText(/^Not quite\. In this demo model it’s Madrid\./)).toBeVisible();
  });

  test("Deeper reveals the Köppen and analogue notes; the data note is always visible", async ({ page }) => {
    await expect(page.getByText("Demo data, not a forecast.")).toBeVisible();
    const note = page.getByText(/Köppen classification, drawn up in the early 1900s/);
    await expect(note).toBeHidden();
    await page.getByRole("button", { name: "Deeper" }).click();
    await expect(note).toBeVisible();
    await expect(page.getByText(/Analogue matching: we compare/)).toBeVisible();
  });

  test("the page warms as time advances (data-bound theme)", async ({ page }) => {
    const root = page.locator("#experience-root");
    const cold = await root.evaluate((e) => (e as HTMLElement).style.getPropertyValue("--warm"));
    await page.getByRole("slider").fill("44");
    const warm = await root.evaluate((e) => (e as HTMLElement).style.getPropertyValue("--warm"));
    expect(Number(cold)).toBe(0);
    expect(Number(warm)).toBeGreaterThan(0.5);
  });
});

test.describe("Home", () => {
  test("city wall answers from the dataset", async ({ page }) => {
    await page.goto("/", { waitUntil: "networkidle" });
    await page.getByRole("button", { name: "London", exact: true }).click();
    await expect(page.getByText(/London in 2070 feels like Madrid does today\./)).toBeVisible();
  });
  test("layer bands open", async ({ page }) => {
    await page.goto("/", { waitUntil: "networkidle" });
    const b = page.getByRole("button", { name: /The soil: society and institutions/ });
    await b.click();
    await expect(b).toHaveAttribute("aria-expanded", "true");
  });
  test("About: go deeper toggles", async ({ page }) => {
    await page.goto("/about", { waitUntil: "networkidle" });
    await page.getByRole("button", { name: "Go deeper" }).click();
    await expect(page.getByText(/This is what a deeper layer looks like/)).toBeVisible();
    await expect(page.getByRole("button", { name: "Back to simple" })).toBeVisible();
  });
});
