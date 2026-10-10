import Link from "next/link";
import { FOOTER, NAV } from "@/content/site/pages";
import { UI } from "@/renderer/ui-strings";
import s from "./SiteChrome.module.css";

export function SiteNav({ onDark = false }: { onDark?: boolean }) {
  return (
    <nav className={s.nav} aria-label={UI.siteName} data-on-dark={onDark || undefined}>
      <Link className={s.wordmark} href="/">{UI.siteName}</Link>
      <ul>
        <li><Link className={s.link} href="/#rooms">{NAV.explore}</Link></li>
        <li><Link className={s.link} href="/about">{NAV.about}</Link></li>
      </ul>
    </nav>
  );
}

export function SiteFooter() {
  return (
    <footer className={s.footer}>
      <p><b>{FOOTER.name}</b></p>
      <p>{FOOTER.note}</p>
      <p>{FOOTER.domain}</p>
    </footer>
  );
}
