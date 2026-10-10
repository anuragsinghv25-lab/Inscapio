import { z } from "zod";
import { Block, EndnoteBlock } from "./blocks";
import { Dataset } from "./dataset";
import { Accent, ReadingControl, Theme } from "./presentation";
import { Id, LongText, MediumText, ShortText } from "./primitives";
import { Source } from "./sources";
import { checkReferences } from "./references";

/** Bump when a change is not backwards compatible. Documents declare the version they were written for. */
export const SCHEMA_VERSION = 1 as const;

const HeroAction = z.strictObject({
  label: ShortText,
  targetSectionId: Id,
  emphasis: z.enum(["primary", "secondary"]),
});

const Section = z.strictObject({
  id: Id,
  kicker: ShortText.optional(),
  title: ShortText,
  accent: Accent.optional(),
  blocks: z.array(Block).min(1).max(40),
});

export const Experience = z
  .strictObject({
    schemaVersion: z.literal(SCHEMA_VERSION),
    id: Id,
    slug: Id,
    kind: z.enum(["explainer", "data-story"]),
    title: ShortText,
    shortTitle: ShortText,
    language: z.string().regex(/^[a-z]{2}(?:-[A-Z]{2})?$/),
    summary: MediumText,
    theme: Theme,
    reading: z.array(ReadingControl).max(3),
    hero: z.strictObject({
      title: ShortText,
      intro: z.array(LongText).min(1).max(4),
      actions: z.array(HeroAction).max(3),
    }),
    sections: z.array(Section).min(1).max(40),
    sources: z.array(Source).max(100),
    datasets: z.array(Dataset).max(10),
    endnotes: z.array(EndnoteBlock).max(10),
  })
  .superRefine((doc, ctx) => {
    for (const issue of checkReferences(doc)) ctx.addIssue({ code: "custom", ...issue });
  });
export type Experience = z.infer<typeof Experience>;
export type Section = z.infer<typeof Section>;
