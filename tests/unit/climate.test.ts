import { describe, expect, it } from "vitest";
import { listExperienceSlugs, loadExperience } from "@/content/load";

describe("loader", () => {
  it("lists both v0 experiences", () => {
    expect(listExperienceSlugs()).toEqual(["climate", "whose-body-is-it"]);
  });
  it("loads and validates every experience", () => {
    for (const s of listExperienceSlugs()) expect(() => loadExperience(s)).not.toThrow();
  });
});

describe("climate content", () => {
  const e = loadExperience("climate");
  const ds = e.datasets[0]!;
  const last = ds.steps.length - 1;
  it("is a 20 × 45 × 12 dataset flagged illustrative, with the data note kept", () => {
    expect(ds.groups).toHaveLength(20);
    expect(ds.steps).toHaveLength(45);
    expect(ds.periods).toHaveLength(12);
    expect(ds.illustrative).toBe(true);
    const note = e.sections.flatMap((s) => s.blocks).find((b) => b.type === "data-note");
    expect(note?.type === "data-note" && note.lead).toBe("Demo data, not a forecast.");
  });
  it("reproduces v0's headline analogues (London→Madrid, Madrid→Tokyo in 2070)", () => {
    expect(ds.derived["london"]![last]!.match).toBe("madrid");
    expect(ds.derived["madrid"]![last]!.match).toBe("tokyo");
  });
  it("offers three prediction options that include the true answer", () => {
    const sc = e.sections.flatMap((s) => s.blocks).find((b) => b.type === "scrubber-chart");
    if (sc?.type !== "scrubber-chart" || !sc.prediction) throw new Error("no prediction");
    for (const g of ds.groups) {
      const opts = sc.prediction.optionsByGroup[g.id]!;
      expect(opts).toHaveLength(3);
      expect(opts).toContain(ds.derived[g.id]![last]!.match);
    }
  });
});
