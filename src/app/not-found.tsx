import Link from "next/link";
import type { Metadata } from "next";
import { NOT_FOUND } from "@/content/site/pages";
import { SiteFooter, SiteNav } from "@/components/SiteChrome";
import s from "@/components/pages.module.css";

export const metadata: Metadata = { title: NOT_FOUND.title };

export default function NotFound() {
  return (
    <>
      <SiteNav />
      <main id="main" tabIndex={-1} className={s.nf}>
        <h1 tabIndex={-1}>{NOT_FOUND.title}</h1>
        <p>{NOT_FOUND.body}</p>
        <Link className={s.ulink} href="/">{NOT_FOUND.link}</Link>
      </main>
      <SiteFooter />
    </>
  );
}
