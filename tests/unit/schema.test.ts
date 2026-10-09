import { describe, expect, it } from "vitest";
import { parseExperience } from "@/content/schema";
import { minimalExperience } from "../fixtures/minimal";

type Doc = ReturnType<typeof minimalExperience>;
const mutate = (fn: (d: Doc & Record<string, any>) => void) => { // eslint-disable-line @typescript-eslint/no-explicit-any
  const d = minimalExperience() as Doc & Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any
  fn(d);
  return parseExperience(d);
};
const messages = (r: ReturnType<typeof parseExperience>) => (r.ok ? [] : r.issues.map((i) => i.message)).join(" | ");

describe("experience schema", () => {
  it("accepts a valid document", () => {
    const r = parseExperience(minimalExperience());
    expect(r.ok, messages(r)).toBe(true);
  });

  it("rejects unknown block types", () => {
    expect(mutate((d) => { d.sections[0]!.blocks.push({ id: "x", type: "html", content: "<b>" } as never); }).ok).toBe(false);
  });

  it.each([["style", "color:red"], ["html", "<b>x</b>"], ["onClick", "alert(1)"], ["className", "x"]])(
    "rejects extra key '%s' on a block",
    (key, value) => {
      expect(mutate((d) => { (d.sections[0]!.blocks[0] as Record<string, unknown>)[key] = value; }).ok).toBe(false);
    },
  );

  it("rejects markup-looking text", () => {
    const r = mutate((d) => { d.summary = "Hello <script>alert(1)</script>"; });
    expect(r.ok).toBe(false);
    expect(messages(r)).toMatch(/markup/);
  });

  it("rejects non-https and javascript: URLs", () => {
    for (const url of ["http://example.com", "javascript:alert(1)", "not a url"])
      expect(mutate((d) => { (d.sources[0] as Record<string, unknown>).url = url; }).ok).toBe(false);
    expect(mutate((d) => { (d.sources[0] as Record<string, unknown>).url = "https://example.com/a"; }).ok).toBe(true);
  });

  it("rejects a wrong schema version", () => {
    expect(mutate((d) => { (d as Record<string, unknown>).schemaVersion = 2; }).ok).toBe(false);
  });

  it("rejects unresolved source references", () => {
    expect(messages(mutate((d) => { d.sources = []; }))).toMatch(/unknown source/);
  });

  it("rejects an unknown dataset", () => {
    expect(messages(mutate((d) => { (d.sections[0]!.blocks[1] as Record<string, unknown>).datasetId = "nope"; }))).toMatch(/unknown dataset/);
  });

  it("rejects duplicate ids", () => {
    expect(messages(mutate((d) => { d.sections[0]!.blocks[1]!.id = "p1"; }))).toMatch(/duplicate id/);
  });

  it("requires a data-note when an illustrative dataset is used", () => {
    expect(messages(mutate((d) => { d.endnotes = []; }))).toMatch(/data-note/);
  });

  it("rejects an illustrative dataset not declared illustrative-model", () => {
    expect(mutate((d) => { d.datasets[0]!.provenance.kind = "cited-source"; }).ok).toBe(false);
  });

  it("rejects prediction options that omit the true match", () => {
    expect(messages(mutate((d) => {
      ((d.sections[0]!.blocks[1] as any).prediction.optionsByGroup as Record<string, string[]>).a = ["a", "a"]; // eslint-disable-line @typescript-eslint/no-explicit-any
    }))).toMatch(/final-step match/);
  });

  it("rejects invalid scrubber parameters", () => {
    expect(mutate((d) => { (d.sections[0]!.blocks[1] as any).chart.yMin = 20; }).ok).toBe(false); // eslint-disable-line @typescript-eslint/no-explicit-any
    expect(mutate((d) => { (d.sections[0]!.blocks[1] as any).themeBinding = "css"; }).ok).toBe(false); // eslint-disable-line @typescript-eslint/no-explicit-any
  });

  it("rejects a dataset with mismatched shape", () => {
    expect(mutate((d) => { d.datasets[0]!.values.a = [[1, 2]] as never; }).ok).toBe(false);
  });

  it("rejects hero actions that target no section", () => {
    expect(messages(mutate((d) => { d.hero.actions[0]!.targetSectionId = "missing"; }))).toMatch(/unknown section/);
  });

  it("rejects an unknown accent", () => {
    expect(mutate((d) => { (d.sections[0] as Record<string, unknown>).accent = "#ff0000"; }).ok).toBe(false);
  });
});
