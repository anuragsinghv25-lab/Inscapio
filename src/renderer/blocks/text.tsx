import { UI } from "../ui-strings";
import { RichText } from "../RichText";
import { classes, type BlockProps } from "../types";
import d from "./disclosure.module.css";
import s from "./text.module.css";

export function ParagraphBlock({ block, ctx }: BlockProps<"paragraph">) {
  return (
    <p className={classes(block.variant === "lead" && s.lead)}>
      <RichText nodes={block.content} ctx={ctx} />
    </p>
  );
}

export function CalloutBlock({ block, ctx }: BlockProps<"callout">) {
  return (
    <p className={s.say}>
      <RichText nodes={block.content} ctx={ctx} />
    </p>
  );
}

export function CardBlock({ block, ctx }: BlockProps<"card">) {
  return (
    <div className={s.card}>
      {block.label && (
        <>
          <strong>{block.label}</strong>{" "}
        </>
      )}
      <RichText nodes={block.content} ctx={ctx} />
    </div>
  );
}

export function FactRowBlock({ block }: BlockProps<"fact-row">) {
  return (
    <div className={s.facts}>
      {block.items.map((it) => (
        <div key={it.id} className={s.fact}>
          <b>{it.title}</b>
          {it.text}
        </div>
      ))}
    </div>
  );
}

export function DeeperBlock({ block, ctx }: BlockProps<"deeper">) {
  return (
    <div className={d.deeper}>
      <span className={d.deeperLabel}>{UI.goingDeeper}</span>
      {block.blocks.map((b) =>
        b.type === "paragraph" ? (
          <p key={b.id}><RichText nodes={b.content} ctx={ctx} /></p>
        ) : (
          <CompareTableBlock key={b.id} block={b} ctx={ctx} />
        ),
      )}
    </div>
  );
}

export function CompareTableBlock({ block }: Pick<BlockProps<"compare-table">, "block"> & { ctx?: unknown }) {
  return (
    <div className={s.tableWrap} tabIndex={0} role="region" aria-label="Table">
      <table className={s.table}>
        <thead>
          <tr>{block.columns.map((c) => <th key={c} scope="col">{c}</th>)}</tr>
        </thead>
        <tbody>
          {block.rows.map((r, i) => (
            <tr key={i}>{r.map((cell, j) => <td key={j}>{cell}</td>)}</tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function ResourceBoxBlock({ block }: BlockProps<"resource-box">) {
  return (
    <aside className={s.help}>
      <h3>{block.title}</h3>
      <p>
        {block.items.map((it, i) => (
          <span key={it.id}>
            {i > 0 && " · "}
            <b>{it.value}</b> {it.label}
            {it.detail && ` (${it.detail})`}
          </span>
        ))}
        . {block.note}
      </p>
    </aside>
  );
}

export function SourceListBlock({ block, ctx }: BlockProps<"source-list">) {
  const items = block.sourceIds.map((id) => ctx.sources.get(id)).filter((x) => x !== undefined);
  return (
    <p className={s.sources}>
      <b>{block.lead}</b>{" "}
      {items.map((src, i) => (
        <span key={src.id}>
          {src.url ? <a href={src.url} rel="noreferrer noopener">{src.citation}</a> : src.citation}
          {i < items.length - 1 ? "; " : "."}
        </span>
      ))}
    </p>
  );
}

export function DataNoteBlock({ block, ctx }: BlockProps<"data-note">) {
  return (
    <p className={s.dataNote}>
      {block.lead && (
        <>
          <b>{block.lead}</b>{" "}
        </>
      )}
      <RichText nodes={block.content} ctx={ctx} />
    </p>
  );
}
