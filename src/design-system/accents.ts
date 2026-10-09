/** Closed list of section accents. Must match accents.css and tokens.css. */
export const ACCENTS = ["rose", "teal", "violet", "ochre", "blue", "plum", "green", "pink", "indigo"] as const;
export type Accent = (typeof ACCENTS)[number];
