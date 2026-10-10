import type { ButtonHTMLAttributes } from "react";
import { classes } from "@/renderer/types";
import s from "./Chip.module.css";

/** A toggle button used for filters, pickers and city/persona selectors. */
export function Chip({ pressed, className, ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { pressed: boolean }) {
  return <button type="button" aria-pressed={pressed} className={classes(s.chip, className)} {...rest} />;
}
