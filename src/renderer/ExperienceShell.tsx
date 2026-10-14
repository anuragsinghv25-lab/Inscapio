"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react";
import Link from "next/link";
import type { ReadingControl, Theme } from "@/content/schema/presentation";
import { UI } from "./ui-strings";
import { readPrefs, writePrefs } from "./readingPrefs";
import { SectionsMenu } from "./SectionsMenu";
import type { OutlineItem } from "./outline";
import s from "./ExperienceShell.module.css";

interface ShellApi {
  /** Data-bound themes (0..1, cool to warm). Written by the scrubber block. */
  setWarm: (v: number) => void;
}
const ShellContext = createContext<ShellApi>({ setWarm: () => {} });
export const useShell = () => useContext(ShellContext);

const FS_MIN = 15, FS_MAX = 26, FS_DEFAULT = 19, FS_STEP = 2;
const FS_BOUNDS = { min: FS_MIN, max: FS_MAX };
/** Experiences with at least this many sections get a Sections control in the bar. */
const MENU_MIN_SECTIONS = 4;
export const ORIGIN_KEY = "inscapio:origin";

interface Props {
  theme: Theme;
  controls: readonly ReadingControl[];
  title: string;
  outline: readonly OutlineItem[];
  children: ReactNode;
}

/**
 * Reading chrome and reading state (Deeper, text size, light/dark) for one experience.
 * Content arrives as server-rendered `children`; this component only owns presentation state,
 * which it exposes as data attributes so block styles can respond in CSS.
 */
export function ExperienceShell({ theme, controls, title, outline, children }: Props) {
  const [deeper, setDeeper] = useState(false);
  const [fs, setFs] = useState(FS_DEFAULT);
  const [mode, setMode] = useState<"light" | "dark" | undefined>(undefined);
  const [warm, setWarmState] = useState(0);
  const root = useRef<HTMLDivElement>(null);
  const progress = useRef<HTMLDivElement>(null);
  const setWarm = useCallback((v: number) => setWarmState(v), []);
  const api = useMemo(() => ({ setWarm }), [setWarm]);

  // Restore this reader's saved preferences (only for the controls this experience offers).
  useEffect(() => {
    queueMicrotask(() => {
      const p = readPrefs(FS_BOUNDS);
      if (controls.includes("deeper") && p.deeper !== undefined) setDeeper(p.deeper);
      if (controls.includes("text-size") && p.fs !== undefined) setFs(p.fs);
      if (controls.includes("theme") && p.mode !== undefined) setMode(p.mode);
    });
  }, [controls]);

  // Circular reveal from the tap point that opened this experience (v0 behaviour); skipped for reduced motion.
  useEffect(() => {
    let raw: string | null = null;
    try {
      raw = sessionStorage.getItem(ORIGIN_KEY);
      sessionStorage.removeItem(ORIGIN_KEY);
    } catch {}
    if (!raw || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const el = root.current;
    if (!el) return;
    try {
      const { x, y } = JSON.parse(raw) as { x: string; y: string };
      el.style.setProperty("--ox", x);
      el.style.setProperty("--oy", y);
      el.classList.add(s.entering!);
      el.addEventListener("animationend", () => el.classList.remove(s.entering!), { once: true });
    } catch {}
  }, []);

  useEffect(() => {
    let tick = false;
    const update = () => {
      tick = false;
      const h = document.documentElement.scrollHeight - innerHeight;
      const p = h > 0 ? Math.min(1, scrollY / h) : 0;
      if (progress.current) progress.current.style.transform = `scaleX(${p})`;
    };
    const onScroll = () => {
      if (tick) return;
      tick = true;
      requestAnimationFrame(update);
    };
    update();
    addEventListener("scroll", onScroll, { passive: true });
    return () => removeEventListener("scroll", onScroll);
  }, []);

  const toggleTheme = () => {
    const dark = mode ? mode === "dark" : matchMedia("(prefers-color-scheme: dark)").matches;
    const next = dark ? "light" : "dark";
    setMode(next);
    writePrefs({ mode: next }, FS_BOUNDS);
  };
  const changeFs = (delta: number) => {
    const next = Math.min(FS_MAX, Math.max(FS_MIN, fs + delta));
    setFs(next);
    writePrefs({ fs: next }, FS_BOUNDS);
  };
  const toggleDeeper = () => {
    setDeeper(!deeper);
    writePrefs({ deeper: !deeper }, FS_BOUNDS);
  };
  const style: CSSProperties & Record<string, string> = {};
  if (controls.includes("text-size")) style["--fs"] = `${fs}px`;
  if (theme === "tarn") style["--warm"] = warm.toFixed(3);

  return (
    <ShellContext.Provider value={api}>
      <div
        id="experience-root"
        ref={root}
        className={s.root}
        data-theme={theme}
        data-mode={mode}
        data-deeper={deeper}
        style={style}
      >
        <nav className={s.bar} aria-label={UI.experienceControls}>
          <Link className={s.back} href="/" aria-label={UI.backToHome}>
            {UI.siteName}
          </Link>
          <b className={s.title}>{title}</b>
          {outline.length >= MENU_MIN_SECTIONS && <SectionsMenu items={outline} />}
          {controls.includes("deeper") && (
            <button type="button" className={s.btn} aria-pressed={deeper} title={UI.deeperTitle} onClick={toggleDeeper}>
              {deeper ? UI.simple : UI.deeper}
            </button>
          )}
          {controls.includes("text-size") && (
            <>
              <button type="button" className={s.btn} title={UI.biggerText} aria-label={UI.biggerText} onClick={() => changeFs(FS_STEP)}>
                A+
              </button>
              <button type="button" className={s.btn} title={UI.smallerText} aria-label={UI.smallerText} onClick={() => changeFs(-FS_STEP)}>
                A-
              </button>
            </>
          )}
          {controls.includes("theme") && (
            <button type="button" className={s.btn} title={UI.switchTheme} aria-label={UI.switchTheme} onClick={toggleTheme}>
              <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
                <circle cx="9" cy="9" r="7" fill="none" stroke="currentColor" strokeWidth="2" />
                <path d="M9 2a7 7 0 0 0 0 14z" fill="currentColor" />
              </svg>
            </button>
          )}
        </nav>
        <div className={s.progress} ref={progress} aria-hidden="true" />
        {children}
      </div>
    </ShellContext.Provider>
  );
}
