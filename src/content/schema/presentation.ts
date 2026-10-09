import { z } from "zod";
import { ACCENTS } from "@/design-system/accents";

/**
 * PRESENTATION layer: closed lists the renderer maps to design-system tokens.
 * Content selects a name; it never supplies a value, class, selector or colour.
 */
export const Accent = z.enum(ACCENTS);
export type Accent = z.infer<typeof Accent>;

/** paper: switchable light/dark reading theme ("Whose Body Is It?"). tarn: dark teal, data-bound ("Climate"). */
export const THEMES = ["paper", "tarn"] as const;
export const Theme = z.enum(THEMES);
export type Theme = z.infer<typeof Theme>;

/** Reading controls shown in the experience bar. */
export const READING_CONTROLS = ["deeper", "text-size", "theme"] as const;
export const ReadingControl = z.enum(READING_CONTROLS);
export type ReadingControl = z.infer<typeof ReadingControl>;
