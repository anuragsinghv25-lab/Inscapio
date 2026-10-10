import type { Page } from "@playwright/test";

/** Collects console errors and uncaught exceptions for the life of a page. */
export function trackErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  page.on("pageerror", (e) => errors.push(`pageerror: ${e.message}`));
  return errors;
}

export const norm = (s: string) => s.replace(/\s+/g, " ").trim();
export const ROUTES = ["/", "/about", "/experiences/whose-body-is-it", "/experiences/climate"] as const;
