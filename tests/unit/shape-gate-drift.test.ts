import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { listExperienceSlugs, loadExperience } from "@/content/load";
import { BLOCK_TYPES, EndnoteBlock } from "@/content/schema/blocks";
import { Experience, SCHEMA_VERSION } from "@/content/schema/experience";

/**
 * The database "shape gate" (supabase/migrations/20261016000200_experience_tables.sql) is a cheap
 * structural check that duplicates a few constants of the Zod content schema. It is NOT the full
 * validation. This test makes any drift between the two a failing build: change the Zod vocabulary
 * and this fails until the SQL constants are updated in a new forward-only migration.
 */
const MIGRATION = path.join(process.cwd(), "supabase", "migrations", "20261016000200_experience_tables.sql");
const sql = readFileSync(MIGRATION, "utf8");

function sqlList(fn: string): string[] {
  const m = new RegExp(`create function private\\.${fn}\\(\\)[\\s\\S]*?select array\\[([\\s\\S]*?)\\]::`).exec(sql);
  if (!m) throw new Error(`function ${fn} not found in ${MIGRATION}`);
  return [...m[1]!.matchAll(/'([^']+)'/g)].map((x) => x[1]!);
}
const sqlInts = (fn: string): number[] => {
  const m = new RegExp(`create function private\\.${fn}\\(\\)[\\s\\S]*?select array\\[([\\s\\S]*?)\\]::`).exec(sql);
  if (!m) throw new Error(`function ${fn} not found`);
  return m[1]!.split(",").map((x) => Number(x.trim()));
};

describe("database shape gate stays in step with the Zod content schema", () => {
  it("knows exactly the block vocabulary", () => {
    expect([...sqlList("known_block_types")].sort()).toEqual([...BLOCK_TYPES].sort());
  });
  it("knows exactly the endnote block types", () => {
    const zodTypes = EndnoteBlock.options.map((o) => o.shape.type.value as string);
    expect([...sqlList("known_endnote_types")].sort()).toEqual([...zodTypes].sort());
  });
  it("knows exactly the top-level document keys", () => {
    const keys = Object.keys((Experience as unknown as { shape: Record<string, unknown> }).shape);
    expect([...sqlList("known_document_keys")].sort()).toEqual([...keys].sort());
  });
  it("supports exactly the current schema version", () => {
    expect(sqlInts("supported_schema_versions")).toEqual([SCHEMA_VERSION]);
  });
  it("reserves the slugs of every existing file-based experience", () => {
    const reserved = sqlList("reserved_slugs");
    for (const slug of listExperienceSlugs()) expect(reserved).toContain(slug);
  });
});

describe("both existing experiences satisfy the structural gate the database applies", () => {
  const keys = sqlList("known_document_keys");
  const blockTypes = sqlList("known_block_types");
  const endnoteTypes = sqlList("known_endnote_types");
  for (const slug of listExperienceSlugs()) {
    it(`${slug}: top-level keys, block types and sizes`, () => {
      const doc = loadExperience(slug);
      for (const k of Object.keys(doc)) expect(keys).toContain(k);
      expect(doc.schemaVersion).toBe(SCHEMA_VERSION);
      expect(doc.title.length).toBeLessThanOrEqual(200);
      expect(doc.summary.length).toBeLessThanOrEqual(1200);
      expect(doc.sections.length).toBeGreaterThanOrEqual(1);
      expect(doc.sections.length).toBeLessThanOrEqual(40);
      for (const s of doc.sections) {
        expect(s.blocks.length).toBeGreaterThanOrEqual(1);
        expect(s.blocks.length).toBeLessThanOrEqual(40);
        for (const b of s.blocks) expect(blockTypes).toContain(b.type);
      }
      for (const b of doc.endnotes) expect(endnoteTypes).toContain(b.type);
      expect(Buffer.byteLength(JSON.stringify(doc), "utf8")).toBeLessThan(1048576);
    });
  }
});
