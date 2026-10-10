import { Fragment, type ReactNode } from "react";
import type { Template, TemplateToken } from "@/content/schema/primitives";
import { applyMarks } from "./RichText";

export type TemplateValues = Record<TemplateToken, string | number>;

/** Fills a content template with data-token values. Pure; used by data-driven blocks. */
export function renderTemplate(t: Template, values: TemplateValues): ReactNode {
  return t.map((n, i) => (
    <Fragment key={i}>{applyMarks("token" in n ? String(values[n.token]) : n.text, n.marks)}</Fragment>
  ));
}

/** Plain-text form of a template (for aria labels and tests). */
export function templateText(t: Template, values: TemplateValues): string {
  return t.map((n) => ("token" in n ? String(values[n.token]) : n.text)).join("");
}
