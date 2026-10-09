# Content architecture

> **Status:** Phase 0 · Design. The schema shapes below are **illustrative**, to fix the architecture and make it testable. The authoritative schema will be written in code (Zod/TypeScript) in Phase 1 and will supersede the snippets here. Conceptual entities are in [`../ux/content-model.md`](../ux/content-model.md); this document is the technical treatment.

## Purpose

Define how an InScapio experience is represented so that:

- an AI can produce it **safely** (as data, never code),
- a renderer can display it **consistently, accessibly and quickly**,
- it can be **versioned, diffed, validated, previewed and migrated**,
- the **prototype's experiences** can be expressed in it without losing what makes them good.

## The Experience document

An experience's content is a single JSON document, validated against a versioned schema, stored per revision.

```
Experience
├── schemaVersion, id, kind, title, subtitle, language, summary, theme
├── teaser?                (a block shown as the "live sample" on home/topic pages)
├── sections[]             (chapters)
│     ├── id, kicker, title, accent
│     └── blocks[]
│           └── id, type, depth ("surface" | "deeper"), …type-specific fields…
│                 + derivedFrom?[] (knowledge items) + sources?[]
├── sources[]              (citations)
├── datasets[]             (data for charts; provenance + illustrative flag)
└── media[]                (images; alt text required)
```

### Illustrative example

*A tiny document; shape only.*

```jsonc
{
  "schemaVersion": 1,
  "id": "exp_01H…",
  "kind": "explainer",
  "title": "Whose Body Is It?",
  "language": "en",
  "theme": "fog",
  "sections": [
    {
      "id": "sec_why",
      "kicker": "Chapter 2 · The one idea",
      "title": "Your body is yours. Nobody else's.",
      "accent": "teal",
      "blocks": [
        { "id": "b1", "type": "paragraph", "variant": "lead",
          "content": [{ "text": "Everything in this book grows from one sentence." }] },
        { "id": "b2", "type": "card",
          "label": "For a child",
          "content": [{ "text": "If something feels wrong, you may say no, even to a grown-up." }] },
        { "id": "b3", "type": "callout",
          "content": [{ "text": "Respecting this is not weakness. It is what strength looks like." }] },
        { "id": "b4", "type": "paragraph", "depth": "deeper",
          "content": [
            { "text": "Public-health bodies list the same themes again and again. See " },
            { "sourceRef": "src_who" }
          ] }
      ]
    }
  ],
  "sources": [
    { "id": "src_who", "title": "Violence against women (fact sheet)", "publisher": "WHO",
      "url": "https://…", "accessedAt": "2026-09-30", "type": "report" }
  ]
}
```

Note what is *absent*: no HTML, no CSS, no scripts, no layout instructions beyond named options.

### Rich text

Inline content is a small **AST**, not HTML: an array of nodes, each text with optional `marks` (`strong`, `em`), a `link` (checked against the URL allowlist) or a `sourceRef`. Block-level structure comes from block types. This eliminates a whole class of injection and formatting problems and gives the AI a simple, hard-to-misuse target.

## Block taxonomy

Four tiers, deliberately ordered by risk. **Only the first three exist in the plan; the fourth is excluded.**

| Tier | Name | What it is | Who creates the *type* | Who uses it |
|---|---|---|---|---|
| **A** | **Declarative content blocks** | Content plus declared behaviour parameters; no data computation | InScapio | Publishers, AI |
| **B** | **Data blocks** | Driven by a `Dataset`; precomputed values; no formulas | InScapio | Publishers, AI (data supplied by publisher) |
| **C** | **Platform-built custom blocks** | Bespoke, engineered, tested, reviewed by InScapio when an idea needs a one-off interaction | InScapio engineers only | Selected publishers, by arrangement |
| ~~D~~ | ~~Publisher/AI-authored code~~ | ~~Scripts or components in content~~ | **Not permitted** | n/a |

A *constrained parametric-model block* (formulas in a small verifiable DSL) is **Future** and would sit between B and C. See [`ai-architecture.md`](./ai-architecture.md).

**Why tiers:** a finite vocabulary risks everything feeling templated (the central product risk). Tier C is the pressure-release valve: the climate model was *bespoke logic*, and a platform that cannot host that kind of idea will be limited. But it is a **service InScapio engineers provide**, not a hole through which unreviewed code enters.

## Blocks from the prototype

