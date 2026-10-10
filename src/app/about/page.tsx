import type { Metadata } from "next";
import Link from "next/link";
import { ABOUT } from "@/content/site/pages";
import { GoDeeper } from "@/components/GoDeeper";
import { SiteNav } from "@/components/SiteChrome";
import s from "@/components/pages.module.css";

export const metadata: Metadata = { title: ABOUT.title };

export default function AboutPage() {
  return (
    <div className={s.aboutPage} data-on-dark>
      <SiteNav onDark />
      <main id="main" tabIndex={-1} className={s.view}>
        <article className={s.ab}>
          <h1 tabIndex={-1}>{ABOUT.title}</h1>
          <div className={s.prose}>
            {ABOUT.prose.map((p) => (
              <p key={p.text} className={"emphasis" in p ? s.q : undefined}>{p.text}</p>
            ))}
          </div>
          <GoDeeper {...ABOUT.deeper} />
          <p className={s.fin}><span>{ABOUT.finale.light}</span>{ABOUT.finale.strong}</p>
          <Link className={s.ulink} href="/#rooms">{ABOUT.link}</Link>
        </article>
      </main>
    </div>
  );
}
