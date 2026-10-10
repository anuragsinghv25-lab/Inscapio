import type { ZodError } from "zod";
import { Experience } from "./experience";

export interface ValidationIssue {
  path: string;
  message: string;
}
export type ParseResult = { ok: true; experience: Experience } | { ok: false; issues: ValidationIssue[] };

const fmtPath = (p: readonly PropertyKey[]) => p.map(String).join(".") || "(root)";

export function formatIssues(error: ZodError): ValidationIssue[] {
  return error.issues.map((i) => ({ path: fmtPath(i.path), message: i.message }));
}

/** The single entry point for turning unknown JSON into a trusted Experience. */
export function parseExperience(input: unknown): ParseResult {
  const r = Experience.safeParse(input);
  return r.success ? { ok: true, experience: r.data } : { ok: false, issues: formatIssues(r.error) };
}
