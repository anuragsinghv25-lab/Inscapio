import type { Block } from "@/content/schema/blocks";
import { BlockBoundary } from "./BlockBoundary";
import type { RenderContext } from "./types";
import { AccordionBlock, StepperBlock } from "./blocks/disclosure";
import { ClaimsBlock, ClassifyBlock, SelectorContentBlock } from "./blocks/interactive";
import { ScrubberBlock } from "./blocks/scrubber/Scrubber";
import {
  CalloutBlock, CardBlock, CompareTableBlock, DataNoteBlock, DeeperBlock, FactRowBlock,
  ParagraphBlock, ResourceBoxBlock, SourceListBlock,
} from "./blocks/text";

const never = (b: never): never => {
  throw new Error(`Unhandled block: ${JSON.stringify(b)}`);
};

/**
 * The single place where a block `type` becomes a component. This is a closed, compile-time-checked
 * switch: content never selects a component by name, path or import.
 */
function renderBlock(block: Block, ctx: RenderContext) {
  switch (block.type) {
    case "paragraph": return <ParagraphBlock block={block} ctx={ctx} />;
    case "callout": return <CalloutBlock block={block} ctx={ctx} />;
    case "card": return <CardBlock block={block} ctx={ctx} />;
    case "fact-row": return <FactRowBlock block={block} ctx={ctx} />;
    case "compare-table": return <CompareTableBlock block={block} />;
    case "resource-box": return <ResourceBoxBlock block={block} ctx={ctx} />;
    case "source-list": return <SourceListBlock block={block} ctx={ctx} />;
    case "data-note": return <DataNoteBlock block={block} ctx={ctx} />;
    case "deeper": return <DeeperBlock block={block} ctx={ctx} />;
    case "accordion": return <AccordionBlock block={block} ctx={ctx} />;
    case "stepper": return <StepperBlock block={block} ctx={ctx} />;
    case "claims": return <ClaimsBlock block={block} ctx={ctx} />;
    case "classify": return <ClassifyBlock block={block} ctx={ctx} />;
    case "selector-content": return <SelectorContentBlock block={block} ctx={ctx} />;
    case "scrubber-chart": return <ScrubberBlock block={block} ctx={ctx} />;
    default: return never(block);
  }
}

export function BlockRenderer({ block, ctx }: { block: Block; ctx: RenderContext }) {
  return (
    <BlockBoundary blockId={block.id} blockType={block.type}>
      {renderBlock(block, ctx)}
    </BlockBoundary>
  );
}
