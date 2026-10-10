"use client";

import Link from "next/link";
import type { ComponentProps, MouseEvent } from "react";
import { ORIGIN_KEY } from "@/renderer/ExperienceShell";

/** A link into an experience. Remembers where it was tapped so the experience can open from that point. */
export function EnterLink({ onClick, ...rest }: ComponentProps<typeof Link>) {
  const handle = (e: MouseEvent<HTMLAnchorElement>) => {
    const pointer = e.detail > 0; // keyboard activation has detail 0 -> centred origin
    try {
      sessionStorage.setItem(ORIGIN_KEY, JSON.stringify({ x: pointer ? `${e.clientX}px` : "50%", y: pointer ? `${e.clientY}px` : "60%" }));
    } catch {}
    onClick?.(e);
  };
  return <Link {...rest} onClick={handle} />;
}
