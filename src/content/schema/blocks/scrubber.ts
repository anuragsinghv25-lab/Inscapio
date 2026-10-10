import { z } from "zod";
import { Id, ShortText, Template } from "../primitives";

/**
 * v0 climate chart: choose a group, optionally predict, then scrub a step (year) and watch a
 * periodic curve, summary stats, an analogue sentence and (optionally) the theme respond.
 * All values come from the referenced Dataset; this block carries wording and parameters only.
 */
const Stat = z.discriminatedUnion("kind", [
  z.strictObject({ kind: z.literal("high"), label: ShortText }),
  z.strictObject({ kind: z.literal("low"), label: ShortText }),
  z.strictObject({
    kind: z.literal("category"),
    label: ShortText,
    /** Appended with the earlier category when it has changed, e.g. ", changed from". */
    changedFrom: ShortText,
  }),
]);

export const ScrubberChart = z
  .strictObject({
    id: Id,
    type: z.literal("scrubber-chart"),
    datasetId: Id,
    groupSelector: z.strictObject({ label: ShortText, initialGroupId: Id.optional() }),
    stepControl: z.strictObject({ label: ShortText }),
    chart: z
      .strictObject({
        title: ShortText,
        yMin: z.number().finite(),
        yMax: z.number().finite(),
        yTicks: z.array(z.number().finite()).min(2).max(8),
        /** Appended to tick labels and stat values, e.g. "°". */
        valueSuffix: z.string().max(4),
      })
      .refine((c) => c.yMin < c.yMax, "yMin must be less than yMax"),
    legend: z.strictObject({ first: Template, now: Template, match: Template }),
    headline: z.strictObject({ atFirstStep: Template, later: Template }),
    stats: z.array(Stat).min(1).max(4),
    prediction: z
      .strictObject({
        question: Template,
        /** For each group, the options offered (the correct analogue among them). */
        optionsByGroup: z.record(Id, z.array(Id).min(2).max(6)),
        correctPrefix: ShortText,
        wrongPrefix: ShortText,
        reveal: Template,
      })
      .optional(),
    /** "warmth": the page theme follows the dataset's `warm` value. "none": static theme. */
    themeBinding: z.enum(["none", "warmth"]),
  })
  .superRefine((b, ctx) => {
    const t = b.chart.yTicks;
    if (t.some((v) => v < b.chart.yMin || v > b.chart.yMax))
      ctx.addIssue({ code: "custom", message: "yTicks must lie within yMin..yMax", path: ["chart", "yTicks"] });
  });
