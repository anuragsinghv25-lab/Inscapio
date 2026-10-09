/**
 * One-off migration: reads the FROZEN prototype (prototype/v0/index.html, never modified) and writes
 * src/content/experiences/whose-body-is-it/experience.json.
 * Text is copied from v0's DOM and JS arrays, not retyped. Run: pnpm generate:whose-body
 * Intentional differences from v0 are marked DIFF.
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import vm from "node:vm";
import { JSDOM } from "jsdom";

const SRC = "prototype/v0/index.html";
const OUT = "src/content/experiences/whose-body-is-it/experience.json";
const html = readFileSync(SRC, "utf8");
const dom = new JSDOM(html);
const doc = dom.window.document;
const script = [...doc.querySelectorAll("script")].map((s) => s.textContent).join("\n");

/* ---- literals out of v0's script ---- */
function grab(after) {
  const i = script.indexOf(after);
  if (i < 0) throw new Error(`not found in v0: ${after}`);
  let j = i + after.length;
  const open = script[j];
  const close = open === "[" ? "]" : "}";
  let depth = 0, q = null;
  for (let k = j; k < script.length; k++) {
    const ch = script[k];
    if (q) { if (ch === "\\") k++; else if (ch === q) q = null; continue; }
    if (ch === '"' || ch === "'") { q = ch; continue; }
    if (ch === open) depth++;
    else if (ch === close && --depth === 0) return vm.runInNewContext("(" + script.slice(j, k + 1) + ")");
  }
  throw new Error("unbalanced literal after " + after);
}
const LAYERS = grab("const LAYERS=");
const LADDER = grab("stepper('#ladder',");
const CULTURE = grab("stepper('#culture',");
const Q = grab("const Q=");
const A = grab("const A=");
const M = grab("const M=");
const W = grab("const W=");

const ACCENT = { "#c8374f": "rose", "#17787a": "teal", "#6a3fb5": "violet", "#a85f00": "ochre", "#1d6fb8": "blue", "#8a2a6e": "plum", "#2f7d4f": "green", "#d6336c": "pink", "#3b5bdb": "indigo" };
const accent = (hex) => { const a = ACCENT[hex.toLowerCase()]; if (!a) throw new Error("unmapped colour " + hex); return a; };
const kebab = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

/* ---- inline markup -> rich text (only <b>/<i> exist in v0 content) ---- */
function rich(node) {
  const out = [];
  const walk = (n, marks) => {
    for (const c of n.childNodes) {
      if (c.nodeType === 3) out.push({ text: c.textContent, marks });
      else if (c.nodeType === 1) {
        const tag = c.tagName.toLowerCase();
        if (tag === "b") walk(c, [...marks, "strong"]);
        else if (tag === "i") walk(c, [...marks, "em"]);
        else throw new Error("unsupported inline element <" + tag + ">");
      }
    }
  };
  walk(node, []);
  const merged = [];
  for (const n of out) {
    const last = merged.at(-1);
    if (last && last.marks.join() === n.marks.join()) last.text += n.text; else merged.push({ ...n });
  }
  if (merged.length) { merged[0].text = merged[0].text.replace(/^\s+/, ""); merged.at(-1).text = merged.at(-1).text.replace(/\s+$/, ""); }
  return merged.filter((n) => n.text).map((n) => (n.marks.length ? { text: n.text, marks: n.marks } : { text: n.text }));
}
const plain = (el) => el.textContent.replace(/\s+/g, " ").trim();

