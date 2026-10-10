# InScapio

> **Don't just read it. Explore it.**

InScapio is an early-stage product exploring an **AI-native publishing platform for interactive knowledge experiences**: a place where a publisher's expertise becomes something a reader can explore, not just scroll.

**Status: Phase 1 (schema, renderer, design system) on branch `phase-1/schema-renderer`; Phase 0 is merged.** There is a frozen HTML prototype, a set of planning documents, and a small Next.js application that renders both prototype experiences from validated, versioned content. There is no database, auth, publisher studio or AI yet, and nothing here is deployed.

## Labels used in this repository

| Label | Meaning |
|---|---|
| **Current** | Exists and works today |
| **Planned** | Decided direction, scheduled in the phasing; not built |
| **Future** | Possible direction; not committed |

Nothing is described as built unless marked **Current**.

## What InScapio is

| | |
|---|---|
| **Readers** | Discover, read and *explore* ideas designed to be understood: simple first, deeper when curious. Editorial, immersive, honest about what is known. |
| **Publishers** | Bring what they know. An AI editorial partner interviews them, structures their knowledge, proposes where interaction helps, and produces an experience they review, edit and publish. |
| **AI-native publishing** | The AI produces **structured content**, never arbitrary HTML. InScapio's renderer and design system turn it into the experience. A human approves everything before it goes live. |

It is deliberately **not** an AI article writer, a Medium/Substack clone, a CMS with an AI sidebar, or an AI website builder. See [`docs/product/positioning.md`](docs/product/positioning.md).

## Current

- **Prototype v0**: a single-file HTML application with a home page, an About page and two hand-built experiences (*What will your city feel like in 2070?* and *Whose Body Is It?*), including feedback and sharing. It is the baseline for what InScapio looks and feels like.
  - Location: [`prototype/v0/index.html`](prototype/v0/index.html). **Frozen; do not edit.**
  - To view it, open the file in a browser. Fonts load from Google Fonts; it works without them.
  - What it contains in detail: [`docs/design/current-design-audit.md`](docs/design/current-design-audit.md).
