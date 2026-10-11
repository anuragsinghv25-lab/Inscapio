"use client";

import { useEffect, useRef, useState } from "react";
import { HOME } from "@/content/site/pages";
import { periodicSplinePath, xFor, yFor } from "@/renderer/blocks/scrubber/geometry";
import s from "../pages.module.css";

interface Props {
  group: string;
  match: string;
  today: readonly number[];
  future: readonly number[];
  matchToday: readonly number[];
}

/** Value the server renders for the slider; narrow screens rest here, wide ones adjust on mount. */
const REST_SERVER = 100;
const W = 600, H = 220, LO = 2, HI = 32, B = 6, T = 6;

/** Home opening: the same idea as text on the left and as a chart on the right, with a draggable wipe between. */
export function ReadExploreStrip({ group, match, today, future, matchToday }: Props) {
  const copy = HOME.strip;
  // null = untouched: the stylesheet decides where the wipe rests (see .strip in pages.module.css).
  const [v, setV] = useState<number | null>(null);
  const raf = useRef(0);

  useEffect(() => {
    const to = matchMedia("(min-width: 900px)").matches ? 50 : 100;
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) {
      raf.current = requestAnimationFrame(() => setV(to));
      return () => cancelAnimationFrame(raf.current);
    }
    raf.current = requestAnimationFrame(() => setV(0));
    const timer = setTimeout(() => {
      const from = 0;
      let t0 = -1;
      const step = (t: number) => {
        if (t0 < 0) t0 = t;
        const k = Math.min(1, (t - t0) / 1700);
        setV(from + (to - from) * (1 - Math.pow(1 - k, 3)));
        if (k < 1) raf.current = requestAnimationFrame(step);
      };
      raf.current = requestAnimationFrame(step);
    }, 900);
    return () => { clearTimeout(timer); cancelAnimationFrame(raf.current); };
  }, []);

  const xs = today.map((_, i) => xFor(i, today.length, W, 0));
  const path = (row: readonly number[]) => periodicSplinePath(xs, row.map((x) => yFor(x, H, LO, HI, B, T)));
  const shown = v ?? REST_SERVER;
  const text = shown < 15 ? copy.valueText.reading : shown > 85 ? copy.valueText.exploring : copy.valueText.mixed;

  return (
    <>
      <div className={s.ctl}>
        <label htmlFor="wipe">{copy.sliderLabel}</label>
        <div className={s.row}>
          <span>{copy.readEnd}</span>
          <input
            id="wipe" className={s.rng} type="range" min={0} max={100} value={Math.round(shown)} aria-valuetext={text}
            onChange={(e) => { cancelAnimationFrame(raf.current); setV(Number(e.target.value)); }}
          />
          <span>{copy.exploreEnd}</span>
        </div>
      </div>
      <div className={s.strip} style={v === null ? undefined : { ["--v" as string]: `${v}%` }} role="group" aria-label={copy.label}>
        <div className={s.read}>
          <div className={s.art}>
            <h2>{copy.readHeading}</h2>
            {copy.readParagraphs.map((p) => <p key={p}>{p}</p>)}
          </div>
        </div>
        <div className={s.exp}>
          <p className={s.hl}>{group}{HOME.analogue.mid}<b>{match}</b>{HOME.analogue.end}</p>
          <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" role="img" aria-label={copy.chartLabel}>
            <path className={s.area} d={`${path(future)}L${W - 8} ${H}L0 ${H}Z`} />
            <path className={s.lMatch} d={path(matchToday)} />
            <path className={s.lFirst} d={path(today)} />
            <path className={s.lNow} d={path(future)} />
          </svg>
          <ul className={s.lg}>
            <li><i className={s.kFirst} />{group} {copy.legend.today}</li>
            <li><i className={s.kNow} />{group} {copy.legend.future}</li>
            <li><i className={s.kMatch} />{match} {copy.legend.today}</li>
          </ul>
        </div>
        <div className={s.rule} aria-hidden="true" />
      </div>
    </>
  );
}
