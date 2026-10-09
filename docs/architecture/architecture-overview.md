# Architecture overview

> **Status:** Phase 0 · Recommended architecture. **Nothing in this document is built.** Decisions are recorded in [`../DECISIONS.md`](../DECISIONS.md). Unconfirmed vendor facts are marked *(verify)*; check current documentation at implementation time.

## What the architecture must do

1. Let AI turn a publisher's knowledge into **structured content** and never into arbitrary front-end code. (Principles 5 and 6.)
2. Render that content as fast, accessible, SEO-friendly, richly interactive experiences.
3. Keep operational complexity low for a very small team.
4. Be changeable: the prototype taught us the block vocabulary will evolve.

## The core idea in one picture

```
 PUBLISHER SIDE (Studio)                                        READER SIDE
 ───────────────────────                                        ───────────
 Publisher                                                       Reader
    │ conversation                                                  ▲
    ▼                                                               │ HTML (server-rendered) + small client islands
 ┌───────────────┐   structured    ┌────────────────┐   validated   ┌──────────────────┐
 │ AI services   │ ─────────────►  │ Content store  │ ────────────► │ InScapio Renderer│
 │ (server only) │   proposals     │ (Postgres,     │   Experience  │ + Design system  │
 └───────────────┘                 │  versioned)    │   document    └──────────────────┘
        ▲  ▲                       └───────┬────────┘                      ▲
        │  └── schema + validators ◄────────┤                              │
        │                                   │ Draft → Revision → Approved → Publication
        └── human edits & approval ◄────────┘     (only a human can approve and publish)
```

Three rules hold everywhere:

- **AI writes data; the renderer writes pixels.**
- **One schema, owned by InScapio,** is the contract between AI, editor, store and renderer.
- **Preview and production use the same renderer.**

## System components

| Component | Responsibility | Where |
|---|---|---|
| **Web app (reader)** | Public pages, server-rendered; interactive blocks hydrated as needed | Next.js app |
| **Web app (Studio)** | Publisher workspace: interview, preview, editor, QA, publish, analytics | Same Next.js app, separate route group |
| **Content schema package** | Zod/TypeScript schema for experiences and blocks; validators; JSON Schema export for AI | Pure TypeScript module, no React |
| **Renderer + block library** | Map validated content → design-system components | React, with the design system |
| **Design system** | Tokens, primitives, block components, accessibility contracts | In the app repo; extractable later |
| **AI services** | Interview, structuring, editorial, experience design, QA | Server-side modules behind a provider interface |
| **Data layer** | Postgres: entities, revisions (JSONB), publications, feedback, analytics | Managed Postgres |
| **Auth** | Publisher and admin sign-in; roles; row-level authorisation | Managed auth |
| **Storage** | Media uploads, share images | Managed object storage |
| **Jobs** | Long-running AI work, aggregation | A table plus a worker; introduce a queue only when needed |
| **Observability** | Errors, logs, performance, AI cost | Hosted tooling |

## Recommended stack and why

*Evaluated against: fast development, maintainability, scalability, SEO, strong UX, secure auth, structured content, AI integration, low operational complexity.*

| Area | Recommendation | Alternatives considered | Why |
|---|---|---|---|
| **App framework** | **Next.js (App Router) + React + TypeScript** | Astro (islands); Remix / React Router; SvelteKit; Nuxt | One codebase serves a content-heavy public site *and* an app-like Studio. Server Components and static/incremental rendering give SEO and fast first paint; client components give rich interaction. The React ecosystem is the deepest source of hiring, libraries and AI-assistant familiarity. **Trade-off:** framework complexity and churn; some lock-in to Vercel conventions. **Astro** is the strongest challenger for the *reader* side (islands, minimal JS) but is weaker for the app-like Studio, and two frameworks is a cost we do not need yet. |
| **Language** | **TypeScript, strict** | JavaScript | The schema is the product; types across AI, store and renderer are the cheapest correctness tool available. |
| **Schema/validation** | **Zod** (single source) → JSON Schema for AI structured output | JSON Schema first; io-ts; Valibot | One definition produces types, runtime validation and AI output schemas. *(verify current Zod-to-JSON-Schema support at implementation)* |
| **Database** | **PostgreSQL via Supabase** | Neon + separate auth; PlanetScale (MySQL); Firebase; self-hosted Postgres | Relational model fits entities; JSONB fits versioned documents; Row-Level Security gives authorisation in the data layer; auth, storage and Postgres in one product keeps ops minimal. **Trade-offs:** vendor coupling; RLS is powerful but easy to misconfigure. **Mitigation:** plain Postgres features and standard SQL migrations, data access behind a repository layer, so exit is possible. |
| **Auth** | **Supabase Auth** (email magic link; OAuth later), cookie sessions for SSR | Auth.js; Clerk; Auth0; build our own | Integrated with RLS; no extra vendor. Never build our own. |
| **AI** | **Anthropic Claude API, server-side only**, behind a thin provider interface | Direct multi-provider; agent frameworks (LangChain etc.) | Strong long-context, instruction-following and structured output *(verify current features)*. A thin interface (not a heavy framework) keeps us able to swap models and keeps prompts and evaluations in our repo. |
| **Styling** | **CSS Modules + CSS custom-property tokens** | Tailwind; CSS-in-JS (runtime); vanilla-extract | The prototype's design is already token-based; zero runtime; works with Server Components; styles stay explicit. **Tailwind** is a reasonable alternative; this is a lower-stakes decision and is revisited if velocity suffers (D-015). |
| **Hosting** | **Vercel** (app) + **Supabase** (data) | Netlify; Cloudflare; AWS; self-host | Zero-ops previews per pull request and good Next.js support. Revisit if cost or lock-in bites. |
| **Region** | Near the primary audience (India-first suggests a Mumbai/South-Asia region for data) *(verify availability)* | | Latency and data-residency considerations. |
| **Testing** | **Vitest** (unit/schema), **Playwright** (E2E, visual, interaction parity), **axe** (accessibility) | Jest; Cypress | Fast, modern, runs the same scripts against the v0 prototype for parity. |
| **Observability** | Error tracking (e.g. Sentry) + structured logs + AI call logging | | Know when AI output fails validation; cost visibility. |