/* ---- chapters ---- */
const sections = [];
const counts = { deeper: 0 };
for (const sec of doc.querySelectorAll("#xp1 section.ch")) {
  const n = sec.id.replace("c", "");
  const sid = `chapter-${n}`;
  let bi = 0;
  const nid = (t) => `${sid}-${t}-${++bi}`;
  const wrap = sec.querySelector(".wrap");
  const blocks = [];
  let kicker, title;
  for (const el of wrap.children) {
    const cls = el.className, tag = el.tagName.toLowerCase();
    if (cls === "tag") kicker = plain(el);
    else if (tag === "h2") title = plain(el);
    else if (tag === "p") blocks.push({ id: nid("paragraph"), type: "paragraph", variant: cls === "lead" ? "lead" : "body", content: rich(el) });
    else if (cls === "say") blocks.push({ id: nid("callout"), type: "callout", content: rich(el) });
    else if (cls === "card" && !el.id) blocks.push(card(el, nid("card")));
    else if (cls === "deep") { counts.deeper++; blocks.push(deeper(el, nid("deeper"))); }
    else if (el.id === "layers") blocks.push({ id: nid("accordion"), type: "accordion", variant: "layers", items: LAYERS.map(([c, t, d], i) => ({ id: `layer-${i + 1}`, title: t, body: d, accent: accent(c) })) });
    else if (el.id === "ladder") blocks.push(stepper(nid("stepper"), "rose", LADDER, "rung"));
    else if (el.id === "culture") blocks.push(stepper(nid("stepper"), "green", CULTURE, "level"));
    else if (el.id === "sort") blocks.push(classify(nid("classify")));
    else if (el.id === "chips") blocks.push(claims(nid("claims")));
    else if (el.id === "cards") { /* rendered by the claims block */ }
    else if (el.id === "miss") M.forEach((t, i) => blocks.push({ id: nid("card"), type: "card", label: `${i + 1}.`, content: [{ text: t }] }));
    else if (el.id === "who") blocks.push(personas(nid("selector-content")));
    else if (el.id === "whoOut") { /* rendered by the selector block */ }
    else if (cls === "help") blocks.push(help(el, nid("resource-box")));
    else throw new Error(`unhandled element in ${sid}: <${tag} class="${cls}" id="${el.id}">`);
  }
  sections.push({ id: sid, kicker, title, accent: accent(sec.getAttribute("style").match(/--c:(#[0-9a-fA-F]{6})/)[1]), blocks });
}

function card(el, id) {
  const first = el.firstElementChild;
  if (first && first.tagName === "B" && el.firstChild === first) {
    const label = plain(first);
    const rest = rich({ childNodes: [...el.childNodes].slice(1) });
    return { id, type: "card", label, content: rest };
  }
  return { id, type: "card", content: rich(el) };
}
function deeper(el, id) {
  const kids = [];
  let k = 0;
  for (const c of el.children) {
    if (c.tagName === "P") kids.push({ id: `${id}-p${++k}`, type: "paragraph", variant: "body", content: rich(c) });
    else if (c.tagName === "TABLE") {
      const rows = [...c.querySelectorAll("tr")].map((r) => [...r.children].map(plain));
      kids.push({ id: `${id}-t${++k}`, type: "compare-table", columns: rows[0], rows: rows.slice(1) });
    } else throw new Error("unhandled in .deep: " + c.tagName);
  }
  return { id, type: "deeper", blocks: kids };
}
function stepper(id, acc, items, prefix) {
  return { id, type: "stepper", accent: acc, steps: items.map(([t, s], i) => ({ id: `${prefix}-${i + 1}`, title: t, note: s })) };
}
function classify(id) {
  return {
    id, type: "classify",
    categories: [{ id: "safety", label: "Safety advice", accent: "teal" }, { id: "blame", label: "Blame", accent: "rose" }],
    items: Q.map(([text, a, fb], i) => ({ id: `statement-${i + 1}`, text, answer: a === "s" ? "safety" : "blame", feedback: fb })),
    closing: "The same words can be care or blame depending on who they punish.",
  };
}
function claims(id) {
  const tabs = [["women", "About women and feminism"], ["men", "About men"], ["law", "About law and society"]];
  return {
    id, type: "claims", accent: "plum", hint: "Tap for a fair answer", allLabel: "All",
    themes: tabs.map(([k, l]) => ({ id: k, label: l })),
    items: A.map(([th, q, a], i) => ({ id: `claim-${i + 1}`, theme: th, claim: q.replace(/^"|"$/g, ""), response: a })),
  };
}
function personas(id) {
  return { id, type: "selector-content", options: Object.entries(W).map(([k, v]) => ({ id: kebab(k), label: k, content: v })), defaultOptionId: kebab(Object.keys(W)[0]) };
}
function help(el, id) {
  const p = el.querySelector("p");
  const parts = plain(p).split(" · ");
  const items = parts.map((s) => {
    const m = s.match(/^(\d+) ([^(.]+?)(?: \((.*?)\))?(?:\. (.*))?$/);
    if (!m) throw new Error("helpline parse: " + s);
    return { id: `line-${m[1]}`, value: m[1], label: m[2], ...(m[3] ? { detail: m[3] } : {}), _note: m[4] };
  });
  const note = items.at(-1)._note;
  items.forEach((x) => delete x._note);
  return { id, type: "resource-box", title: plain(el.querySelector("h3")), items, note };
}

/* ---- sources and end notes (v0 footer) ---- */
const footerP = [...doc.querySelectorAll("#xp1 > footer p")];
const srcText = plain(footerP[0]).replace(/^Sources used for the underlying facts:\s*/, "").replace(/\.$/, "");
const SOURCE_IDS = ["who-vaw-fact-sheet", "who-respect-women", "cdc-sv-risk-factors", "nij-deterrence", "un-women-gender-norms", "bns-2023", "jamui-reporting-2026"];
const citations = srcText.split("; ");
if (citations.length !== SOURCE_IDS.length) throw new Error("source count changed");
const sources = citations.map((c, i) => ({ id: SOURCE_IDS[i], citation: c }));

const exp = {
  schemaVersion: 1,
  id: "whose-body-is-it",
  slug: "whose-body-is-it",
  kind: "explainer",
  title: "Whose Body Is It?",
  shortTitle: "Whose Body Is It?",
  language: "en",
  summary: "Safety, honour, gender, respect and the boundaries we place around other people’s lives.",
  theme: "paper",
  reading: ["deeper", "text-size", "theme"],
  hero: {
    title: plain(doc.querySelector("#xp1 .hero h1")),
    intro: [...doc.querySelectorAll("#xp1 .hero p")].map(plain),
    actions: [
      { label: "Begin", targetSectionId: "chapter-1", emphasis: "primary" },
      // DIFF: v0 targeted #c6 ("Risk or blame?") although the label says "the arguments", which is chapter 7.
      { label: "Jump to the arguments", targetSectionId: "chapter-7", emphasis: "secondary" },
    ],
  },
  sections,
  sources,
  datasets: [],
  endnotes: [
    { id: "sources", type: "source-list", lead: "Sources used for the underlying facts:", sourceIds: SOURCE_IDS },
    { id: "disclaimer", type: "paragraph", variant: "body", content: [{ text: plain(footerP[1]) }] },
  ],
};

/* ---- sanity against the counts recorded in the migration inventory ---- */
const must = (c, m) => { if (!c) throw new Error("count mismatch: " + m); };
must(sections.length === 12, "12 chapters");
must(counts.deeper === 7, "7 deeper blocks");
must(LAYERS.length === 6 && LADDER.length === 6 && CULTURE.length === 5, "layers/ladders");
must(Q.length === 6 && A.length === 16 && M.length === 11 && Object.keys(W).length === 7, "quiz/claims/misses/personas");

mkdirSync(OUT.replace(/\/[^/]+$/, ""), { recursive: true });
writeFileSync(OUT, JSON.stringify(exp, null, 2) + "\n");
console.log(`wrote ${OUT}: ${sections.length} chapters, ${sections.reduce((n, s) => n + s.blocks.length, 0)} blocks`);
