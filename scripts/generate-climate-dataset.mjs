/**
 * One-off migration: runs v0's OWN climate model code (extracted from the frozen prototype, never
 * modified) and writes the results as data, so the renderer performs no modelling.
 *   src/content/experiences/climate/datasets/city-temperatures.json
 *   src/content/experiences/climate/experience.json
 * Run: pnpm generate:climate
 * Intentional differences from v0 are marked DIFF.
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import vm from "node:vm";
import { JSDOM } from "jsdom";

const SRC = "prototype/v0/index.html";
const DIR = "src/content/experiences/climate";
const html = readFileSync(SRC, "utf8");
const doc = new JSDOM(html).window.document;
const script = [...doc.querySelectorAll("script")].map((s) => s.textContent).join("\n");

/* The model: from `const C=` through `const feels=...;` (v0 lines "shared data" and "demo climate model"). */
const a = script.indexOf("const C=[");
const b = script.indexOf("const SC=");
if (a < 0 || b < 0) throw new Error("v0 model markers not found");
const modelSrc = script.slice(a, b);
const ctx = vm.createContext({ Math });
vm.runInContext(modelSrc + "\nthis.__m={C,mA,temp,stats,kind,feels}", ctx);
const { C, temp, stats, kind, feels } = ctx.__m;

const slug = (n) => n.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const id = (c) => slug(c.n);
const r2 = (x) => Math.round(x * 100) / 100;
const r6 = (x) => Math.round(x * 1e6) / 1e6;

const YEARS = Array.from({ length: 45 }, (_, i) => 2026 + i);
const values = {}, derived = {};
for (const c of C) {
  values[id(c)] = YEARS.map((y) => { const g = (y - 2026) / 44; return Array.from({ length: 12 }, (_, m) => r2(temp(c, m, g))); });
  derived[id(c)] = YEARS.map((y) => {
    const g = (y - 2026) / 44, s = stats(c, g);
    return { match: id(feels(c, g)), category: kind(c, g), warm: r6(Math.min(1, (c.dT * g) / 3)), high: r6(s.w), low: r6(s.k) };
  });
}

/* Prediction options exactly as v0's guess(): the true 2070 analogue plus two decoys, sorted by name. */
const optionsByGroup = {};
for (const c of C) {
  const t = feels(c, 1);
  const o = [t, ...C.filter((x) => x !== c && x !== t).sort((p, q) => ((p.n + c.n).length % 7) - ((q.n + c.n).length % 7)).slice(0, 2)].sort((p, q) => (p.n < q.n ? -1 : 1));
  optionsByGroup[id(c)] = o.map(id);
}

const dataset = {
  id: "city-temperatures",
  title: "Demo city temperatures, 2026–2070",
  unit: "°C",
  illustrative: true,
  provenance: {
    kind: "illustrative-model",
    description:
      "Generated offline by scripts/generate-climate-dataset.mjs, which runs the demo model from InScapio prototype v0. City temperatures are rounded approximations and the warming per city is an invented illustrative rule (more at higher latitudes). Not a forecast.",
  },
  groups: C.map((c) => ({ id: id(c), label: c.n })),
  steps: YEARS,
  periods: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
  values,
  derived,
};

/* ---- copy from v0's markup (not retyped) ---- */
const plain = (el) => el.textContent.replace(/\s+/g, " ").trim();
const cl = doc.querySelector("#cl");
const [sFirst, sK1, sK2, sLast] = cl.querySelectorAll("section.cs");
const dm = sLast.querySelector("p.dm");
const dmLead = plain(dm.querySelector("b"));
const dmRest = plain(dm).slice(dmLead.length).trim();
const q3 = [...sK1.querySelectorAll(".q3 > div")].map((d, i) => ({ id: `question-${i + 1}`, title: plain(d.querySelector("b")), text: plain(d).slice(plain(d.querySelector("b")).length).trim() }));
const k1p = [...sK1.querySelectorAll(":scope > p")].map(plain);
const T = (...parts) => parts.map((p) => (typeof p === "string" ? { text: p } : p));
const tok = (token, marks) => (marks ? { token, marks } : { token });
const p = (idv, text, variant = "body") => ({ id: idv, type: "paragraph", variant, content: [{ text }] });
const deeper = (idv, text) => ({ id: idv, type: "deeper", blocks: [p(`${idv}-note`, text)] });

