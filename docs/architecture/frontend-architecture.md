# Frontend architecture

> **Status:** Phase 0 · Recommended. Nothing is built. See [`architecture-overview.md`](./architecture-overview.md) for the stack and rationale.

## Goals

1. **Reading is fast and works without JavaScript.** Interaction is an enhancement layered on content.
2. **Every experience is rendered by one renderer** from validated structured content.
3. **Interactive blocks are isolated** so that one block failing, or being heavy, doesn't break or slow the rest.
4. **The design system is the only place styling lives.**
5. **A small team, or an AI collaborator, can add a block safely** by following a checklist.

## Rendering strategy

| Surface | Strategy | Reason |
|---|---|---|
| Public experience pages | **Server Components**, statically generated and revalidated on publish (incremental regeneration) | Best SEO and first paint; content changes only on publish |
| Home, topics, publisher pages | Static with revalidation | Same |
| Studio | Server Components for data, **client components** for the conversation and editor | App-like and personalised |
| Preview | Dynamic, authenticated, `noindex` | Always current; same renderer |
| Interactive blocks | **Client islands**, loaded lazily (on visibility or on first interaction) | Pay JS cost only for what is used |

### Progressive enhancement contract

Every block has two renderings:

1. **Baseline (server, no JS):** readable, accessible HTML derived from content alone. A classify quiz renders as a list of statements with their answers and feedback in a `<details>` or an expandable list; a scrubber chart renders as a data table plus a static summary.
2. **Enhanced (client):** the interaction.

A block without a defined baseline cannot be added to the library. This is what makes the reading path work on slow connections, in crawlers and for assistive tech, and it doubles as the **data-table alternative** the prototype is missing for charts.

## Structure (proposed)

Proposed layout once the app exists. *Not created in Phase 0.*

```
src/
  app/                       # Next.js routes
    (reader)/                #   public site
      page.tsx               #   home
      experiences/[slug]/
      topics/[slug]/
      publishers/[handle]/
    (studio)/studio/...      #   publisher workspace (auth-required)
    (admin)/admin/...
    api/                     #   route handlers (webhooks, analytics ingest)
  content/                   # SCHEMA: pure TypeScript, no React, no I/O
    schema/                  #   Zod definitions: Experience, Section, Block types
    validate/                #   validators + migrations between schema versions
    fixtures/                #   canonical example experiences (used in tests + gallery)
  renderer/                  # Maps validated content → components
    registry.ts              #   block type → { component, fallback, schema version }
    Experience.tsx
    boundaries/              #   per-block error boundary with text fallback
  design-system/
    tokens/                  #   CSS custom properties + TS constants
    primitives/              #   Button, Chip, Callout, Card …
    blocks/                  #   one folder per block: schema, component, baseline, a11y notes, tests
    chrome/                  #   ExperienceBar, ReadingControls, Progress, Feedback, Share
  features/                  # Product features (not UI primitives)
    interview/  editor/  preview/  qa/  publish/  analytics/
  server/                    # Server-only
    db/  auth/  ai/  jobs/   #   repositories, AI services, job handlers
  lib/                       # Shared utilities
tests/ e2e/ docs/ prototype/
```

Rules enforced by lint/import boundaries:

- `content/` imports nothing from React, the database or the network.
- `renderer/` and `design-system/` import `content/` types, never the database.
- `server/` is never imported from client components.
- Features may import the design system; the design system never imports features.

## The renderer

```
Experience document ──► validate ──► registry lookup ──► block component ──► DOM
                         │ invalid          │ unknown/unsupported version
                         ▼                  ▼
                  fallback / error     baseline text rendering + log
```

