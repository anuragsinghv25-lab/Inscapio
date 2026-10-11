import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { listExperienceSlugs, loadExperience } from "@/content/load";
import { pickNext } from "@/content/site/promotion";
import { ExperienceView } from "@/renderer/ExperienceView";

type Params = { slug: string };

export const dynamicParams = false;

export function generateStaticParams(): Params[] {
  return listExperienceSlugs().map((slug) => ({ slug }));
}

export async function generateMetadata({ params }: { params: Promise<Params> }): Promise<Metadata> {
  const { slug } = await params;
  if (!listExperienceSlugs().includes(slug)) return {};
  const e = loadExperience(slug);
  return {
    title: e.title,
    description: e.summary,
    openGraph: { title: `${e.title} — InScapio`, description: e.summary, url: `/experiences/${e.slug}` },
    alternates: { canonical: `/experiences/${e.slug}` },
  };
}

export default async function ExperiencePage({ params }: { params: Promise<Params> }) {
  const { slug } = await params;
  if (!listExperienceSlugs().includes(slug)) notFound();
  const nextSlug = pickNext(slug, listExperienceSlugs());
  const n = nextSlug ? loadExperience(nextSlug) : null;
  return <ExperienceView experience={loadExperience(slug)} next={n ? { slug: n.slug, title: n.title, summary: n.summary } : null} />;
}