- **Phase 0 documentation** (this repository's `/docs`).
- **Phase 1 application** (this branch; see [Phase 1 implementation note](#phase-1-implementation-note)): a Next.js app with a versioned content schema, a block renderer, a design-token system, and both v0 experiences migrated to data. Routes: `/`, `/about`, `/experiences/whose-body-is-it`, `/experiences/climate`.

## Planned

Phasing is a proposal in [`docs/product/mvp-scope.md`](docs/product/mvp-scope.md).

| Phase | Goal |
|---|---|
| **0** | Product, design and technical foundation (done) |
| **1** | Content schema + renderer spike: express both prototype experiences as data, render them in a Next.js app, prove parity with v0 (**this branch; see the implementation note for what was and was not verified**) |
| **2** | Platform: database, publisher auth, publish pipeline, public reader site, stored feedback |
| **3** | AI interview, structuring and structured editing |
| **4** | AI QA, human approval flow, revisions, analytics; invite the first outside publishers (closed alpha) |
| **5** | Reader-side growth: follow, email updates |

### Planned architecture (summary)

Next.js (App Router) + TypeScript · PostgreSQL via Supabase (data, auth, storage) · Claude API, server-side behind a provider interface · CSS Modules with design tokens · Vercel · Vitest + Playwright + axe. Core idea:

```
Publisher → AI conversation → structured content → experience schema → InScapio renderer → preview → human review → publish → reader experience
```

Rationale and alternatives: [`docs/architecture/architecture-overview.md`](docs/architecture/architecture-overview.md).

## Future

Reader accounts, follows, subscriptions and notifications; payments and premium content; publisher teams and organisations; a richer block library (timeline, map, video); a constrained model-definition block; embeds and an API.

## Development philosophy

1. **Foundation before features.** Decisions are written down ([`docs/DECISIONS.md`](docs/DECISIONS.md)).
2. **Structured content, not generated code.** Content, presentation and behaviour are separate.
3. **The experience serves the idea.** Interaction must earn its place.
4. **Honest, accessible, fast.** WCAG 2.2 AA and performance budgets are requirements.
5. **Evolve the prototype; don't abandon it.**
6. **Humans approve; AI proposes.**

Full principles: [`docs/product/principles.md`](docs/product/principles.md).

## Repository structure

```
README.md                  you are here
CLAUDE.md                  pointer so AI agents load the rules automatically
prototype/v0/index.html    frozen baseline (Current)
docs/
  README.md                index of the documents
  DECISIONS.md             decision log: check before proposing architecture
  OPEN-QUESTIONS.md        unresolved product questions
  product/                 vision, users, positioning, principles, MVP scope
  ux/                      information architecture, reader & publisher journeys, content model
  design/                  current-design audit, design principles, design-system direction
  architecture/            overview, frontend, backend, AI, content, migration strategy
  engineering/             workflow, coding principles, AI development guidelines
.github/                   pull request template
```

```
src/
  app/                     routes: home, about, experiences/[slug], not-found
  content/
    schema/                Zod schema: primitives, blocks, datasets, references, validate
    experiences/<slug>/    experience.json (+ datasets/*.json): the migrated v0 experiences
    site/pages.ts          copy for the platform's own pages
    load.ts                loads, merges and validates experiences (server side)
  renderer/                ExperienceView, block registry, blocks, scrubber chart, shell
  design-system/           tokens.css, accents, base.css, primitives
  components/              site chrome, feedback form, home pieces
scripts/                   one-off migration scripts that read the frozen v0 file
tests/                     unit (Vitest) and e2e (Playwright: routes, interactions, axe, parity)
```

## Setup

Requires Node 22 and pnpm 10 (`corepack enable`).

```bash
pnpm install --frozen-lockfile
pnpm dev                 # http://localhost:3000
pnpm build && pnpm start # production build
pnpm typecheck && pnpm lint
pnpm test                # unit and component tests (Vitest)
pnpm test:e2e            # Playwright: builds, serves on :3100, runs desktop (1280) and mobile (375)
```

Playwright uses the Chromium that is already installed (`PLAYWRIGHT_BROWSERS_PATH`); do not run `playwright install` in the cloud workspace. Fonts are self-hosted from npm packages, so no network is needed at runtime.

Regenerate migrated content from the frozen prototype (only needed if the extractors change):

```bash
pnpm generate:whose-body   # prototype/v0 -> src/content/experiences/whose-body-is-it/experience.json
pnpm generate:climate      # prototype/v0 -> src/content/experiences/climate/{experience.json,datasets/}
```

Deployment is deliberately not configured in this branch. `inscapio.in` is managed separately and is not touched by this work.

## Phase 1 implementation note

**What exists.** A strict, versioned Zod schema (`schemaVersion: 1`) with a closed vocabulary of 15 blocks; a renderer that is a compile-time-checked `switch` over block type (content never selects a component); both v0 experiences expressed as data; a precomputed climate dataset generated by running v0's own model code; and home, About, experience and not-found routes with real URLs.

**What was actually run and passed** (on this branch, Chromium only):

| Check | Result |
|---|---|
| `tsc --noEmit`, `eslint` | clean |
| Vitest (schema, content, loader, geometry, renderer, block behaviour) | 42 passed |
| Playwright, 1280 and 375 | 100 passed, 6 skipped by design (parity checks that are viewport independent run once, on desktop) |
| Parity: v0's model vs shipped dataset | 900 city-years (20 x 45): analogue city, simplified type, warmth, warmest/coldest month identical; monthly values within 0.005 C (2-decimal rounding) |
| Parity: displayed output | headline, year and stat tiles identical to v0 for all 20 cities at 5 years (100 states) |
| Parity: prediction | question, 3 options and right/wrong reveal text identical for all 20 cities |
| Parity: text | all 163 text items in v0's Whose Body hero/chapters/footer present; Climate, Home and About copy present |
| axe (WCAG 2.2 A/AA tags) | no violations on 4 routes at both widths, plus Deeper-on, all-expanded, dark mode, forced light, warm climate theme |
| No-JS baseline | deeper notes, layers, claim answers, stepper notes and every city's analogue are visible with JavaScript disabled |

**What was not verified.** Pixel-level visual parity (screenshots at both widths are saved to `test-results/parity/` for human review; v0 screenshots use fallback fonts because Google Fonts is blocked in the test environment). Firefox, Safari, real devices, and any screen reader (axe is automated and finds only a subset of problems; no manual VoiceOver/NVDA/TalkBack pass was done). Animation timing. The spline curve is a rendering of 12 monthly points rather than v0's 45-point cosine sampling; its worst deviation from the true curve is 0.036 C across the dataset, checked numerically but not by image diff. Performance on a mid-range phone. Anything about deployment.

**Intentional differences from v0** are listed in [`docs/architecture/migration-strategy.md`](docs/architecture/migration-strategy.md#phase-1-as-built).

**Known risk before any publication:** "Whose Body Is It?" discusses a real, recent criminal case involving minors. Its wording is migrated verbatim, including v0's request not to share the victims' identities, but it has had no editorial or legal review. See `docs/OPEN-QUESTIONS.md` Q-16.

## Working in this repository

**Everyone, human or AI:**

1. Read this README, then [`docs/README.md`](docs/README.md) and [`docs/DECISIONS.md`](docs/DECISIONS.md).
2. Follow the loop: *understand → inspect → read docs → plan → implement → test → review → report*.
3. Branch from `main`, keep changes small, open a pull request, squash-merge. See [`docs/engineering/development-workflow.md`](docs/engineering/development-workflow.md).
4. Update the docs in the same pull request as the change.

**AI agents specifically:** read [`docs/engineering/ai-development-guidelines.md`](docs/engineering/ai-development-guidelines.md). The short version: don't rewrite unrelated code, don't change architecture without explanation, don't delete features without approval, don't add dependencies casually, don't generate arbitrary HTML for AI-created experiences, and never edit `prototype/v0/`.

## Where to start

| If you want to… | Read |
|---|---|
| Understand the product | [`docs/product/vision.md`](docs/product/vision.md) |
| See what exists today | [`docs/design/current-design-audit.md`](docs/design/current-design-audit.md) |
| Understand the architecture | [`docs/architecture/architecture-overview.md`](docs/architecture/architecture-overview.md) |
| Know what's in and out of the MVP | [`docs/product/mvp-scope.md`](docs/product/mvp-scope.md) |
| Know what's undecided | [`docs/OPEN-QUESTIONS.md`](docs/OPEN-QUESTIONS.md) |