- **Pure function of content.** Same document, same output. No hidden fetches inside blocks.
- **Registry-based.** Adding a block means registering a schema, a component and a baseline; nothing else changes.
- **Fault isolation.** Each block is wrapped by an error boundary that falls back to its baseline rendering and reports the error.
- **Version-aware.** Blocks declare which schema versions they accept; older documents are migrated forward on read (see [`content-architecture.md`](./content-architecture.md)).
- **Emits declared analytics events** only (a block's schema declares which events it can emit, so analytics cannot be added ad hoc).

## Block component conventions

Each block folder contains:

| File | Purpose |
|---|---|
| `schema.ts` | Zod schema for content, behaviour and presentation options |
| `Block.tsx` | Server component producing the **baseline** |
| `Interactive.tsx` | Client component for the enhanced behaviour (if any) |
| `Block.module.css` | Styles using tokens only |
| `a11y.md` | Roles, keyboard map, announcements, reduced-motion behaviour |
| `fixture.ts` | Example content used by tests and the gallery |
| `Block.test.tsx`, `e2e.spec.ts` | Unit + interaction tests |

## State

- **Document content** is immutable on the reader side.
- **Local interaction state** (which layer is open, a quiz score) lives inside the block's client component; no global store for reader pages.
- **Reader preferences** (theme, text size, Deeper, reduced-motion override) are small and persisted as **cookies** so the server can render them without a flash, with `localStorage` as a convenience mirror. Defaults follow the system (`prefers-color-scheme`, `prefers-reduced-motion`).
- **Studio state:** server is the source of truth; client state is cached and reconciled. A library like TanStack Query is acceptable; no global-store framework until needed.

## Styling

- **CSS Modules + CSS custom properties.** All raw values (colour, size, duration) come from tokens.
- Themes are token sets applied at a container (`data-theme`), including the per-section accent.
- **Data-bound theming** (the climate page's warming) is exposed as a block-level behaviour writing a single scalar custom property, as the prototype does with `--w`, because it is elegant and cheap.
- No runtime CSS-in-JS.

## Routing and URLs

- Real paths mirroring the prototype's scheme: `/experiences/[slug]`, `/topics/[slug]`, `/publishers/[handle]`, `/about`.
- Old hash aliases (`#/body`, `#/climate`) become redirects.
- In-page anchors (`#chapter-3`) remain native.
- Entering an experience keeps the **circular-reveal entrance** via the View Transitions API or an equivalent, with a no-motion fallback; the prototype's keyboard fallback (centre origin) is retained.

## SEO and sharing

- Server-rendered content; semantic headings; canonical URLs.
- `generateMetadata` per experience: title, description, Open Graph and Twitter tags.
- A generated **share image** per experience.
- Structured data (`Article`-style JSON-LD) where appropriate.
- Sitemap; `noindex` on preview and Studio.

## Accessibility

- Every block ships an **accessibility contract** and an automated axe test; interaction tests cover keyboard paths.
- Focus management on navigation (carry over from the prototype: focus the new `<h1>`).
- Add the missing **skip link**, chart data tables and persisted preferences.
- Contrast is verified per theme × accent in CI using the token table (closing the dark-theme accent gap).

## Performance

- Budgets in [`../design/design-principles.md`](../design/design-principles.md); enforced with Lighthouse/Web Vitals checks in CI on key pages.
- Self-hosted, subsetted variable fonts; load only the axes used.
- Lazy-load islands; no client JS on pages with only baseline blocks.
- Images: dimensions required, responsive, modern formats.
- Avoid large animation or charting libraries by default. The prototype draws its chart with a few dozen lines of SVG; prefer small purpose-built renderers to a general chart library unless a block truly needs one.

## Component gallery

Start with an **in-app gallery route** (development only) that renders every block's fixture in every theme. It doubles as the visual-regression baseline and as a reference for people and AI. A dedicated tool (e.g. Storybook) can be adopted in Phase 1 if it earns its keep.

## Testing (frontend)

| Layer | Tool | Covers |
|---|---|---|
| Schema and content | Vitest | Fixtures validate; migrations; invalid content rejected |
| Components | Vitest + Testing Library | Baseline output; interactions |
| Accessibility | axe via Playwright | Every block × theme; keyboard paths |
| End to end | Playwright | Reading with JS disabled; entering an experience; feedback submit |
| Visual | Playwright snapshots | Gallery at 375 / 1280 in each theme |
| Parity | Playwright against `prototype/v0` and the new app | See [`migration-strategy.md`](./migration-strategy.md) |

## What is intentionally undecided

Gallery tooling; whether to use TanStack Query; exact view-transition approach; chart helper approach; icon strategy. Each is a Phase 1 spike with a decision recorded in [`../DECISIONS.md`](../DECISIONS.md).

---

## Phase 1: as built

> **Status:** Current on branch `phase-1/schema-renderer`. Decisions: D-029 to D-034.

### Stack and layout

Next.js 16 (App Router, Turbopack), React 19, TypeScript 5.9 strict (`noUncheckedIndexedAccess`), CSS Modules plus CSS custom-property tokens, pnpm. Routes: `/`, `/about`, `/experiences/[slug]` (statically generated from the content folder, unknown slugs 404), not-found, plus redirects for v0's aliases.

### The renderer

`ExperienceView` (server) validates nothing itself: it receives an `Experience` that has already passed the loader. It builds a `RenderContext` (sources and datasets by id) and renders hero, sections and end notes. `BlockRenderer` is a closed `switch` over `block.type` with a `never` exhaustiveness check, wrapped per block in a client error boundary. Static blocks are server components; interactive blocks (`accordion`, `stepper`, `claims`, `classify`, `selector-content`, `scrubber-chart`) and the shell are client components that receive validated props.

`ExperienceShell` (client) owns Deeper, text size, light/dark and the progress line, and exposes them as `data-deeper`, `data-mode`, `--fs` and (for data-bound themes) `--warm`. Block styles respond to these in CSS, so server-rendered blocks never re-render when the reader toggles a preference.

### Progressive enhancement

All content is in the server HTML. `@media (scripting: none)` opens or shows every disclosed region and hides controls that need script. Tested with JavaScript disabled for both experiences.

### Scrubber

Pure geometry (`blocks/scrubber/geometry.ts`: scales, row interpolation, periodic Catmull-Rom path) is unit tested separately from the component. Width is measured with `ResizeObserver` (SVG `viewBox` follows the container, as in v0). Colours come from CSS classes using tokens, not from component code. Reduced motion skips the 1.5 s tween.

### Styling

Raw colours, sizes and durations appear only in `src/design-system/tokens.css`; components use role tokens. Themes are `data-theme="paper"` (light/dark by system preference or reader choice) and `data-theme="tarn"` (dark, data-bound). Section accents use `data-accent` to set `--c` and `--c-text`.

### Platform strings and copy

`src/renderer/ui-strings.ts` (UI wording) and `src/content/site/pages.ts` (home, About, footer, not-found copy). Experience wording is content (D-032).

### Tests

Vitest + Testing Library (schema, content, loader, geometry, renderer, block behaviour). Playwright at 1280 and 375: routes and console errors, overflow, interactions, axe, keyboard order, reduced motion, no-JS, and parity against the frozen prototype (D-036).

### Known gaps

Server render errors are not isolated per block (D-031). Inline `style` is used for two CSS variables (Q-22). Reading preferences are not persisted (Q-19). Only Chromium has been tested (Q-20).
