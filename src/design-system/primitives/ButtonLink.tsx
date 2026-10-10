import Link from "next/link";
import type { ComponentProps } from "react";
import { classes } from "@/renderer/types";
import s from "./ButtonLink.module.css";

type Emphasis = "primary" | "secondary";

/** A link styled as a button. In-page targets (#id) use a plain anchor; routes use next/link. */
export function ButtonLink({ emphasis = "primary", className, href, ...rest }: Omit<ComponentProps<typeof Link>, "href"> & { href: string; emphasis?: Emphasis }) {
  const cls = classes(s.btn, emphasis === "secondary" ? s.secondary : s.primary, className);
  if (href.startsWith("#")) return <a href={href} className={cls} {...(rest as object)} />;
  return <Link href={href} className={cls} {...rest} />;
}
