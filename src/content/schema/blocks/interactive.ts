import { z } from "zod";
import { Accent } from "../presentation";
import { Id, LongText, MediumText, ShortText } from "../primitives";

/** Interactive blocks. Content and declarative parameters only. */

/** v0 "What people say on X": tap-to-open cards with a theme filter. */
export const Claims = z
  .strictObject({
    id: Id,
    type: z.literal("claims"),
    accent: Accent,
    /** Visible prefix on each claim, e.g. "They say:". */
    label: ShortText,
    /** Hint on a closed card, e.g. "Tap for a fair answer". */
    hint: ShortText,
    /** Label of the "no filter" chip. */
    allLabel: ShortText,
    themes: z.array(z.strictObject({ id: Id, label: ShortText })).min(1).max(8),
    items: z
      .array(z.strictObject({ id: Id, theme: Id, claim: MediumText, response: LongText }))
      .min(1)
      .max(40),
  })
  .superRefine((b, ctx) => {
    const themeIds = b.themes.map((t) => t.id);
    if (new Set(themeIds).size !== themeIds.length)
      ctx.addIssue({ code: "custom", message: "theme ids must be unique", path: ["themes"] });
    b.items.forEach((it, i) => {
      if (!themeIds.includes(it.theme))
        ctx.addIssue({ code: "custom", message: `theme '${it.theme}' is not declared in themes`, path: ["items", i, "theme"] });
    });
  });

/** v0 "safety advice or blame?": binary classification with per-item feedback and a closing line. */
export const Classify = z
  .strictObject({
    id: Id,
    type: z.literal("classify"),
    categories: z.tuple([
      z.strictObject({ id: Id, label: ShortText, accent: Accent }),
      z.strictObject({ id: Id, label: ShortText, accent: Accent }),
    ]),
    items: z
      .array(z.strictObject({ id: Id, text: MediumText, answer: Id, feedback: MediumText }))
      .min(1)
      .max(30),
    /** Shown after the last item, following the score. */
    closing: MediumText,
  })
  .superRefine((b, ctx) => {
    const ids = b.categories.map((c) => c.id);
    if (ids[0] === ids[1]) ctx.addIssue({ code: "custom", message: "category ids must differ", path: ["categories"] });
    b.items.forEach((it, i) => {
      if (!ids.includes(it.answer))
        ctx.addIssue({ code: "custom", message: `answer '${it.answer}' is not a category id`, path: ["items", i, "answer"] });
    });
  });

/** v0 "What you can do": choose an option, see its content. */
export const SelectorContent = z
  .strictObject({
    id: Id,
    type: z.literal("selector-content"),
    label: ShortText.optional(),
    options: z.array(z.strictObject({ id: Id, label: ShortText, content: LongText })).min(2).max(12),
    defaultOptionId: Id.optional(),
  })
  .superRefine((b, ctx) => {
    if (b.defaultOptionId && !b.options.some((o) => o.id === b.defaultOptionId))
      ctx.addIssue({ code: "custom", message: "defaultOptionId is not an option", path: ["defaultOptionId"] });
  });
