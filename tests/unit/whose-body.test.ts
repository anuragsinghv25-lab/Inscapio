import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { parseExperience } from "@/content/schema";

const raw = JSON.parse(readFileSync("src/content/experiences/whose-body-is-it/experience.json", "utf8"));

describe("whose-body-is-it content", () => {
  const r = parseExperience(raw);
  it("validates against the schema", () => {
    expect(r.ok, r.ok ? "" : JSON.stringify(r.issues.slice(0, 5))).toBe(true);
  });
  it("keeps v0's structure counts", () => {
    if (!r.ok) throw new Error("invalid");
    const e = r.experience;
    const all = e.sections.flatMap((s) => s.blocks);
    expect(e.sections).toHaveLength(12);
    expect(all.filter((b) => b.type === "deeper")).toHaveLength(7);
    expect(all.filter((b) => b.type === "accordion")).toHaveLength(1);
    expect(all.filter((b) => b.type === "stepper")).toHaveLength(2);
    const claims = all.find((b) => b.type === "claims");
    expect(claims?.type === "claims" && claims.items.length).toBe(16);
    expect(e.sources).toHaveLength(7);
  });
  it("retargets the arguments button to chapter 7 (intentional difference from v0)", () => {
    expect(raw.hero.actions[1].targetSectionId).toBe("chapter-7");
  });
});
