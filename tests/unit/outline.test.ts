import { describe, expect, it } from "vitest";
import { listExperienceSlugs, loadExperience } from "@/content/load";
import { HELD_FROM_NEXT, pickNext } from "@/content/site/promotion";
import { describeExperience } from "@/renderer/outline";

describe("describeExperience", () => {
  it("derives sections, interactive count and a read-time estimate from the document", () => {
    const body = describeExperience(loadExperience("whose-body-is-it"));
    expect(body.items).toHaveLength(12);
    expect(body.items[0]).toMatchObject({ id: "chapter-1", label: "Chapter 1 · Why this book" });
    expect(body.interactive).toBe(6);
    expect(body.minutes).toBeGreaterThan(5);
    const climate = describeExperience(loadExperience("climate"));
    expect(climate.items.map((i) => i.id).sort()).toEqual(["closing", "explore", "pattern"]);
    expect(climate.interactive).toBe(1);
    expect(climate.minutes).toBeGreaterThanOrEqual(1);
  });
});

describe("promotion hold", () => {
  it("holds Whose Body Is It? back from next links (Q-16)", () => {
    expect(HELD_FROM_NEXT).toContain("whose-body-is-it");
  });
  it("never offers a held experience, nor the current one", () => {
    const slugs = listExperienceSlugs();
    expect(pickNext("climate", slugs)).toBeNull();
    expect(pickNext("whose-body-is-it", slugs)).toBe("climate");
  });
  it("cycles through allowed experiences in slug order", () => {
    expect(pickNext("a", ["a", "b", "c"])).toBe("b");
    expect(pickNext("c", ["a", "b", "c"])).toBe("a");
    expect(pickNext("a", ["a", "whose-body-is-it"])).toBeNull();
  });
});