Mapping each prototype pattern to a block gives the starting vocabulary and a precise parity target. *Params* are the declared behaviour parameters; every interactive block also defines a **baseline** (non-JS) rendering.

| Block `type` | Prototype origin | Tier | Content | Params (examples) | Baseline (no JS) |
|---|---|---|---|---|---|
| `paragraph` (`lead`, `body`) | all prose | A | Rich text | `variant` | Text |
| `heading` | chapter H2/H3 | A | Text | `level` | Heading |
| `callout` | `.say`, `.an` | A | Rich text | `variant: statement\|note\|warning` | Blockquote/aside |
| `card` | `.card` | A | Label + rich text | `variant` | Aside |
| `deeper` (or `depth: "deeper"` on any block) | `.deep`, `.dp`, About demo | A | Any blocks | `label` | Visible, labelled "Going deeper" |
| `accordion` (layers) | Home bands; `LAYERS` | A | Items: title + body + colour key | `exclusive: bool` | Expanded list |
| `stepper` | honour ladder; culture ladder | A | Ordered steps: title + note | `cumulative: true` | Ordered list |
| `claims` (claim-and-response) | "What people say on X" | A | Items: theme, claim, response | `filterBy: theme`, `reveal: tap` | List of claim/response |
| `classify` | "Safety advice or blame?" | A | Prompt, categories, items with answer + feedback, closing | `reveal`, `showScore` | Items with answers |
| `selector-content` | "What you can do" personas | A | Options → content | `default` | All options listed |
| `compare-table` | claim / true / doesn't follow | A | Columns + rows | `stickyHeader` | Table |
| `resource-box` | Helpline box | A | Title, items (label + value), note | `emphasis` | List |
| `source-note` | Footer sources; "Demo data" note | A | Source refs, text | `kind: sources\|data-note` | Text |
| `scrubber-chart` | Climate | **B** | `datasetId`, axes, series, stats | `parameter`, `selector`, `prediction`, `themeBinding` | Data table + static summary |
| `image` | none today | A | Media ref, caption | `layout` | `<img>` with alt |
| `quote` | none today | A (Later) | Text, attribution, source | | Blockquote |
| `timeline` | none today | A (Later) | Dated entries | | List |
| `compare-slider` | Home Read↔Explore | A (Later) | Two blocks | `start` | Both shown stacked |
| `video`, `map`, `embed` | none today | Future | | | |

## Interaction behaviour: declarative, not coded

A behaviour is a **named type plus parameters** interpreted by the renderer's own code. Examples of what is and isn't allowed:

| Allowed | Not allowed |
|---|---|
| `"reveal": "after-each"` | `"onClick": "function(){…}"` |
| `"parameter": {"field": "year", "min": 2026, "max": 2070}` | Any expression evaluated from content |
| `"themeBinding": {"scalar": "warming", "from": "cool", "to": "hot"}` | Custom CSS |
| `"prediction": {"question": "…", "options": […]}` | A script that decides outcomes |

### Worked example: expressing the climate experience

The climate experience is the **hardest test of this model**, because its behaviour is computed by code today. The MVP route is *precomputation*:

1. A one-off **script** (kept in the repo, not shipped) runs the v0 model and emits a **Dataset**: for each city, year (2026–2070) and month, the temperature; plus a per-city, per-year **analogue city** and **simplified climate type**.
2. The `scrubber-chart` block references the dataset and declares the slider parameter (`year`), the selector (`city`), the series to draw, the stat cards, the **prediction** step (question and the correct option drawn from the analogue column), and the **theme binding** (`warming` scalar derived from the dataset).
3. The dataset carries `illustrative: true`, rendering the "Demo data, not a forecast" note automatically. A required `source-note` retains the real-source pointers.

**What this preserves:** every interaction a reader sees. **What it loses:** the ability for a *publisher* to change the model parameters, and the deterministic pseudo-shuffle of guess decoys becomes a precomputed field. **Size:** 20 cities × 45 years × 12 months ≈ 10,800 numbers, trivially small.

This is the Phase 1 acceptance test (see [`migration-strategy.md`](./migration-strategy.md)). If it cannot be expressed without custom code, that is *information* about where Tier C or the Future DSL is needed.

## Schema design rules

