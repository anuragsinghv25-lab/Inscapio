"use client";

import { useId, useState } from "react";
import { HOME } from "@/content/site/pages";
import s from "../pages.module.css";

export function CityWall({ cities }: { cities: readonly { id: string; label: string; match: string }[] }) {
  const uid = useId();
  const [id, setId] = useState<string | null>(null);
  const current = cities.find((c) => c.id === id);
  return (
    <>
      <p className={s.rh} id={`${uid}-h`}>{HOME.rooms.climate.prompt}</p>
      <div className={s.wall} role="group" aria-labelledby={`${uid}-h`}>
        {cities.map((c) => (
          <button key={c.id} type="button" aria-pressed={c.id === id} onClick={() => setId(c.id)}>{c.label}</button>
        ))}
      </div>
      <p className={s.wans} aria-live="polite">
        {current ? <>{current.label}{HOME.analogue.mid}<b>{current.match}</b>{HOME.analogue.end}</> : HOME.rooms.climate.idle}
      </p>
      <p className={s.note}>{HOME.rooms.climate.note}</p>
    </>
  );
}
