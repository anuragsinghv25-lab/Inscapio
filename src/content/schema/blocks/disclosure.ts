import { z } from "zod";
import { Accent } from "../presentation";
import { Id, MediumText, ShortText } from "../primitives";
import { CompareTable, Paragraph } from "./text";

/** Blocks that reveal content progressively. Behaviour lives in the application, not here. */

/** Content shown only when the reader switches on "Deeper". Children are a closed subset. */
export const Deeper = z.strictObject({
  id: Id,
  type: z.literal("deeper"),
  blocks: z.array(z.discriminatedUnion("type", [Paragraph, CompareTable])).min(1).max(8),
});

/**
 * v0 layered disclosure. `variant` is PRESENTATION only:
 *  - layers: stacked coloured buttons (v0 "Whose Body Is It?" chapter 3)
 *  - bands: full-width colour bands (v0 home page)
 * Both render the same content.
 */
export const Accordion = z.strictObject({
  id: Id,
  type: z.literal("accordion"),
  variant: z.enum(["layers", "bands"]),
  items: z
    .array(z.strictObject({ id: Id, title: ShortText, body: MediumText, accent: Accent }))
    .min(2)
    .max(12),
});

/** v0 stepper: choosing step N highlights steps 1..N and shows only step N's note. */
export const Stepper = z.strictObject({
  id: Id,
  type: z.literal("stepper"),
  accent: Accent,
  steps: z.array(z.strictObject({ id: Id, title: ShortText, note: MediumText })).min(2).max(12),
});
