import Link from "next/link";
import { UI } from "./ui-strings";
import s from "./ExperienceView.module.css";

export interface NextExperience {
  slug: string;
  title: string;
  summary: string;
}

/**
 * The end of an experience: where the reader goes next. The "next" experience is chosen by platform policy
 * (see content/site/promotion.ts), never by content, and is null when nothing may be offered.
 */
export function EndState({ next }: { next: NextExperience | null }) {
  return (
    <section className={s.end} aria-labelledby="end-title">
      <div className={s.wrap}>
        <h2 id="end-title">{UI.end.heading}</h2>
        {next ? (
          <Link className={s.next} href={`/experiences/${next.slug}`}>
            <small>{UI.end.next}</small>
            <b>{next.title}</b>
            <span>{next.summary}</span>
          </Link>
        ) : (
          <Link className={s.next} href="/">
            <b>{UI.end.home}</b>
          </Link>
        )}
        <p className={s.endLinks}>
          <a href="#main">{UI.end.top}</a>
        </p>
      </div>
    </section>
  );
}
