"use client";

import { useId, useState } from "react";
import { classes, type BlockProps } from "../types";
import s from "./disclosure.module.css";

export function AccordionBlock({ block }: BlockProps<"accordion">) {
  const uid = useId();
  const [open, setOpen] = useState<ReadonlySet<string>>(new Set());
  const toggle = (id: string) => setOpen((o) => { const n = new Set(o); if (n.has(id)) n.delete(id); else n.add(id); return n; });
  const bands = block.variant === "bands";
  return (
    <div className={classes(s.accordion, bands && s.bands)} role="group">
      {block.items.map((it) => {
        const isOpen = open.has(it.id);
        const panelId = `${uid}-${it.id}`;
        return (
          <div key={it.id} className={classes(s.item, isOpen && s.open)} data-accent={it.accent}>
            <button type="button" className={s.trigger} aria-expanded={isOpen} aria-controls={panelId} onClick={() => toggle(it.id)}>
              <span>{it.title}</span>
              {bands && <i className={s.sign} aria-hidden="true">{isOpen ? "−" : "+"}</i>}
            </button>
            <div className={s.panel}>
              <div className={s.panelInner} id={panelId}>
                <p>{it.body}</p>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

export function StepperBlock({ block }: BlockProps<"stepper">) {
  const [at, setAt] = useState(-1);
  return (
    <div className={s.steps} data-accent={block.accent}>
      {block.steps.map((st, i) => (
        <button
          key={st.id}
          type="button"
          className={classes(s.step, i <= at && s.on, i === at && s.current)}
          aria-expanded={i === at}
          onClick={() => setAt(i)}
        >
          {st.title}
          <span className={s.note}>{st.note}</span>
        </button>
      ))}
    </div>
  );
}
