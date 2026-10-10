import type { Dataset } from "@/content/schema/dataset";
import type { Source } from "@/content/schema/sources";
import type { BlockOf, BlockType } from "@/content/schema/blocks";

/** Everything a block may need to resolve references. Built once per experience. */
export interface RenderContext {
  readonly sources: ReadonlyMap<string, Source>;
  readonly datasets: ReadonlyMap<string, Dataset>;
}
export interface BlockProps<T extends BlockType> {
  block: BlockOf<T>;
  ctx: RenderContext;
}
export const classes = (...c: (string | false | undefined)[]) => c.filter(Boolean).join(" ");
