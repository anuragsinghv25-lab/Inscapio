/**
 * Cross-document integrity checks that single-object schemas cannot express.
 * Walks the parsed document generically so new block types are covered by default.
 */
type Path = (string | number)[];
interface Issue {
  message: string;
  path: Path;
}

interface Doc {
  sections: { id: string; blocks: unknown[] }[];
  sources: { id: string }[];
  datasets: { id: string; illustrative: boolean; groups: { id: string }[]; derived: Record<string, { match: string }[]> }[];
  endnotes: unknown[];
  hero: { actions: { targetSectionId: string }[] };
}

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);

function walk(node: unknown, path: Path, visit: (o: Record<string, unknown>, p: Path) => void): void {
  if (Array.isArray(node)) node.forEach((n, i) => walk(n, [...path, i], visit));
  else if (isObj(node)) {
    visit(node, path);
    for (const [k, v] of Object.entries(node)) walk(v, [...path, k], visit);
  }
}

export function checkReferences(doc: Doc): Issue[] {
  const issues: Issue[] = [];
  const add = (message: string, path: Path) => issues.push({ message, path });

  // 1. Ids are unique across sections, blocks, sources and datasets.
  const seen = new Map<string, Path>();
  const claim = (id: unknown, path: Path) => {
    if (typeof id !== "string") return;
    if (seen.has(id)) add(`duplicate id '${id}'`, path);
    else seen.set(id, path);
  };
  doc.sections.forEach((s, i) => {
    claim(s.id, ["sections", i, "id"]);
    s.blocks.forEach((b, j) => {
      if (isObj(b)) claim(b.id, ["sections", i, "blocks", j, "id"]);
    });
  });
  doc.endnotes.forEach((b, i) => isObj(b) && claim(b.id, ["endnotes", i, "id"]));
  const sourceIds = new Set(doc.sources.map((s) => s.id));
  doc.sources.forEach((s, i) => claim(`source:${s.id}`, ["sources", i, "id"]));
  doc.datasets.forEach((d, i) => claim(`dataset:${d.id}`, ["datasets", i, "id"]));

  // 2. Source and dataset references resolve.
  let hasDataNote = false;
  const usedDatasets = new Set<string>();
  const visit = (o: Record<string, unknown>, p: Path) => {
    if (typeof o.sourceRef === "string" && !sourceIds.has(o.sourceRef)) add(`unknown source '${o.sourceRef}'`, [...p, "sourceRef"]);
    if (Array.isArray(o.sourceIds))
      o.sourceIds.forEach((s, i) => {
        if (typeof s === "string" && !sourceIds.has(s)) add(`unknown source '${s}'`, [...p, "sourceIds", i]);
      });
    if (o.type === "data-note") hasDataNote = true;
    if (o.type === "scrubber-chart") checkScrubber(o, p);
  };
  const checkScrubber = (o: Record<string, unknown>, p: Path) => {
    const dsId = o.datasetId as string;
    const ds = doc.datasets.find((d) => d.id === dsId);
    if (!ds) return add(`unknown dataset '${dsId}'`, [...p, "datasetId"]);
    usedDatasets.add(dsId);
    const groupIds = ds.groups.map((g) => g.id);
    const sel = o.groupSelector as { initialGroupId?: string };
    if (sel.initialGroupId && !groupIds.includes(sel.initialGroupId))
      add(`initialGroupId '${sel.initialGroupId}' is not a group of '${dsId}'`, [...p, "groupSelector", "initialGroupId"]);
    const pred = o.prediction as { optionsByGroup: Record<string, string[]> } | undefined;
    if (!pred) return;
    for (const g of groupIds) {
      const opts = pred.optionsByGroup[g];
      if (!opts) {
        add(`prediction has no options for group '${g}'`, [...p, "prediction", "optionsByGroup"]);
        continue;
      }
      opts.forEach((opt, i) => {
        if (!groupIds.includes(opt)) add(`option '${opt}' is not a group of '${dsId}'`, [...p, "prediction", "optionsByGroup", g, i]);
      });
      const finalMatch = ds.derived[g]?.at(-1)?.match;
      if (finalMatch && !opts.includes(finalMatch))
        add(`options for '${g}' must include its final-step match '${finalMatch}'`, [...p, "prediction", "optionsByGroup", g]);
    }
    for (const k of Object.keys(pred.optionsByGroup))
      if (!groupIds.includes(k)) add(`'${k}' is not a group of '${dsId}'`, [...p, "prediction", "optionsByGroup", k]);
  };
  walk(doc.sections, ["sections"], visit);
  walk(doc.endnotes, ["endnotes"], visit);

  // 3. Honesty: illustrative data in use must be disclosed in the document.
  for (const d of doc.datasets) {
    if (usedDatasets.has(d.id) && d.illustrative && !hasDataNote)
      add(`dataset '${d.id}' is illustrative: the experience must include a data-note block`, ["datasets"]);
  }

  // 4. Hero actions point at real sections.
  doc.hero.actions.forEach((a, i) => {
    if (!doc.sections.some((s) => s.id === a.targetSectionId))
      add(`unknown section '${a.targetSectionId}'`, ["hero", "actions", i, "targetSectionId"]);
  });
  return issues;
}
