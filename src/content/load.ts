import { readdirSync, readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { formatIssues } from "./schema";
import { Experience } from "./schema/experience";

/**
 * Loads experiences from local, version-controlled fixtures (server-side only).
 *   src/content/experiences/<slug>/experience.json
 *   src/content/experiences/<slug>/datasets/*.json   (merged into `datasets`)
 * Anything that fails validation throws with every issue listed: invalid content never renders.
 */
const ROOT = path.join(process.cwd(), "src", "content", "experiences");

const readJson = (file: string): unknown => JSON.parse(readFileSync(file, "utf8"));

export function listExperienceSlugs(): string[] {
  return readdirSync(ROOT, { withFileTypes: true })
    .filter((d) => d.isDirectory() && existsSync(path.join(ROOT, d.name, "experience.json")))
    .map((d) => d.name)
    .sort();
}

export function loadExperience(slug: string): Experience {
  if (!/^[a-z0-9-]+$/.test(slug)) throw new Error(`invalid slug '${slug}'`);
  const dir = path.join(ROOT, slug);
  const raw = readJson(path.join(dir, "experience.json")) as Record<string, unknown>;
  const dsDir = path.join(dir, "datasets");
  const files = existsSync(dsDir) ? readdirSync(dsDir).filter((f) => f.endsWith(".json")).sort() : [];
  const datasets = [...((raw.datasets as unknown[] | undefined) ?? []), ...files.map((f) => readJson(path.join(dsDir, f)))];
  const parsed = Experience.safeParse({ ...raw, datasets });
  if (!parsed.success) {
    const lines = formatIssues(parsed.error).slice(0, 20).map((i) => `  ${i.path}: ${i.message}`);
    throw new Error(`Experience '${slug}' failed validation:\n${lines.join("\n")}`);
  }
  if (parsed.data.slug !== slug) throw new Error(`Experience folder '${slug}' declares slug '${parsed.data.slug}'`);
  return parsed.data;
}