### What we are deliberately **not** choosing

- **MDX** as the content format. Powerful, but it embeds code and arbitrary components in content, exactly what Principle 6 forbids for AI output. (D-005)
- **A headless CMS product** as the core. The content model *is* the product; outsourcing it to a vendor schema would be a strategic mistake. A vendor CMS could still hold *marketing* pages.
- **A microservice architecture.** One deployable app and one database. Boundaries are enforced by code structure, not by network hops.
- **A heavy AI-agent framework.** Narrow, schema-bound functions we can test and evaluate.
- **A monorepo with many packages** on day one (D-019).

## Key flows

### Read (public)

1. Request hits a route; the server loads the **published revision** as an Experience document.
2. The document is validated, then rendered by Server Components. Text, headings, sources and all *no-JS* content are in the HTML.
3. Interactive blocks hydrate as client islands, lazily, near the viewport.
4. Per-experience metadata and share image are generated server-side.
5. Reader preferences (theme, text size, Deeper) are cookies so the server renders them without a flash.

### Create (Studio)

1. Publisher starts a draft; an **interview session** begins (streaming).
2. Interview turns produce **knowledge items**; the structuring step proposes an outline; generation proposes blocks. **Each AI output is validated against the schema** before it touches the draft.
3. Preview renders the draft through the production renderer.
4. Edits and AI revisions create **revisions** (immutable).
5. QA runs; the publisher resolves findings and presses **Approve and publish**, a server action requiring the publisher's identity. AI service credentials cannot perform it.

## Boundaries and rules

| Rule | Enforced by |
|---|---|
| AI never emits HTML or code to readers | Output schema validation; renderer accepts only the schema; CSP; tests |
| AI cannot publish | Separate database role/permissions; publish requires human session; test asserts it |
| Content has no scripts, raw CSS or raw HTML | Schema forbids; links and media URLs checked against allowlists |
| Reader pages work without JS for the reading path | Server rendering; E2E test with JS disabled |
| Secrets never reach the browser | Server-only modules; lint rule; env separation |
| Draft/preview never indexed | `noindex`, auth, separate route group |

## Environments

| Environment | Purpose | Data |
|---|---|---|
| **Local** | Development | Local Postgres (via the vendor's local stack) with seed data; no real AI keys by default (recorded fixtures) |
| **Preview** | One per pull request | Shared "staging" database; AI calls on a low spend limit |
| **Production** | Real users | Separate project, backups on, strict keys |

Three environments, not four. A fourth ("staging" distinct from preview) is added only when the team needs it.

## Non-functional targets (proposed)

Performance, accessibility and security targets live in [`../design/design-principles.md`](../design/design-principles.md) and [`../engineering/development-workflow.md`](../engineering/development-workflow.md). In summary: LCP ≤ 2.5s p75 on mobile, WCAG 2.2 AA enforced in CI, schema validation on every write, row-level security on every table, and no third-party trackers.

## Where the detail is

| Topic | Document |
|---|---|
| Frontend structure, renderer, islands | [`frontend-architecture.md`](./frontend-architecture.md) |
| Data, auth, jobs, security, privacy | [`backend-architecture.md`](./backend-architecture.md) |
| AI capabilities, guardrails, evaluation | [`ai-architecture.md`](./ai-architecture.md) |
| Schema, blocks, renderer contract | [`content-architecture.md`](./content-architecture.md) |
| Prototype → production plan | [`migration-strategy.md`](./migration-strategy.md) |
