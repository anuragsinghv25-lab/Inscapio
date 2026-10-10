"use client";

import { useId, useState } from "react";
import s from "./pages.module.css";

export function GoDeeper({ lead, open, close, body }: { lead: string; open: string; close: string; body: string }) {
  const id = useId();
  const [on, setOn] = useState(false);
  return (
    <div className={s.gd}>
      <p>{lead}</p>
      <button type="button" aria-expanded={on} aria-controls={id} onClick={() => setOn((v) => !v)}>{on ? close : open}</button>
      <div className={s.more} id={id} hidden={!on}><p>{body}</p></div>
    </div>
  );
}
