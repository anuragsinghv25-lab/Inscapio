import type { Experience } from "@/content/schema";

/** Words per minute used for the length estimate. A conventional figure for adult silent reading; an estimate, not a measurement. */
export const WORDS_PER_MINUTE = 200;

const INTERACTIVE = new Set(["accordion", "stepper", "claims", "classify", "selector-content", "scrubber-chart"]);
/** Keys whose string values are identifiers or settings, not prose. */
const NOT_PROSE = new Set([
  "id", "type", "accent", "variant", "datasetId", "answer", "theme", "sourceRef", "marks", "token",
  "targetSectionId", "defaultOptionId", "themeBinding", "emphasis", "kind", "item", "category",
]);

function countWords(node: unknown): number {
  if (typeof node === "string") return node.trim() ? node.trim().split(/\s+/).length : 0;
  if (Array.isArray(node)) return node.reduce<number>((n, x) => n + countWords(x), 0);
  if (node && typeof node === "object") {
    return Object.entries(node).reduce((n, [k, v]) => (NOT_PROSE.has(k) ? n : n + countWords(v)), 0);
  }
  return 0;
}

export interface OutlineItem {
  id: string;
  /** Section kicker (for example "Chapter 3 · Root causes") when present, otherwise the title. */
  label: string;
  title: string;
}

export interface ExperienceOutline {
  items: OutlineItem[];
  /** Estimated minutes to read the simple path (text in "deeper" containers is not counted). */
  minutes: number;
  interactive: number;
}

/** Derives structure and size from a validated document. Nothing here is authored, so nothing needs the schema to change. */
export function describeExperience(e: Experience): ExperienceOutline {
  let words = countWords(e.hero.intro);
  let interactive = 0;
  for (const sec of e.sections) {
    words += countWords(sec.title);
    for (const b of sec.blocks) {
      if (b.type !== "deeper") words += countWords(b);
      if (INTERACTIVE.has(b.type)) interactive += 1;
    }
  }
  return {
    items: e.sections.map((s) => ({ id: s.id, label: s.kicker ?? s.title, title: s.title })),
    minutes: Math.max(1, Math.round(words / WORDS_PER_MINUTE)),
    interactive,
  };
}
