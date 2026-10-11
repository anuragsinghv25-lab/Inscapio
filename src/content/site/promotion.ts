/**
 * Platform policy, deliberately NOT part of the content schema (D-041).
 * Experiences listed here are never offered as a "next experience" link from another experience's end state.
 * "whose-body-is-it" is held because its content has had no editorial or safeguarding review (Q-16).
 * Remove an entry only when a named reviewer has signed off and the owner agrees.
 */
export const HELD_FROM_NEXT: readonly string[] = ["whose-body-is-it"];

/** The experience to offer after `current`, in slug order, skipping itself and held ones; null when there is none. */
export function pickNext(current: string, slugs: readonly string[]): string | null {
  const others = slugs.filter((s) => s !== current && !HELD_FROM_NEXT.includes(s));
  if (others.length === 0) return null;
  const after = others.find((s) => s > current);
  return after ?? others[0] ?? null;
}
