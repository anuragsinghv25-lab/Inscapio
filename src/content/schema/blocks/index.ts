import { z } from "zod";
import { Accordion, Deeper, Stepper } from "./disclosure";
import { Claims, Classify, SelectorContent } from "./interactive";
import { ScrubberChart } from "./scrubber";
import { Callout, Card, CompareTable, DataNote, FactRow, Paragraph, ResourceBox, SourceList } from "./text";

/** The complete, closed block vocabulary. Unknown `type` values are rejected. */
export const Block = z.discriminatedUnion("type", [
  Paragraph,
  Callout,
  Card,
  FactRow,
  CompareTable,
  ResourceBox,
  SourceList,
  DataNote,
  Deeper,
  Accordion,
  Stepper,
  Claims,
  Classify,
  SelectorContent,
  ScrubberChart,
]);
export type Block = z.infer<typeof Block>;
export type BlockType = Block["type"];
export type BlockOf<T extends BlockType> = Extract<Block, { type: T }>;

/** Blocks permitted in an experience's end notes. */
export const EndnoteBlock = z.discriminatedUnion("type", [Paragraph, SourceList, DataNote]);
export type EndnoteBlock = z.infer<typeof EndnoteBlock>;

export const BLOCK_TYPES = [
  "paragraph", "callout", "card", "fact-row", "compare-table", "resource-box", "source-list", "data-note",
  "deeper", "accordion", "stepper", "claims", "classify", "selector-content", "scrubber-chart",
] as const satisfies readonly BlockType[];
