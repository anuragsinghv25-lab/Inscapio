"use client";

import { useId, useRef, useState } from "react";
import { UI } from "@/renderer/ui-strings";
import s from "./FeedbackForm.module.css";

const STORE_KEY = "inscapio"; // same key as v0, so earlier answers on a device are kept

/**
 * v0 behaviour, unchanged: answers are saved to this device's localStorage and copied to the clipboard.
 * They are NOT sent anywhere (a known gap, tracked in docs/OPEN-QUESTIONS.md).
 */
export function FeedbackForm({ slug, title }: { slug: string; title: string }) {
  const uid = useId();
  const F = UI.feedback;
  const answers = useRef<Record<string, string>>({});
  const [pressed, setPressed] = useState<Record<string, string>>({});
  const [message, setMessage] = useState("");

  const pick = (id: string, v: string) => {
    answers.current[id] = v;
    setPressed((p) => ({ ...p, [id]: v }));
  };

  const send = () => {
    const a = answers.current;
    if (!Object.keys(a).length) return setMessage(F.addAnswer);
    const text = `InScapio feedback — ${title}\n` + Object.entries(a).map(([k, v]) => `${k}: ${v}`).join("\n");
    try {
      const list = JSON.parse(localStorage.getItem(STORE_KEY) || "[]") as unknown[];
      list.push({ key: slug, ...a });
      localStorage.setItem(STORE_KEY, JSON.stringify(list));
    } catch {}
    const copy = navigator.clipboard ? navigator.clipboard.writeText(text) : Promise.reject(new Error("no clipboard"));
    copy.then(() => setMessage(F.copied), () => setMessage(F.saved));
  };

  const share = () => {
    const url = `${location.origin}/experiences/${slug}`;
    if (navigator.share) navigator.share({ title: `InScapio: ${title}`, text: F.shareText, url }).catch(() => {});
    else if (navigator.clipboard) navigator.clipboard.writeText(url).then(() => setMessage(F.linkCopied), () => setMessage(url));
  };

  return (
    <section className={s.root} aria-label="Feedback" data-on-dark>
      <div className={s.inner}>
        <h2>{F.title}</h2>
        <p>{F.lede}</p>
        {F.questions.map((q) => (
          <div key={q.id} className={s.q} role="group" aria-labelledby={`${uid}-${q.id}`}>
            <h3 id={`${uid}-${q.id}`}>{q.q}</h3>
            <div className={s.options}>
              {q.options.map((o) => (
                <button key={o} type="button" aria-pressed={pressed[q.id] === o} onClick={() => pick(q.id, o)}>{o}</button>
              ))}
            </div>
            {"ends" in q && (
              <p className={s.ends}><span>{q.ends[0]}</span><span>{q.ends[1]}</span></p>
            )}
          </div>
        ))}
        {F.texts.map((t) => (
          <div key={t.id} className={s.text}>
            <label htmlFor={`${uid}-${t.id}`}>{t.q}</label>
            <textarea id={`${uid}-${t.id}`} rows={3} onChange={(e) => { answers.current[t.id] = e.target.value; }} />
          </div>
        ))}
        <div className={s.actions}>
          <button type="button" className={s.send} onClick={send}>{F.send}</button>
          <button type="button" onClick={share}>{F.share}</button>
        </div>
        <p className={s.message} role="status">{message}</p>
      </div>
    </section>
  );
}