const exp = {
  schemaVersion: 1,
  id: "climate",
  slug: "climate",
  kind: "data-story",
  title: plain(sFirst.querySelector("h1")),
  shortTitle: plain(cl.querySelector(".cb b")),
  language: "en",
  summary: "Explore how a changing climate could transform the places we know.",
  theme: "tarn",
  reading: ["deeper"],
  hero: {
    title: plain(sFirst.querySelector("h1")),
    intro: [plain(sFirst.querySelector("p.sub"))],
    actions: [{ label: plain(sFirst.querySelector("a.go")), targetSectionId: "pattern", emphasis: "primary" }],
  },
  sections: [
    {
      id: "pattern",
      title: plain(sK1.querySelector("h2")),
      blocks: [
        p("pattern-intro", k1p[0]),
        { id: "pattern-questions", type: "fact-row", items: q3 },
        p("pattern-label", k1p[1]),
        deeper("pattern-koppen", plain(sK1.querySelector(".dp"))),
      ],
    },
    {
      id: "explore",
      title: plain(sK2.querySelector("h2")),
      blocks: [
        {
          id: "city-scrubber",
          type: "scrubber-chart",
          datasetId: "city-temperatures",
          groupSelector: { label: sK2.querySelector("#cc").getAttribute("aria-label"), initialGroupId: id(C[0]) },
          stepControl: { label: "Year" },
          chart: { title: "Monthly temperature chart", yMin: -12, yMax: 42, yTicks: [0, 10, 20, 30, 40], valueSuffix: "°" },
          legend: {
            first: T(tok("group"), " today"),
            now: T(tok("group"), " in ", tok("step")),
            match: T(tok("match"), " today"),
          },
          headline: {
            atFirstStep: T(tok("group"), " today. Drag forward to see where its climate is heading."),
            later: T("In ", tok("step"), ", ", tok("group"), " feels most like ", tok("match", ["strong"]), " does today."),
          },
          stats: [
            { kind: "high", label: "warmest month" },
            { kind: "low", label: "coldest month" },
            { kind: "category", label: "simplified type", changedFrom: ", changed from" },
          ],
          prediction: {
            question: T("Before you drag: which city’s climate will ", tok("group"), " come closest to by ", tok("lastStep"), "?"),
            optionsByGroup,
            correctPrefix: "Close.",
            wrongPrefix: "Not quite.",
            reveal: T("In this demo model it’s ", tok("match"), ". Watch the year move to ", tok("lastStep"), "."),
          },
          themeBinding: "warmth",
        },
        deeper("explore-analogue", plain(sK2.querySelector(".dp"))),
      ],
    },
    {
      id: "closing",
      title: plain(sLast.querySelector("h2")),
      blocks: [
        p("closing-body", plain(sLast.querySelector("p:not(.dm)"))),
        { id: "demo-data-note", type: "data-note", lead: dmLead, content: [{ text: dmRest }] },
      ],
    },
  ],
  sources: [],
  endnotes: [],
};

// Self-checks against what the inventory recorded.
if (C.length !== 20) throw new Error("expected 20 cities");
if (q3.length !== 3) throw new Error("expected 3 fact-row items");

mkdirSync(`${DIR}/datasets`, { recursive: true });
writeFileSync(`${DIR}/datasets/city-temperatures.json`, JSON.stringify(dataset) + "\n");
writeFileSync(`${DIR}/experience.json`, JSON.stringify(exp, null, 2) + "\n");
console.log(`wrote ${DIR}: ${C.length} cities × ${YEARS.length} years × 12 months`);
