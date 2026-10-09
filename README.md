# InScapio

> **Don't just read it. Explore it.**

InScapio is an early-stage product exploring an **AI-native publishing platform for interactive knowledge experiences**: a place where a publisher's expertise becomes something a reader can explore, not just scroll.

**Status: Phase 0 (foundation).** There is a working HTML prototype and a set of planning documents. There is no production application yet.

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

## Planned

Phasing is a proposal in [`docs/product/mvp-scope.md`](docs/product/mvp-scope.md).

| Phase | Goal |
|---|---|
| **0** | Product, design and technical foundation (**this phase**) |
| **1** | Content schema + renderer spike: express both prototype experiences as data, render them in a Next.js app, prove parity with v0 |
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

Application code (`src/`, tests, tooling) does not exist yet and will be introduced in Phase 1.

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
