/**
 * Reading preferences (Deeper, text size, light/dark), kept on this device only.
 * Applied after hydration, so a returning reader may see the default for an instant (D-041, Q-19).
 * Every access is guarded: storage can be absent, full or blocked, and the page must work without it.
 */
export interface ReadingPrefs {
  deeper?: boolean;
  fs?: number;
  mode?: "light" | "dark";
}

export const PREFS_KEY = "inscapio:prefs";

export function readPrefs(bounds: { min: number; max: number }): ReadingPrefs {
  try {
    const raw = localStorage.getItem(PREFS_KEY);
    if (!raw) return {};
    const v = JSON.parse(raw) as Record<string, unknown>;
    const out: ReadingPrefs = {};
    if (typeof v.deeper === "boolean") out.deeper = v.deeper;
    if (typeof v.fs === "number" && Number.isFinite(v.fs)) out.fs = Math.min(bounds.max, Math.max(bounds.min, v.fs));
    if (v.mode === "light" || v.mode === "dark") out.mode = v.mode;
    return out;
  } catch {
    return {};
  }
}

export function writePrefs(patch: ReadingPrefs, bounds: { min: number; max: number }): void {
  try {
    localStorage.setItem(PREFS_KEY, JSON.stringify({ ...readPrefs(bounds), ...patch }));
  } catch {
    /* storage unavailable: the preference simply does not persist */
  }
}
