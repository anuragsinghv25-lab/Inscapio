"use client";

import { useEffect, useId, useRef, useState } from "react";
import { UI } from "./ui-strings";
import type { OutlineItem } from "./outline";
import s from "./ExperienceShell.module.css";

/** Sections control in the experience bar: a disclosure of anchor links with the current section marked. */
export function SectionsMenu({ items }: { items: readonly OutlineItem[] }) {
  const uid = useId();
  const [open, setOpen] = useState(false);
  const [current, setCurrent] = useState<string | null>(null);
  const root = useRef<HTMLDivElement>(null);
  const button = useRef<HTMLButtonElement>(null);

  const close = (returnFocus: boolean) => {
    setOpen(false);
    if (returnFocus) button.current?.focus();
  };

  const toggle = () => {
    if (!open) {
      // The current section is the last one whose top has passed about a third of the way down the screen.
      let id: string | null = null;
      for (const it of items) {
        const el = document.getElementById(it.id);
        if (el && el.getBoundingClientRect().top <= innerHeight * 0.35) id = it.id;
      }
      setCurrent(id);
    }
    setOpen(!open);
  };

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") close(true); };
    const onPointer = (e: PointerEvent) => { if (root.current && !root.current.contains(e.target as Node)) setOpen(false); };
    document.addEventListener("keydown", onKey);
    document.addEventListener("pointerdown", onPointer);
    root.current?.querySelector<HTMLElement>("[aria-current]")?.scrollIntoView({ block: "nearest" });
    return () => { document.removeEventListener("keydown", onKey); document.removeEventListener("pointerdown", onPointer); };
  }, [open]);

  return (
    <div ref={root} className={s.sectionsWrap}>
      <button
        ref={button} type="button" className={s.btn} aria-expanded={open} aria-controls={`${uid}-panel`}
        title={UI.sections} aria-label={UI.sections} onClick={toggle}
      >
        <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
          <path d="M2 4h14M2 9h14M2 14h14" fill="none" stroke="currentColor" strokeWidth="2" />
        </svg>
      </button>
      <nav id={`${uid}-panel`} className={s.sectionsPanel} aria-label={UI.sectionsNav} hidden={!open}>
        <ol>
          {items.map((it) => (
            <li key={it.id}>
              <a href={`#${it.id}`} aria-current={it.id === current ? "location" : undefined} onClick={() => setOpen(false)}>
                <span>{it.label}</span>
                {it.label !== it.title && <small>{it.title}</small>}
              </a>
            </li>
          ))}
        </ol>
      </nav>
    </div>
  );
}
