import Link from "next/link";
import { loadExperience } from "@/content/load";
import { HOME } from "@/content/site/pages";
import { CityWall } from "@/components/home/CityWall";
import { ReadExploreStrip } from "@/components/home/ReadExploreStrip";
import { EnterLink } from "@/components/EnterLink";
import { SiteFooter, SiteNav } from "@/components/SiteChrome";
import { AccordionBlock } from "@/renderer/blocks/disclosure";
import type { RenderContext } from "@/renderer/types";
import s from "@/components/pages.module.css";

export default function HomePage() {
  const climate = loadExperience("climate");
  const body = loadExperience("whose-body-is-it");
  const ds = climate.datasets[0]!;
  const last = ds.steps.length - 1;
  const label = (id: string) => ds.groups.find((g) => g.id === id)?.label ?? id;
  const at = (id: string) => ({ values: ds.values[id]!, end: ds.derived[id]![last]! });

  const madrid = at("madrid");
  const wall = HOME.wallCities.map((id) => ({ id, label: label(id), match: label(at(id).end.match) }));

  // The layers shown on home are the same content as chapter 3 of "Whose Body Is It?", presented as bands.
  const layers = body.sections.flatMap((x) => x.blocks).find((b) => b.type === "accordion");
  const ctx: RenderContext = { sources: new Map(), datasets: new Map() };

  return (
    <>
      <SiteNav />
      <main id="main" tabIndex={-1} className={s.view}>
        <section className={s.opening} aria-labelledby="home-title">
          <h1 className={s.ttl} id="home-title" tabIndex={-1}>
            <span className={s.ttlLight}>{HOME.title.light}</span>
            <span className={s.ttlStrong}>{HOME.title.strong}</span>
          </h1>
          <p className={s.sub}>{HOME.sub}</p>
          <ReadExploreStrip
            group={label("madrid")}
            match={label(madrid.end.match)}
            today={madrid.values[0]!}
            future={madrid.values[last]!}
            matchToday={ds.values[madrid.end.match]![0]!}
          />
        </section>

        <section className={`${s.room} ${s.r1}`} id="rooms" aria-labelledby="room-body">
          <div className={s.in}>
            <div className={s.rt}>
              <h2 id="room-body">{HOME.rooms.body.heading}</h2>
              <p className={s.desc}>{HOME.rooms.body.description}</p>
              <EnterLink className={s.enter} href="/experiences/whose-body-is-it">{HOME.rooms.body.enter}</EnterLink>
            </div>
            <div className={s.rv}>
              <p className={s.rh}>{HOME.rooms.body.prompt}</p>
              {layers?.type === "accordion" && <AccordionBlock block={{ ...layers, variant: "bands" }} ctx={ctx} />}
            </div>
          </div>
        </section>

        <section className={`${s.room} ${s.r2}`} aria-labelledby="room-climate">
          <div className={s.in}>
            <div className={s.rv}>
              <CityWall cities={wall} />
            </div>
            <div className={s.rt}>
              <h2 id="room-climate">{HOME.rooms.climate.heading}</h2>
              <p className={s.desc}>{HOME.rooms.climate.description}</p>
              <EnterLink className={s.enter} href="/experiences/climate">{HOME.rooms.climate.enter}</EnterLink>
            </div>
          </div>
        </section>

        <section className={s.what} aria-labelledby="what-title">
          <div className={s.in}>
            <h2 id="what-title">{HOME.what.heading}</h2>
            <Link className={s.ulink} href="/about">{HOME.what.link}</Link>
          </div>
        </section>

        <section className={s.closing} aria-labelledby="closing-title" data-on-dark>
          <div className={s.in}>
            <h2 id="closing-title">{HOME.closing.heading}</h2>
            <Link className={s.cta} href="/#rooms">{HOME.closing.cta}</Link>
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
