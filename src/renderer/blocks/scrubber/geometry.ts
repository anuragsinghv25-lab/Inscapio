/** Pure chart geometry for the scrubber block. No React, no DOM: unit-testable. */

export const PLOT = { left: 34, right: 8, bottom: 26, top: 24 } as const;

export const chartHeight = (width: number) => (width < 560 ? 300 : 270);

export const yFor = (value: number, height: number, yMin: number, yMax: number, bottom: number = PLOT.bottom, top: number = PLOT.top) =>
  height - bottom - ((value - yMin) / (yMax - yMin)) * (height - bottom - top);

export const xFor = (i: number, count: number, width: number, left: number = PLOT.left) =>
  left + (i / (count - 1)) * (width - left - PLOT.right);

/** Linear blend of two dataset rows. `pos` is a fractional step index. */
export function interpolateRow(rows: readonly (readonly number[])[], pos: number): number[] {
  const lo = Math.max(0, Math.min(rows.length - 1, Math.floor(pos)));
  const hi = Math.min(rows.length - 1, lo + 1);
  const f = Math.max(0, Math.min(1, pos - lo));
  const a = rows[lo] as readonly number[];
  const b = rows[hi] as readonly number[];
  return a.map((v, i) => v + ((b[i] as number) - v) * f);
}

export const lerp = (a: number, b: number, f: number) => a + (b - a) * f;

/**
 * Smooth closed-period curve through one value per period (e.g. 12 months).
 * Catmull-Rom converted to cubic Béziers. The series is cyclic (December flows into January),
 * so the ghost points before the first and after the last are the opposite ends of the same series.
 */
export function periodicSplinePath(xs: readonly number[], ys: readonly number[]): string {
  const n = ys.length;
  const at = (i: number): [number, number] => {
    if (i < 0) return [(xs[0] as number) - ((xs[1] as number) - (xs[0] as number)), ys[n - 1] as number];
    if (i >= n) return [(xs[n - 1] as number) + ((xs[n - 1] as number) - (xs[n - 2] as number)), ys[0] as number];
    return [xs[i] as number, ys[i] as number];
  };
  const f = (v: number) => v.toFixed(1);
  let d = `M${f(xs[0] as number)} ${f(ys[0] as number)}`;
  for (let i = 0; i < n - 1; i++) {
    const [x0, y0] = at(i - 1), [x1, y1] = at(i), [x2, y2] = at(i + 1), [x3, y3] = at(i + 2);
    d += `C${f(x1 + (x2 - x0) / 6)} ${f(y1 + (y2 - y0) / 6)} ${f(x2 - (x3 - x1) / 6)} ${f(y2 - (y3 - y1) / 6)} ${f(x2)} ${f(y2)}`;
  }
  return d;
}

/** Signed one-decimal delta, as v0 prints it: "+1.2", "-0.4", "+0.0" is shown as "0.0" below .05. */
export const signed = (v: number) => (v >= 0.05 ? "+" : "") + v.toFixed(1);
