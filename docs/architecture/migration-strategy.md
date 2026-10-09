# Migration strategy: prototype v0 → production InScapio

> **Status:** Phase 0 · Plan. Nothing is migrated in Phase 0. The prototype remains frozen at [`/prototype/v0/index.html`](../../prototype/v0/index.html).

## Principle

**Evolution, not abandonment.** The prototype contains the product's identity and its best interaction ideas. The production application should be able to *show* both existing experiences, faithfully, as the first proof that the new architecture is sound.

We do not copy the code. We **extract the content, data and behaviour**, **rebuild them in the new architecture**, and **prove parity** with automated tests against the original.

## What goes where

| Aspect of v0 | Disposition | Detail |
|---|---|---|
| Product line, philosophy, About copy | **Preserve** | Moves into content/marketing pages unchanged |
| Brand: wordmark, favicon idea, colour and type tokens | **Preserve → extract** | Become design tokens |
| Two-weight display title treatment | **Preserve** | A named text style |
| Interaction patterns (§1.3 of the audit) | **Extract → rebuild** | Each becomes a block with a schema and baseline |
| All experience text | **Extract → content** | Into Experience documents |
| `C` cities, `LAYERS`, `Q`, `A`, `M`, `W`, steps, sources | **Extract → content/data** | Into block content and a Dataset |
| Climate model maths | **Extract → one-off dataset generator** | Script emits a Dataset; model itself not shipped (see [`content-architecture.md`](./content-architecture.md)) |
| Chapter accents | **Extract → presentation tokens** | A closed palette with light/dark variants |
| Entering transition, progress, reading controls | **Rebuild as platform chrome** | Preserve behaviour and reduced-motion handling |
| Honesty components (data notes, sources) | **Preserve → make structural** | Required fields in the schema |
| Hash router | **Rewrite** | Real paths, server rendering, per-route metadata |
| `innerHTML` rendering | **Rewrite** | Typed components; no HTML from content |
| DOM-as-state | **Rewrite** | Explicit per-block state; persisted preferences |
| Feedback and share | **Rewrite as services** | Feedback stored server-side; share with real previews |
| Two visual systems | **Redesign (later)** | Harmonise or formalise as two themes; not during parity |
| Discovery (two hard-coded rooms) | **Redesign (MVP)** | Data-driven home built from published experiences |
| Google Fonts hot-link | **Replace** | Self-hosted, subsetted |
| Wrapper/duplicate doctype in the file | **Drop** | An export artefact |

## Parity: what "equivalent" means

Parity is defined **per experience** and tested automatically. **Differences are allowed only if listed under "intended improvements".**

| Dimension | How it is checked |
|---|---|
| **Text** | Extract visible text (surface and deeper) from v0 and from the new page; diff. Target: identical, apart from listed edits. |
| **Behaviour** | A Playwright script suite exercises each interaction on **both** v0 and the new app and compares observable results (e.g. classify scoring text; stepper reveal state; climate analogue for each city at 2070 and the headline). |
| **Visual** | Screenshot comparison at 375px and 1280px, each theme, with tolerance; deliberate differences recorded. |
| **Accessibility** | axe results no worse than v0; keyboard script passes; reduced-motion behaviour equivalent. |
| **Performance** | Not worse than v0 on the same device profile; reading path works with JS disabled (new capability). |

### Intended improvements (allowed differences)

These are known gaps from the audit, to be closed as part of the migration, not accidents:

1. Dark-theme accent-text contrast.
2. Skip link.
3. Data-table alternative for the chart.
4. Persisted reading preferences.
5. Real URLs and per-experience share metadata.
6. Feedback stored server-side.
7. Self-hosted fonts.
8. `color-mix()` guard in the Whose Body styles.

## Order of work

Each step ends with something demonstrable, and the prototype stays as the reference throughout.

| Step | Work | Proves |
|---|---|---|
| 1 | Scaffold the app; tokens; fonts; the page chrome (home nav, footer) | The visual identity survives |
| 2 | Content schema (core), validators, fixtures | The schema is expressible and testable |
| 3 | Primitives and simple blocks: paragraph, heading, callout, card, deeper, source-note, resource-box | The renderer works end to end |
| 4 | **"Whose Body Is It?"** as a document: accordion, stepper, claims, classify, selector, compare-table | The Tier-A vocabulary is sufficient (most of the experience) |
| 5 | Parity suite for Whose Body; fix differences | The method works |
| 6 | **Climate** as a document: dataset generator, `scrubber-chart` with prediction and theme binding | **The key question:** can Tier B express a computed experience? |
| 7 | Parity suite for Climate | |
| 8 | Home and About, built from data; the circular-reveal entrance | The platform pages |
| 9 | Platform chrome: reading controls, progress, feedback, share | |
| 10 | Archive v0 (keep in `prototype/v0`, mark as reference, do not delete) | |

Steps 1–10 are the **Recommended Phase 1** (in the final Phase 0 report). Persistence, auth and AI are *not* part of it; experiences are loaded from files in the repo. That isolates the riskiest architectural question (can the schema and renderer express what v0 does?) from everything else.

## Risks

| Risk | Mitigation |
|---|---|
| The climate experience cannot be faithfully expressed as data | Treat as information. Fall back to a Tier C custom block for it, or extend `scrubber-chart`. Record the decision. |
| Visual drift while "rebuilding" | Screenshot parity; tokens extracted from v0 values; designer sign-off at each step |
| Scope creep ("while we're here…") | Parity first; redesign and new features only after parity passes; every intended improvement is listed |
| Over-engineering the schema before it meets real content | Express *real* v0 content first; add fields only when a block needs them |
| Losing interaction details (e.g. focus management, reduced-motion) | The audit lists them; the accessibility contract per block; keyboard parity scripts |
| Content in v0 that carries legal/editorial risk (real recent case) | Flag during extraction; apply the editorial/legal review process before any public launch |

## What is *not* migrated

- The v0 file's structure, CSS organisation and JavaScript.
- The "demo model" as runtime logic.
- The Whose Body override-skin layer (replaced by tokens/themes).

## Rollback and reference

`prototype/v0/` is permanent reference. If the production build ever regresses on a core interaction, the original remains available to compare, restore from, or demonstrate.
