import { z } from "zod";
import { Id, LongText, MediumText, RichText, ShortText } from "../primitives";

/* Static, non-interactive content blocks. Source patterns: v0 .lead/p, .say, .card, .q3, .help, .dm, footer. */

export const Paragraph = z.strictObject({
  id: Id,
  type: z.literal("paragraph"),
  variant: z.enum(["body", "lead"]).default("body"),
  content: RichText,
});

/** A pull statement (v0 `.say`). */
export const Callout = z.strictObject({
  id: Id,
  type: z.literal("callout"),
  content: RichText,
});

/** v0 `.card`: an optional bold label followed by text. The label carries its own punctuation. */
export const Card = z.strictObject({
  id: Id,
  type: z.literal("card"),
  label: ShortText.optional(),
  content: RichText,
});

/** v0 `.q3`: a short row of headline facts. */
export const FactRow = z.strictObject({
  id: Id,
  type: z.literal("fact-row"),
  items: z
    .array(z.strictObject({ id: Id, title: ShortText, text: ShortText }))
    .min(2)
    .max(4),
});

/** v0 comparison table (claim / what can be true / what does not follow). Cells are plain text. */
export const CompareTable = z
  .strictObject({
    id: Id,
    type: z.literal("compare-table"),
    columns: z.array(ShortText).min(2).max(6),
    rows: z.array(z.array(MediumText).min(2).max(6)).min(1).max(30),
  })
  .superRefine((t, ctx) => {
    t.rows.forEach((r, i) => {
      if (r.length !== t.columns.length)
        ctx.addIssue({ code: "custom", message: `row ${i} has ${r.length} cells; expected ${t.columns.length}`, path: ["rows", i] });
    });
  });

/** v0 helpline box. `detail` and `note` are plain text so numbers stay verifiable and copyable. */
export const ResourceBox = z.strictObject({
  id: Id,
  type: z.literal("resource-box"),
  title: ShortText,
  items: z
    .array(z.strictObject({ id: Id, value: ShortText, label: ShortText, detail: MediumText.optional() }))
    .min(1)
    .max(8),
  note: LongText,
});

/** v0 footer sources line. Renders the citations of the referenced sources. */
export const SourceList = z.strictObject({
  id: Id,
  type: z.literal("source-list"),
  lead: ShortText,
  sourceIds: z.array(Id).min(1).max(20),
});

/** v0 "Demo data, not a forecast." note. REQUIRED for any experience that uses an illustrative dataset. */
export const DataNote = z.strictObject({
  id: Id,
  type: z.literal("data-note"),
  lead: ShortText.optional(),
  content: RichText,
});
