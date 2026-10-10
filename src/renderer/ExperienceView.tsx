import type { Experience } from "@/content/schema";
import type { EndnoteBlock } from "@/content/schema/blocks";
import { ButtonLink } from "@/design-system/primitives/ButtonLink";
import { BlockRenderer } from "./BlockRenderer";
import { ExperienceShell } from "./ExperienceShell";
import { FeedbackForm } from "@/components/FeedbackForm";
import { DataNoteBlock, ParagraphBlock, SourceListBlock } from "./blocks/text";
import type { RenderContext } from "./types";
import s from "./ExperienceView.module.css";

function Endnote({ block, ctx }: { block: EndnoteBlock; ctx: RenderContext }) {
  switch (block.type) {
    case "paragraph": return <ParagraphBlock block={block} ctx={ctx} />;
    case "source-list": return <SourceListBlock block={block} ctx={ctx} />;
    case "data-note": return <DataNoteBlock block={block} ctx={ctx} />;
  }
}

/** Server component: turns one validated Experience into the page. The only entry point for rendering content. */
export function ExperienceView({ experience: e }: { experience: Experience }) {
  const ctx: RenderContext = {
    sources: new Map(e.sources.map((x) => [x.id, x])),
    datasets: new Map(e.datasets.map((x) => [x.id, x])),
  };
  return (
    <ExperienceShell theme={e.theme} controls={e.reading} title={e.shortTitle}>
      <main id="main" tabIndex={-1} className={s.main}>
        <header className={s.hero}>
          <div className={s.heroInner}>
            <h1 tabIndex={-1}>{e.hero.title}</h1>
            {e.hero.intro.map((t, i) => (
              <p key={i} className={s.intro}>{t}</p>
            ))}
            <div className={s.actions}>
              {e.hero.actions.map((a) => (
                <ButtonLink key={a.label} href={`#${a.targetSectionId}`} emphasis={a.emphasis}>{a.label}</ButtonLink>
              ))}
            </div>
          </div>
        </header>
        {e.sections.map((sec) => (
          <section key={sec.id} id={sec.id} className={s.section} data-accent={sec.accent} aria-labelledby={`${sec.id}-title`}>
            <div className={s.wrap}>
              {sec.kicker && <span className={s.tag}>{sec.kicker}</span>}
              <h2 id={`${sec.id}-title`}>{sec.title}</h2>
              {sec.blocks.map((b) => (
                <BlockRenderer key={b.id} block={b} ctx={ctx} />
              ))}
            </div>
          </section>
        ))}
        <FeedbackForm slug={e.slug} title={e.title} />
        {e.endnotes.length > 0 && (
          <footer className={s.endnotes}>
            <div className={s.wrap}>
              {e.endnotes.map((b) => (
                <Endnote key={b.id} block={b} ctx={ctx} />
              ))}
            </div>
          </footer>
        )}
      </main>
    </ExperienceShell>
  );
}
