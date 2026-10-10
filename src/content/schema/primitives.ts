import { z } from "zod";

/**
 * Shared schema primitives.
 *
 * Safety rules (docs/architecture/content-architecture.md "Schema design rules"):
 *  - every object is strict: unknown keys (style, html, onClick, className, script…) are REJECTED;
 *  - text is text: anything that looks like markup is rejected, and React renders it as text only;
 *  - URLs must be https;
 *  - there is no field anywhere that accepts HTML, CSS, JavaScript or a component name.
 */

/** Stable, human-readable identifier. Never reused within a document. */
export const Id = z
  .string()
  .regex(/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/, "ids are lower-case kebab-case, starting with a letter")
  .max(64);
export type Id = z.infer<typeof Id>;

const MARKUP = /<\s*\/?\s*[a-zA-Z!?][^>]*>?/;
const CONTROL = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;

/** Plain text that may not contain markup or control characters. */
export const safeText = (max: number) =>
  z
    .string()
    .min(1)
    .max(max)
    .refine((s) => !MARKUP.test(s), "text must not contain HTML or markup")
    .refine((s) => !CONTROL.test(s), "text must not contain control characters");

export const ShortText = safeText(200);
export const MediumText = safeText(1200);
export const LongText = safeText(4000);

export const HttpsUrl = z
  .string()
  .max(2048)
  .refine((u) => {
    try {
      return new URL(u).protocol === "https:";
    } catch {
      return false;
    }
  }, "must be an https URL");

export const IsoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "must be YYYY-MM-DD");

/* -------------------------------------------------------------------------- */
/* Rich text: a deliberately tiny AST. Two marks, one reference node.         */
/* -------------------------------------------------------------------------- */

export const MARKS = ["strong", "em"] as const;
const Marks = z.array(z.enum(MARKS)).max(2).refine((m) => new Set(m).size === m.length, "duplicate mark");

export const TextNode = z.strictObject({ text: LongText, marks: Marks.optional() });
/** Inline citation: rendered as the source's citation text. Must resolve to an experience source. */
export const SourceRefNode = z.strictObject({ sourceRef: Id });

export const InlineNode = z.union([TextNode, SourceRefNode]);
export const RichText = z.array(InlineNode).min(1).max(200);
export type RichText = z.infer<typeof RichText>;
export type InlineNode = z.infer<typeof InlineNode>;

/* -------------------------------------------------------------------------- */
/* Templates: text with a closed set of data tokens (used by data-driven      */
/* blocks). A token is replaced by the renderer with a value from the dataset. */
/* -------------------------------------------------------------------------- */

export const TEMPLATE_TOKENS = ["group", "step", "lastStep", "match"] as const;
export type TemplateToken = (typeof TEMPLATE_TOKENS)[number];

export const TemplateNode = z.union([
  TextNode,
  z.strictObject({ token: z.enum(TEMPLATE_TOKENS), marks: Marks.optional() }),
]);
export const Template = z.array(TemplateNode).min(1).max(40);
export type Template = z.infer<typeof Template>;
