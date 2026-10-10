import { Fragment, type ReactNode } from "react";
import type { RichText as RichTextType } from "@/content/schema/primitives";
import type { RenderContext } from "./types";

export function applyMarks(children: ReactNode, marks: readonly string[] | undefined): ReactNode {
  let out = children;
  if (marks?.includes("em")) out = <em>{out}</em>;
  if (marks?.includes("strong")) out = <strong>{out}</strong>;
  return out;
}

/** Renders the rich-text AST as React elements. Text is always a React text child: never parsed as HTML. */
export function RichText({ nodes, ctx }: { nodes: RichTextType; ctx: RenderContext }) {
  return (
    <>
      {nodes.map((n, i) => {
        if ("sourceRef" in n) {
          const src = ctx.sources.get(n.sourceRef);
          return (
            <cite key={i} data-source={n.sourceRef}>
              {src?.citation ?? n.sourceRef}
            </cite>
          );
        }
        return <Fragment key={i}>{applyMarks(n.text, n.marks)}</Fragment>;
      })}
    </>
  );
}