1. **One source of truth:** Zod schemas in `content/schema/`. TypeScript types, runtime validators and the JSON Schema given to the AI are all derived from them.
2. **Closed enums** for block types, themes, accents, layout variants. Unknown values are rejected, not ignored.
3. **Stable IDs** for sections and blocks (ULID/nanoid), never reused. Analytics, diffs, comments and provenance all hang off them.
4. **Required accessibility fields:** image `alt`, chart baseline, table headers, link text. Missing = invalid.
5. **Required honesty fields:** dataset `provenance`; `illustrative` flag; source `accessedAt`.
6. **Limits:** maximum document size, blocks per section, text length per field (proposed: document ≤ 500 KB; set precisely in Phase 1).
7. **No free-form escape hatch.** There is no `html`, `style`, `script` or `any` field. If something doesn't fit, the schema is extended deliberately.

## Validation layers

| Layer | Checks | When |
|---|---|---|
| **Structural** | Shape, types, enums, limits | Every write, every AI output, every read of old data |
| **Referential** | All `sourceRef`, `datasetId`, `mediaId`, `derivedFrom` resolve; IDs unique | Same |
| **Semantic** | Baseline defined; dataset/series consistent; accents valid for theme (contrast safe); depth rules | Same |
| **Editorial / policy** | Caveat only in "deeper"; unsourced statistic; minors / open-case flags | QA step (advisory) |
| **Accessibility** | Contrast table per theme × accent; alt text; structure | CI and QA |

Structural, referential and semantic failures **reject** the write. Editorial and policy results **advise**.

## Depth rules

- `depth: "surface"` (default) is always visible. `depth: "deeper"` is revealed by the reader (the view-level *Deeper* toggle, as in the prototype; per-block expansion is Later).
- **Rule:** the surface alone must be coherent and must not omit a caveat needed to interpret it. The QA step checks "caveat only in deeper".
- A deeper block follows the surface block it elaborates; the baseline renders it visibly labelled.

## Versioning and migration

- `schemaVersion` is an integer on every document.
- **Additive changes** (new optional field, new block type) do not bump the version.
- **Breaking changes** bump it and ship a **pure migration function** `migrate_N→N+1(doc)` with tests and fixtures.
- Documents are **migrated forward on read**; the renderer supports the current version only after migration. A background job can backfill, and the `experiences.schema_version` column shows what remains.
- **Deprecation:** a block type is deprecated by migration to its successor, never deleted while any revision uses it.

## The renderer contract

```
Structured Experience  ─►  validate/migrate  ─►  InScapio Renderer  ─►  Design-system components  ─►  Interactive experience
        (data)                (pure)            (registry, fault isolation)     (tokens + blocks)           (baseline + islands)
```

1. **Pure:** same document in → same output out.
2. **Registry:** `type → { schema, Baseline, Interactive?, a11y, analyticsEvents }`.
3. **Fault isolation:** an erroring block falls back to its baseline; the experience continues; the error is reported.
4. **Baseline-first:** all content is present in server HTML.
5. **Accessibility contract per block:** roles, keyboard map, announcements, reduced-motion behaviour, alternatives. Verified by automated tests.
6. **Declared analytics:** blocks emit only the events their schema lists.
7. **Presentation by tokens:** no block accepts raw style.
8. **Preview = production.**

## Adding a block: the checklist

A block is added only when:

1. It passes the interaction test ([`../design/design-principles.md`](../design/design-principles.md)).
2. It is useful for **more than one** experience.
3. The PR includes: Zod schema; baseline; interactive component (if any); accessibility contract; fixture; unit, axe and interaction tests; gallery entry; documentation of AI-facing guidance (when should the AI choose this block?).
4. The AI's block catalogue and evaluation set are updated so the interview/design stages can propose it.
5. It is recorded in [`../DECISIONS.md`](../DECISIONS.md) if it changes the vocabulary materially.

## Content and media security

- Links `https` only; blocked schemes and known-bad domains rejected.
- Media served from InScapio storage via a separate origin; remote hotlinking disallowed in the MVP.
- No SVG uploads from publishers in the MVP (script risk) unless sanitised.
- Rich text AST has no raw HTML path.
- A CSP forbids inline script outside nonces, so even a validator bug cannot execute injected script.

## Open content-architecture questions

Whether to store `knowledgeItems` inside the document or alongside it; how to represent per-claim sources in text (inline `sourceRef` vs claim objects); how translation/variants (Future) attach to the same blocks; whether `teaser` is a block or a dedicated structure. Tracked as design spikes for Phase 1.
