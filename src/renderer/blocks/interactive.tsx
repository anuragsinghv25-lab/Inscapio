"use client";

import { useId, useMemo, useState } from "react";
import { Chip } from "@/design-system/primitives/Chip";
import { UI } from "../ui-strings";
import { classes, type BlockProps } from "../types";
import s from "./interactive.module.css";

/* ------------------------------ claims ------------------------------ */
export function ClaimsBlock({ block }: BlockProps<"claims">) {
  const [filter, setFilter] = useState<string>("all");
  const [open, setOpen] = useState<ReadonlySet<string>>(new Set());
  const shown = useMemo(() => block.items.filter((i) => filter === "all" || i.theme === filter), [block.items, filter]);
  const toggle = (id: string) => setOpen((o) => { const n = new Set(o); if (n.has(id)) n.delete(id); else n.add(id); return n; });
  return (
    <div data-accent={block.accent}>
      <div className={s.chips} role="group">
        <Chip pressed={filter === "all"} onClick={() => setFilter("all")}>{block.allLabel}</Chip>
        {block.themes.map((t) => (
          <Chip key={t.id} pressed={filter === t.id} onClick={() => setFilter(t.id)}>{t.label}</Chip>
        ))}
      </div>
      <div>
        {shown.map((it) => (
          <button key={it.id} type="button" className={s.flip} aria-expanded={open.has(it.id)} onClick={() => toggle(it.id)}>
            <span className={s.q} data-label={block.label}>{it.claim}</span>
            <span className={s.hint}>{block.hint}</span>
            <span className={s.a}>{it.response}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

/* ------------------------------ classify ------------------------------ */
export function ClassifyBlock({ block }: BlockProps<"classify">) {
  const [index, setIndex] = useState(0);
  const [score, setScore] = useState(0);
  const [feedback, setFeedback] = useState("");
  const total = block.items.length;
  const done = index >= total;
  const item = block.items[index];
  const answer = (categoryId: string) => {
    if (!item) return;
    const ok = categoryId === item.answer;
    if (ok) setScore((v) => v + 1);
    setFeedback(`${ok ? UI.correct : UI.notQuite} ${item.feedback}`);
    setIndex((i) => i + 1);
  };
  return (
    <div className={s.sort}>
      <div className={s.statement}>
        {done ? `${UI.scoreLine(score, total)} ${block.closing}` : item ? `"${item.text}"` : null}
      </div>
      {!done &&
        block.categories.map((c) => (
          <button key={c.id} type="button" className={s.answer} data-accent={c.accent} onClick={() => answer(c.id)}>
            {c.label}
          </button>
        ))}
      <div className={s.feedback} aria-live="polite">{feedback}</div>
      <div><small className={s.counter}>{done ? "" : UI.questionOf(index + 1, total)}</small></div>
      <ul className={s.noJs}>
        {block.items.map((it) => (
          <li key={it.id}>
            &quot;{it.text}&quot; — {block.categories.find((c) => c.id === it.answer)?.label}. {it.feedback}
          </li>
        ))}
      </ul>
    </div>
  );
}

/* ------------------------------ selector-content ------------------------------ */
export function SelectorContentBlock({ block }: BlockProps<"selector-content">) {
  const uid = useId();
  const [id, setId] = useState(block.defaultOptionId ?? block.options[0]?.id);
  const current = block.options.find((o) => o.id === id);
  return (
    <div>
      {block.label && <p id={`${uid}-l`}>{block.label}</p>}
      <div className={s.chips} role="group" aria-labelledby={block.label ? `${uid}-l` : undefined}>
        {block.options.map((o) => (
          <Chip key={o.id} pressed={o.id === id} onClick={() => setId(o.id)}>{o.label}</Chip>
        ))}
      </div>
      <div className={classes(s.out)} aria-live="polite">{current?.content}</div>
      <dl className={s.noJsAll}>
        {block.options.map((o) => (
          <div key={o.id}><dt><b>{o.label}</b></dt><dd>{o.content}</dd></div>
        ))}
      </dl>
    </div>
  );
}
