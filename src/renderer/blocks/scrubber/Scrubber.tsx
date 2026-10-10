"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Chip } from "@/design-system/primitives/Chip";
import { renderTemplate, type TemplateValues } from "../../template";
import { useShell } from "../../ExperienceShell";
import { UI } from "../../ui-strings";
import { classes, type BlockProps } from "../../types";
import { PLOT, chartHeight, interpolateRow, lerp, periodicSplinePath, signed, xFor, yFor } from "./geometry";
import s from "./scrubber.module.css";

const TWEEN_MS = 1500;

export function ScrubberBlock({ block, ctx }: BlockProps<"scrubber-chart">) {
  const ds = ctx.datasets.get(block.datasetId);
  if (!ds) throw new Error(`dataset '${block.datasetId}' missing`); // unreachable for validated content
  const n = ds.steps.length;
  const last = n - 1;
  const { setWarm } = useShell();

  const initial = Math.max(0, ds.groups.findIndex((g) => g.id === block.groupSelector.initialGroupId));
  const [gi, setGi] = useState(initial);
  const [pos, setPosState] = useState(0);
  const posRef = useRef(0);
  const [answer, setAnswer] = useState<{ id: string; ok: boolean } | null>(null);
  const [width, setWidth] = useState(600);
  const wrap = useRef<HTMLDivElement>(null);
  const raf = useRef(0);

  const setPos = useCallback((v: number) => { posRef.current = v; setPosState(v); }, []);
  const stop = useCallback(() => cancelAnimationFrame(raf.current), []);
  useEffect(() => stop, [stop]);

  useEffect(() => {
    const el = wrap.current;
    if (!el) return;
    const measure = () => setWidth(Math.max(300, Math.round(el.getBoundingClientRect().width) || 300));
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const tweenTo = (target: number) => {
    stop();
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return setPos(target);
    const from = posRef.current;
    let t0 = -1;
    const step = (t: number) => {
      if (t0 < 0) t0 = t;
      const k = Math.min(1, (t - t0) / TWEEN_MS);
      setPos(from + (target - from) * (1 - Math.pow(1 - k, 3)));
      if (k < 1) raf.current = requestAnimationFrame(step);
    };
    raf.current = requestAnimationFrame(step);
  };

  const group = ds.groups[gi]!;
  const rows = ds.values[group.id]!;
  const dv = ds.derived[group.id]!;
  const idx = Math.round(pos);
  const lo = Math.min(last, Math.floor(pos)), hiI = Math.min(last, lo + 1), f = pos - lo;
  const here = dv[idx]!, first = dv[0]!, end = dv[last]!;
  const hi = lerp(dv[lo]!.high, dv[hiI]!.high, f);
  const low = lerp(dv[lo]!.low, dv[hiI]!.low, f);
  const warm = lerp(dv[lo]!.warm, dv[hiI]!.warm, f);
  const near = pos / last < 0.04;
  const label = (id: string) => ds.groups.find((g) => g.id === id)?.label ?? id;
  const step = ds.steps[idx]!;

  useEffect(() => { if (block.themeBinding === "warmth") setWarm(warm); }, [block.themeBinding, warm, setWarm]);
  useEffect(() => () => { if (block.themeBinding === "warmth") setWarm(0); }, [block.themeBinding, setWarm]);

  const values: TemplateValues = { group: group.label, step, lastStep: ds.steps[last]!, match: label(here.match) };
  const revealValues: TemplateValues = { ...values, step: ds.steps[last]!, match: label(end.match) };

  const H = chartHeight(width);
  const { yMin, yMax, yTicks, valueSuffix } = block.chart;
  const periods = ds.periods;
  const xs = periods.map((_, i) => xFor(i, periods.length, width));
  const path = (row: readonly number[]) => periodicSplinePath(xs, row.map((v) => yFor(v, H, yMin, yMax)));
  const nowRow = interpolateRow(rows, pos);
  const matchRow = ds.values[here.match]![0]!;
  const baseline = H - PLOT.bottom;
  const hiStat = block.stats.find((x) => x.kind === "high");
  const hiLabel = hiStat ? hiStat.label.charAt(0).toUpperCase() + hiStat.label.slice(1) : "";

  const chooseGroup = (i: number) => { stop(); setGi(i); setPos(0); setAnswer(null); };
  const predicted = block.prediction;

  return (
    <div className={s.root} ref={wrap}>
      <div className={s.rail} role="group" aria-label={block.groupSelector.label}>
        {ds.groups.map((g, i) => (
          <Chip key={g.id} pressed={i === gi} onClick={() => chooseGroup(i)}>{g.label}</Chip>
        ))}
      </div>

      {predicted && (
        <div className={s.guess}>
          <p>{renderTemplate(predicted.question, values)}</p>
          <div className={s.opts}>
            {(predicted.optionsByGroup[group.id] ?? []).map((id) => (
              <button
                key={id}
                type="button"
                className={classes(s.opt, answer?.id === id && (answer.ok ? s.ok : s.no))}
                onClick={() => { setAnswer({ id, ok: id === end.match }); tweenTo(last); }}
              >
                {label(id)}
              </button>
            ))}
          </div>
          <p className={s.res} aria-live="polite">
            {answer && (
              <>
                {answer.ok ? predicted.correctPrefix : predicted.wrongPrefix} {renderTemplate(predicted.reveal, revealValues)}
              </>
            )}
          </p>
        </div>
      )}

      <div className={s.hdr}>
        <div className={s.year} aria-hidden="true">{step}</div>
        <p className={s.headline} aria-live="polite">
          {renderTemplate(near ? block.headline.atFirstStep : block.headline.later, values)}
        </p>
      </div>

      <div className={s.slider}>
        <label htmlFor={`${block.id}-range`}>
          {block.stepControl.label} <output htmlFor={`${block.id}-range`}>{step}</output>
        </label>
        <input
          id={`${block.id}-range`}
          type="range"
          min={0}
          max={last}
          step={1}
          value={idx}
          aria-valuetext={String(step)}
          onChange={(e) => { stop(); setPos(Number(e.target.value)); }}
        />
      </div>

      <svg
        className={s.chart}
        viewBox={`0 0 ${width} ${H}`}
        role="img"
        aria-label={UI.chartLabel(group.label, block.chart.title, hiLabel, first.high.toFixed(1), step, hi.toFixed(1))}
      >
        {yTicks.map((t) => {
          const y = yFor(t, H, yMin, yMax);
          return (
            <g key={t}>
              <line className={s.grid} x1={PLOT.left} x2={width} y1={y.toFixed(1)} y2={y.toFixed(1)} />
              <text className={s.tick} x={PLOT.left - 6} y={(y + 4).toFixed(1)}>{t}{valueSuffix}</text>
            </g>
          );
        })}
        <path className={s.area} d={`${path(nowRow)}L${width - PLOT.right} ${baseline}L${PLOT.left} ${baseline}Z`} />
        {!near && <path className={s.lineMatch} d={path(matchRow)} />}
        <path className={s.lineFirst} d={path(rows[0]!)} />
        <path className={s.lineNow} d={path(nowRow)} />
        {periods.map((p, i) => (
          <text key={p} className={s.month} x={xs[i]!.toFixed(1)} y={H - 6}>{p.charAt(0)}</text>
        ))}
      </svg>

      <ul className={s.legend}>
        <li><i className={s.keyFirst} />{renderTemplate(block.legend.first, values)}</li>
        <li><i className={s.keyNow} />{renderTemplate(block.legend.now, values)}</li>
        {!near && <li><i className={s.keyMatch} />{renderTemplate(block.legend.match, values)}</li>}
      </ul>

      <div className={s.stats}>
        {block.stats.map((st) => {
          if (st.kind === "category") {
            const changed = here.category !== first.category;
            return (
              <div key={st.kind} className={s.stat}>
                <b>{here.category}</b>
                <small>{st.label}{changed ? `${st.changedFrom} ${first.category}` : ""}</small>
              </div>
            );
          }
          const now = st.kind === "high" ? hi : low;
          const base = st.kind === "high" ? first.high : first.low;
          return (
            <div key={st.kind} className={s.stat}>
              <b>{now.toFixed(1)}{valueSuffix}</b>
              <small>{st.label} ({signed(now - base)})</small>
            </div>
          );
        })}
      </div>

      <ul className={s.noJs}>
        {ds.groups.map((g) => (
          <li key={g.id}>{UI.noJsMatches(g.label, ds.steps[last]!, label(ds.derived[g.id]![last]!.match))}</li>
        ))}
      </ul>
    </div>
  );
}

