# Decision log

> **Purpose:** record significant decisions so future sessions (human or AI) do not re-open them without reason.
> **Rules:** append new decisions; never delete. To change one, add a new decision that **supersedes** it and update the old one's status. Check this file before proposing architecture.
> **Statuses:** `Accepted` (settled), `Proposed` (made in Phase 0, **pending owner review**), `Superseded by D-xxx`.

Template for new entries:

```
## D-0xx · <Decision title>
- Context:
- Options considered:
- Decision:
- Reason:
- Trade-offs:
- Status:
```

---

## D-001 · Keep the existing prototype as a frozen baseline in the repository
- **Context:** The repository was empty. The existing single-file HTML app is the only record of what InScapio currently is, and Phase 0 documents refer to it.
- **Options considered:** (a) don't store it; (b) store it and refactor it in place; (c) store it byte-identical as a reference.
- **Decision:** Store it unmodified at `prototype/v0/index.html` (SHA-256 `d7c21eac…6061fa`). Never edit it.
- **Reason:** It is the source of truth for what exists, the parity target for migration, and the original reference if production regresses.
- **Trade-offs:** A 76 KB file of legacy structure lives in the repo. The file contains an export wrapper and a duplicate doctype, which we leave alone.
- **Status:** Accepted

## D-002 · Phase 0 is documentation-first; no application scaffold
- **Context:** The brief asks for foundation before code, and warns against "the appearance of progress".
- **Options considered:** (a) docs only; (b) docs plus a minimal Next.js scaffold; (c) start building.
- **Decision:** (a). The only non-doc files are the frozen prototype, a `.gitignore`, a PR template and a root `CLAUDE.md` pointing at the docs.
- **Reason:** A scaffold would embed framework and structure choices before they are reviewed. The first code should be the schema/renderer spike (Phase 1).
- **Trade-offs:** Repository has no runnable app after Phase 0.
- **Status:** Accepted

## D-003 · Position InScapio as "AI-native publishing of interactive knowledge experiences"
- **Context:** Must distinguish from Medium, Substack, CMSs, AI writing tools, AI site builders and news sites without unsupported claims.
- **Options considered:** (a) better blogging platform; (b) AI writing assistant; (c) AI-native publishing of interactive experiences; (d) interactive-journalism toolkit.
- **Decision:** (c). See [`product/positioning.md`](./product/positioning.md).
- **Reason:** The output (interactive experience) and the method (AI interview → structure) are both distinctive and both match the prototype's thesis. Defensibility, if any, comes from the schema/renderer and the pipeline, not from text generation.
- **Trade-offs:** Narrower than "publishing platform"; depends on publishers valuing interactivity. Closest competitors in output are tools and studios, not blogs.
- **Status:** Proposed

## D-004 · AI produces structured content, never front-end code; content, presentation and behaviour are separate
- **Context:** Owner's stated architectural principle. The prototype interleaves these.
- **Options considered:** (a) AI generates HTML/JS; (b) AI generates MDX; (c) AI generates schema-validated structured content rendered by InScapio.
- **Decision:** (c). Three layers: content (what is said), presentation (closed design-system options), behaviour (declared parameters).
- **Reason:** Safety (no AI code in readers' browsers), quality (accessibility and design by construction), improvability (one renderer upgrade improves all content), and enforceable human review.
- **Trade-offs:** A finite vocabulary risks templated output and can't express every idea. Mitigated by tiers (D-006).
- **Status:** Accepted (owner-stated)

## D-005 · Store experiences as versioned JSON documents validated by Zod; not MDX, HTML or fully normalised rows
- **Context:** Need a content format AI can generate safely, the renderer can consume, and the system can version, diff and migrate.
- **Options considered:** (a) HTML; (b) MDX; (c) normalised relational blocks; (d) JSON document per revision, schema in code.
- **Decision:** (d), with `schemaVersion` and forward migrations. Rich text is a small AST, not HTML.
- **Reason:** MDX and HTML include a code channel, which D-004 forbids. Whole-document revisions make versioning and restore simple. One Zod schema yields types, validation and the AI output schema.
- **Trade-offs:** Querying inside content is harder than with rows; real-time collaborative editing would need rework. Both acceptable for the MVP.
- **Status:** Proposed

## D-006 · Tiered block vocabulary; no publisher- or AI-authored code
- **Context:** The prototype's two experiences differ radically (a computed climate model versus accordions and quizzes). A finite vocabulary risks being too small.
- **Options considered:** (a) declarative blocks only; (b) allow custom code blocks from publishers; (c) tiers: declarative → data-driven → platform-built custom → (Future) constrained model DSL; never arbitrary code.
- **Decision:** (c).
- **Reason:** Keeps a pressure-release valve for bespoke ideas without opening a code channel.
- **Trade-offs:** Tier-C blocks are engineering work done by InScapio and don't scale to every publisher. The DSL is substantial Future work.
- **Status:** Proposed

## D-007 · One entity, `Experience`; "Story" is a *kind*, not a separate record
- **Context:** The brief lists both Story and Experience.
- **Options considered:** (a) both entities; (b) Experience only, with `kind`; (c) Story as the knowledge, Experience as a rendering of it.
- **Decision:** (b).
- **Reason:** Two names for one thing invites ambiguity; a link between experiences can be added later if one body of knowledge needs several formats.
- **Trade-offs:** No native "same story, several formats" relationship yet.
- **Status:** Proposed

## D-008 · MVP is a closed alpha: invite-only publishers, anonymous readers, no accounts or payments
- **Context:** The MVP must test whether publishers can produce experiences they prefer to their own articles, and whether readers engage.
- **Options considered:** (a) full two-sided product; (b) publisher-only tooling; (c) closed alpha with a thin but excellent reader side.
- **Decision:** (c). See [`product/mvp-scope.md`](./product/mvp-scope.md).
- **Reason:** Reader accounts, follows and payments don't help prove the core claims and add privacy and compliance burden.
- **Trade-offs:** No retention mechanics in the MVP; limited reader signal beyond aggregate analytics and feedback.
- **Status:** Proposed

## D-009 · Next.js (App Router) + React + TypeScript
- **Context:** Needs SEO and fast first paint for public pages and an app-like Studio, with a small team.
- **Options considered:** Next.js; Astro (islands); Remix / React Router; SvelteKit; Nuxt.
- **Decision:** Next.js with TypeScript (strict).
- **Reason:** One codebase serves both surfaces; Server Components plus client islands fit the baseline-then-enhance model; largest ecosystem and hiring pool.
- **Trade-offs:** Framework churn and complexity; some Vercel-conventions lock-in. Astro would be lighter for the reader side but means two frameworks.
- **Status:** Proposed

## D-010 · Supabase (Postgres, Auth, Storage) behind a repository layer
- **Context:** Needs relational data, JSON documents, authorisation, auth and file storage with minimal operations.
- **Options considered:** Supabase; Neon + separate auth + storage; Firebase; self-hosted Postgres.
- **Decision:** Supabase, with plain SQL migrations, RLS on every table, and a repository layer.
- **Reason:** One managed product for four needs; Postgres is portable.
- **Trade-offs:** Vendor coupling; RLS is easy to misconfigure (hence tests). Exit path preserved by standard Postgres.
- **Status:** Proposed

## D-011 · Claude API, server-side only, behind a thin provider interface; models are configuration
- **Context:** The AI workflow is central; model landscape changes fast.
- **Options considered:** Claude directly; multi-provider abstraction frameworks; agent frameworks.
- **Decision:** Claude via a thin in-repo interface (`generateStructured`, `streamConversation`); model IDs in configuration; prompts and evaluation sets versioned in the repo.
- **Reason:** Keeps prompts, schemas and evaluations ours; permits swapping models; avoids heavyweight frameworks.
- **Trade-offs:** We build a small amount of plumbing ourselves.
- **Status:** Proposed

## D-012 · Vercel (app) and Supabase (data); three environments: local, preview, production
- **Context:** Low operational complexity; previews per PR.
- **Options considered:** Vercel/Supabase; Netlify; Cloudflare; AWS; self-hosted. Three versus four environments.
- **Decision:** Vercel + Supabase; local, preview (shared staging data), production.
- **Reason:** Minimal ops; fast iteration.
- **Trade-offs:** Cost and lock-in need watching; preview shares a staging database, so data hygiene matters.
- **Status:** Proposed

## D-013 · Trunk-based Git workflow: protected `main`, short-lived feature branches, squash-merged PRs
- **Context:** Small team plus AI collaborators; the owner wants few branches and meaningful commits.
- **Options considered:** Gitflow; trunk-based with feature branches; direct commits to `main`.
- **Decision:** Trunk-based; prefixes `feat/ fix/ docs/ chore/ refactor/ exp/ phase-N/`; Conventional Commits; squash merge; experiments never merged directly. See [`engineering/development-workflow.md`](./engineering/development-workflow.md).
- **Reason:** Simple, reviewable, easy rollback.
- **Trade-offs:** Needs discipline on small PRs and feature flags.
- **Status:** Proposed

## D-014 · Testing strategy: Vitest, Playwright, axe, schema fixtures, RLS tests, AI evaluation sets
- **Context:** Quality, accessibility and AI correctness are core to the product.
- **Options considered:** Jest/Cypress; Vitest/Playwright; minimal testing.
- **Decision:** Vitest + Testing Library; Playwright (E2E, visual, parity); axe in CI; fixtures validated against the schema; RLS tests; AI evaluation sets.
- **Reason:** Fast, modern, and the same Playwright scripts can run against `prototype/v0` for parity.
- **Trade-offs:** Several suites to maintain; slower suites run nightly or on label.
- **Status:** Proposed

## D-015 · Styling: CSS Modules with CSS-custom-property design tokens (no runtime CSS-in-JS)
- **Context:** The prototype already has tokens and fluid CSS; Server Components favour zero-runtime styling.
- **Options considered:** CSS Modules + tokens; Tailwind; CSS-in-JS; vanilla-extract.
- **Decision:** CSS Modules + tokens.
- **Reason:** Preserves the prototype's token approach; explicit, zero-runtime.
- **Trade-offs:** More hand-written CSS than Tailwind. Low-stakes; revisit if velocity suffers.
- **Status:** Proposed

## D-016 · Real URL paths, preserving `/experiences/<slug>`; hash routing is retired
- **Context:** The prototype's routes already mirror intended clean URLs, but fragments are invisible to crawlers and link unfurlers.
- **Options considered:** Keep hash routing; real paths.
- **Decision:** Real paths with server-rendered per-page metadata; old aliases become redirects.
- **Reason:** SEO, correct share previews, resilience.
- **Trade-offs:** Requires a server (already implied by D-009).
- **Status:** Proposed

## D-017 · WCAG 2.2 AA is enforced, not aspirational
- **Context:** The prototype's accessibility baseline is strong and is a brand asset.
- **Options considered:** Best-effort; manual audits only; automated + manual.
- **Decision:** Automated axe in CI, per-block accessibility contracts, contrast verified per theme × accent, manual review per release.
- **Reason:** Prevents regression and makes accessibility a property of the platform (Principle 6).
- **Trade-offs:** Extra work per block.
- **Status:** Proposed

## D-018 · Human approval is an enforced state; AI credentials cannot approve or publish
- **Context:** Principle 5.
- **Options considered:** Convention in application code; enforcement in the data layer.
- **Decision:** `approvals` and `publications` are writable only through a human-session server action; the AI service uses a separate credential lacking that permission; a test asserts it.
- **Reason:** A rule that cannot be bypassed by a prompt injection or a bug is worth more than one that is only followed.
- **Trade-offs:** More deliberate permissions design.
- **Status:** Proposed

## D-019 · One application, modular boundaries; no multi-package monorepo yet
- **Context:** Small team; the schema, renderer and design system might later be shared.
- **Options considered:** Monorepo with packages; single app with enforced import boundaries.
- **Decision:** Single Next.js app. `content/`, `renderer/`, `design-system/` are separated by lint-enforced boundaries so they can be extracted later.
- **Reason:** Lowest overhead now; extraction stays cheap.
- **Trade-offs:** Boundaries are enforced by lint, not by package manifests.
- **Status:** Proposed

## D-020 · Migrate by re-expressing v0 as data first, with a parity gate; Phase 1 is a schema + renderer spike
- **Context:** The riskiest assumption is that a finite vocabulary can express what v0 does.
- **Options considered:** Rebuild the UI first; build backend first; schema/renderer spike with parity tests.
- **Decision:** Phase 1 expresses both experiences as documents and renders them, with parity tests against v0. No database, auth or AI in Phase 1.
- **Reason:** Tests the highest-risk architectural claim in isolation, cheaply.
- **Trade-offs:** Delays visible "product" features; may reveal that the schema needs rethinking, which is the point.
- **Status:** Proposed

## D-021 · Add a root `CLAUDE.md` and a PR template as minimal repository files
- **Context:** Future AI sessions have no memory; the repo is the memory. The brief asks for AI coding rules and a Definition of Done.
- **Options considered:** Docs only; docs plus an auto-loaded pointer.
- **Decision:** A short `CLAUDE.md` that points to the documents, and `.github/pull_request_template.md`.
- **Reason:** Rules are only useful if they are loaded when work starts.
- **Trade-offs:** Two small files outside `/docs`; must be kept in sync.
- **Status:** Proposed

## D-022 · Analytics: first-party, aggregate, privacy-light; no third-party trackers
- **Context:** Publishers need signal on understanding, not page views; readers are anonymous; compliance exposure should stay low.
- **Options considered:** Third-party analytics; self-hosted analytics product; own minimal aggregate counters.
- **Decision:** Own aggregate counters from a small set of declared block events.
- **Reason:** Aligns with D-008, privacy, and the "analytics that explain understanding" differentiator.
- **Trade-offs:** Less flexible than a full analytics product; we build the dashboards.
- **Status:** Proposed

---

# Decisions made in Phase 1 (schema, renderer, design system)

Status for these entries is **Accepted (implemented on `phase-1/schema-renderer`)** unless stated; they become final when the PR is merged.

## D-023 · Strict, closed, versioned content schema in Zod; 15 blocks
- **Context:** D-004/D-020 require a validated vocabulary that can express v0.
- **Decision:** Every object is `z.strictObject`; unknown keys (`style`, `html`, `onClick`, `className`) are rejected. Blocks are a discriminated union of exactly 15 types: `paragraph`, `callout`, `card`, `fact-row`, `compare-table`, `resource-box`, `source-list`, `data-note`, `deeper`, `accordion`, `stepper`, `claims`, `classify`, `selector-content`, `scrubber-chart`. Documents carry `schemaVersion: 1`. Rich text is a tiny AST (text with `strong`/`em`, and `sourceRef`). Text that looks like markup, non-https URLs and control characters are rejected.
- **Reason:** Only what v0 needs; nothing speculative. Rejection at validation, plus React's text-only rendering, is two lines of defence.
- **Differences from the Phase 0 proposal:** no `heading` block (section titles are structure); `source-note` split into `source-list` and `data-note`; no per-block `depth` field (see D-024); no `teaser`, `media`, `subtitle`, `derivedFrom`; no `image`/`quote`/`timeline`/`compare-slider`.
- **Trade-offs:** adding a block is a schema + component + test + docs change (intended friction).

## D-024 · "Deeper" is a container block with a closed set of children
- **Context:** the proposal allowed `depth: "deeper"` on any block.
- **Decision:** `deeper` is a block whose children are only `paragraph` or `compare-table`. Reader-wide state ("Deeper" toggle) is a data attribute on the experience root, so deeper blocks are shown by CSS.
- **Reason:** v0 only ever deepens prose and one table; a per-block flag would have allowed deeper interactive blocks that nothing needs and that complicate the no-JS baseline.
- **Trade-offs:** cannot deepen an interactive block. Revisit if a real experience needs it (Q-21).

## D-025 · Datasets are first-class, and illustrative data must be disclosed structurally
- **Decision:** `Dataset` carries `illustrative` and `provenance.kind` (`illustrative-model` | `publisher-supplied` | `cited-source`). Validation fails if an illustrative dataset is used by a block and the document has no `data-note` block. Dataset values live in `datasets/*.json`, merged by the loader.
- **Reason:** principle 7 (honesty) enforced by the schema rather than by reviewers remembering.
- **Trade-offs:** a data-note can be present but unhelpful; the check guards absence, not quality.

## D-026 · Climate: precompute from v0's own model; the renderer does no modelling
- **Decision:** `scripts/generate-climate-dataset.mjs` extracts v0's model code from the frozen file, runs it in a Node `vm`, and writes 20 cities x 45 years x 12 months (2 d.p.) plus per-(city, year) analogue, type, warmth, warmest and coldest month. Prediction options (decoys) are precomputed with v0's `guess()` logic. The renderer draws a periodic Catmull-Rom spline through the 12 values and interpolates linearly between years while a tween runs (curves exact, stats approximate mid-tween, discrete outputs use the nearest year).
- **Reason:** v0's behaviour was code; this proves it can be expressed as data. Parity is testable against v0's runtime values.
- **Result:** no schema escape hatch was needed. Cost: ~150 KB JSON (Q-18); publishers cannot change the model.
- **Verified:** 900/900 city-years identical on analogue, type, warmth and extremes; worst monthly deviation 0.005 C (rounding).

## D-027 · Fonts: Fontsource variable packages, self-hosted through the bundler
- **Decision:** `@fontsource-variable/bricolage-grotesque` and `@fontsource-variable/literata` (OFL-1.1). No font binaries are committed. Runtime makes no third-party font request.
- **Trade-offs:** the Fontsource Bricolage build has weight and width axes but **no optical-size axis**, which v0 requested from Google Fonts; large display sizes may differ slightly. Literata keeps `opsz`.
- **Status:** Accepted; revisit if the display type looks off at hero sizes.

## D-028 · Accent text variants fix v0's dark-theme contrast
- **Decision:** accents have a fill colour and separate light/dark **text** colours, selected with `light-dark()`. All are at least 4.5:1 on page and card surfaces in both modes.
- **Reason:** v0 used the fill colour for text; in the dark reading theme this fell to 2.3 to 3.96:1.
- **Intended change:** listed in the migration strategy.

## D-029 · Progressive enhancement via server-rendered content and `@media (scripting: none)`
- **Decision:** every block renders its full content in the server HTML; client components only add interaction. Under `@media (scripting: none)` deeper notes, layers, claim answers, stepper notes and the selector's options are shown, and the scrubber shows each group's final-year analogue as a list.
- **Reason:** the reading path must work without JavaScript (reader-journey quality bar) with no extra markup duplication beyond small baselines.
- **Trade-offs:** `scripting` media query needs a current browser; older browsers without it hide the baselines and rely on JavaScript, as v0 did.

## D-030 · Reading state lives in the experience shell and is not persisted
- **Decision:** Deeper, text size and light/dark are shell state exposed as data attributes (`data-deeper`, `data-mode`) and a CSS variable (`--fs`). The data-bound theme variable `--warm` is set by the scrubber through a small shell context. Preferences are **not** persisted (v0 did not); persistence would cause a flash on load.
- **Status:** Accepted; see Q-19.

## D-031 · The renderer is a closed `switch`; blocks fail in isolation
- **Decision:** `BlockRenderer` switches on `block.type` with an exhaustiveness check. No dynamic imports, no component names in content. Each block sits in a client error boundary.
- **Limitation (honest):** a client boundary catches client-side faults only; a server render error still reaches Next's error handling. Content is validated before render, so this is a second line of defence.

## D-032 · Copy lives in data, not components
- **Decision:** experience wording is in `src/content/experiences/`; platform page copy (home, About, footer, not-found) is in `src/content/site/pages.ts`; platform UI strings (buttons, status messages) are in `src/renderer/ui-strings.ts`.
- **Reason:** CLAUDE.md forbids hard-coded content in components, and this is the seam for later localisation.

## D-033 · Content loader: folder per experience, hard failure on invalid content
- **Decision:** `src/content/experiences/<slug>/experience.json` plus optional `datasets/*.json`; the loader merges and validates and **throws** with the first 20 issues. A folder name must equal the document's `slug`. Routes are statically generated from the folder list; unknown slugs are 404.

## D-034 · v0 hash aliases become permanent redirects; no deployment configuration
- **Decision:** `/body`, `/climate`, `/explore` redirect to the clean URLs in `next.config.ts`. No Netlify, DNS or deploy files were added; production deployment is out of scope for this branch.

## D-035 · Feedback behaves as in v0 (local only)
- **Decision:** answers go to `localStorage["inscapio"]` and the clipboard; the stored record key is now the experience slug. They still reach nobody (Q-17).

## D-036 · Parity is tested against the frozen file, loaded from disk
- **Decision:** Playwright opens `prototype/v0/index.html` via `file://`, reads its own globals (`C`, `temp`, `stats`, `kind`, `feels`) for all 900 city-years, and drives both pages for displayed output. Text parity asserts every v0 text item exists in the new page (one direction; the new page adds labels such as "Going deeper" as real text). Screenshots are saved, not diffed.
- **Trade-offs:** does not catch visual regressions or things v0 never displayed.

## D-037 · Chapter 7 link fix is an intentional difference
- **Decision:** v0's "Jump to the arguments" targeted chapter 6 ("Risk or blame?"); the label describes chapter 7 ("The arguments"), so the migrated link targets chapter 7.

---

# Proposed in Phase 1.5 (product design review; documentation only)

Status for these entries is **Proposed, pending owner review**. Nothing is implemented. See [`design/phase-1-5-product-design-review.md`](./design/phase-1-5-product-design-review.md).

## D-038 · Experiences share a predictable reader shell; subject-specific content lives in the body
- **Context:** the review found the gaps in both experiences are mostly platform-level (size and structure not shown, no outline, no end state, preferences not persisted, evidence footer-only).
- **Options considered:** (a) fix each experience separately; (b) define a standard shell and let the body vary by subject.
- **Decision:** (b). Standard: entry hero with size line, reading controls (persisted), outline/progress, evidence at point of use, Deeper behaviour, end state, share, feedback after the end state, accessibility contract. Varies: blocks and order, theme and accents, data-bound theme, presentation variants, pacing. Details: [`design/phase-1-5-experience-specification.md`](./design/phase-1-5-experience-specification.md).
- **Reason:** fixes apply to every present and future experience at once, and readers do not relearn navigation.
- **Trade-offs:** adds platform surface to maintain; some elements may need small schema additions (Q-25) and presentation variants (Q-26), which are proposals, not decisions.
- **Status:** Proposed

## D-039 · Roadmap is expressed as five stages that map onto the earlier phases
- **Decision:** Stage 1 design decisions; 2 visible design evolution (no backend); 3 backend foundation (old Phase 2); 4 AI authoring (old Phase 3); 5 closed alpha (old Phase 4). Mapping and dependencies: [`architecture/phase-2-readiness.md`](./architecture/phase-2-readiness.md). `mvp-scope.md` is unchanged.
- **Reason:** the owner's Phase 1.5 brief separates a visible design stage from the backend; the table prevents two numbering schemes drifting.
- **Trade-offs:** two vocabularies exist until `mvp-scope.md` is next revised.
- **Status:** Proposed

## D-040 · No styled UI library as the design system; headless primitives only where hard interaction behaviour is needed
- **Context:** MUI, HeroUI and UI Lora were evaluated against actual requirements ([`design/ui-library-evaluation.md`](./design/ui-library-evaluation.md)).
- **Options considered:** MUI; HeroUI; UI Lora; headless primitives (React Aria Components, Base UI, Radix); none.
- **Decision:** keep `src/design-system/` (tokens, CSS Modules) as the single design system. For the publisher workspace and a few reader controls, prefer an unstyled behaviour library wrapped in our own components, chosen by a time-boxed spike at Stage 3/4. MUI is the fallback if confined to workspace routes behind a lint boundary.
- **Reason:** styled libraries bring a second token/styling system (Emotion or Tailwind) against D-015, and the reader surface is bespoke by identity.
- **Trade-offs:** more own components to write; accessibility of the primitives must be verified, not assumed. Library facts are a 10 Oct 2026 snapshot; bundle impact was not measured.
- **Status:** Proposed

---

# Decisions made in Stage 2 (visible design evolution)

## D-041 · Stage 2 scope approved with five owner decisions
- **Context:** the owner approved Stage 2 (see `architecture/phase-2-readiness.md`) on 11 Oct 2026 and approved the recommendations on persistence, homepage/Q-16, the promotion hold, climate changes and the claims restyle. Work ships as three PRs: homepage; reader shell; climate pacing and claims.
- **Decision:** (1) reading preferences persist in `localStorage` and are applied after hydration (cookie and pre-hydration script rejected for now; Q-19/Q-22 stay open); (2) the homepage does not name or promote "Whose Body Is It?" above the fold; (3) a platform config list (not the schema) holds experiences back from "next" links; (4) Climate content is reordered and gains an adjacent data note, with v0's migrated strings untouched; (5) the claims block's default presentation is restyled. No schema or block-vocabulary change.
- **Status:** Accepted (owner-approved)

## D-042 · Homepage strip: height follows its text; the wipe rests where no word is cut
- **Decision:** the Read/Explore strip's reading pane is in normal flow, so its height follows the text at any width or text size (no fixed height, no fade). The slider sits above the strip. On screens under 900 px the wipe rests on the Explore side; from 900 px it rests at 50 % with each pane's text kept on its own side of the seam. The headline size is also capped by viewport height. Without JavaScript the slider is hidden and the two halves are shown one after the other. A one-line count ("Two experiences to explore below.") states that there is more than one experience without naming any.
- **Reason:** the Phase 1.5 review (as corrected) found the slider below the fold at 1280 px and clipped or seam-cut text at narrow widths.
- **Trade-offs:** at narrow widths the read text is only seen by dragging back; the one-off intro animation still plays from Read to rest unless reduced motion is set.
- **Status:** Accepted

## D-043 · Reader shell: derived outline and length line, device-local preferences, platform-chosen end state
- **Decision:** (a) every experience shows "N sections · about M min read · K interactive" and a native-disclosure section list in its hero (works without JavaScript); experiences with four or more sections also get a Sections control in the bar that marks the current section. All of it is derived from the validated document (200 words per minute on the simple path, deeper text excluded; an estimate, not a measurement). (b) Deeper, text size and theme persist in `localStorage["inscapio:prefs"]`, validated and clamped on read, applied after hydration (a returning reader may see the default for an instant), and ignored when storage is unavailable (D-041). (c) Every experience ends with an end state before the feedback form. The "next experience" is chosen by platform policy in `content/site/promotion.ts`, which holds `whose-body-is-it` back (Q-16); when nothing may be offered the end state links to the home page, not to the home page's first room.
- **Reason:** review findings F1 to F4; none needed a schema change.
- **Not done:** sources at the point of use. Neither experience uses inline `sourceRef`; adding them means deciding which source supports which claim, which is an editorial task, not a rendering one.
- **Trade-offs:** the 200 wpm estimate ignores interaction time; a flash of defaults for readers with saved preferences; on screens up to 420 px the bar's home link shows only its arrow (accessible name unchanged).
- **Status:** Accepted

## D-044 · Climate: chart first with an adjacent illustrative note; claims as a compact list
- **Decision:** (a) the Climate sections are reordered to `explore`, `pattern`, `closing` and the hero "Begin" action targets `explore`: this departs from v0's order on purpose, so the city selector and chart come first and the framing questions follow as context. (b) A `data-note` block ("A demo, not a forecast.") sits directly under the chart and says the curves come from an invented warming rule and that "feels like" is the closest match among the 20 cities in the demo. The original closing note is kept. v0's migrated strings, the dataset, the prediction logic and the scrubber block are untouched. (c) The claims block renders as a compact list (the hint once above it, a row per claim with a +/− indicator) instead of a stack of bordered cards; behaviour, filter and data are unchanged. This is the new default for any experience using the claims block.
- **Measured (production build, main vs this branch, page y of the chart):** 2190 to 1407 px at 320 wide, 2297 to 1519 at 375, 2095 to 1414 at 430, 2224 to 1627 at 1280; the city selector moved from about 1580–1690 px to about 800–990 px. The chart is therefore roughly 0.8 to 0.9 screens earlier, and the controls start within the first screen after the hero.
- **Known copy mismatch:** chapter 7's intro (v0 text, parity-tested) still says "Tap a card"; the rows are no longer cards. Left unchanged to avoid editing migrated text without a content decision.
- **Status:** Accepted (owner-approved, D-041)

---

# Decisions proposed in Stage 3 design (backend architecture and security)

> Source: the Stage 3 design milestone (13 Oct 2026), documentation only. **All are recommendations, Status Proposed; none is approved.** They refine, and do not replace, D-010, D-012, D-018 and D-022. Details: `architecture/identity-and-access-control.md`, `architecture/supabase-data-model.md`, `architecture/authentication-and-rls-test-plan.md`, `architecture/stage-3-implementation-plan.md`.

## D-045 · Roles and ownership live in database tables, never in JWT claims or user metadata
- **Context:** the backend docs name roles but not where they live. `user_metadata` is user-editable; a JWT claim stays valid until expiry.
- **Options considered:** custom access-token claims; `app_metadata`; capability tables checked per query.
- **Decision:** `admins` row and `publishers.status='active'` are checked inside Postgres on every query; ownership via `experiences.publisher_id` through helper functions (`owns_experience`, `can_edit_experience`) so organisations can be added later by changing two function bodies. One publisher per experience now.
- **Reason:** immediate revocation; client-supplied values are never authoritative.
- **Trade-offs:** one indexed lookup per request.
- **Status:** Proposed

## D-046 · Invite-only magic-link sign-in; the invitation is an email-bound authorisation record
- **Decision:** Supabase Auth email magic links; public sign-ups disabled; an `invites` row (normalised email, expiry 7 days default, 30 max, one pending per email) authorises; the verified email on the session redeems it via a no-argument function; no bearer token. The confirm step is a POST button.
- **Reason:** proves email ownership; a leaked invite is useless to others; neutral responses prevent enumeration.
- **Trade-offs:** needs custom SMTP; some behaviours unverified (U-2, U-3).
- **Status:** Proposed

## D-047 · Authorisation in three layers; the public site is session-free
- **Decision:** proxy (optimistic) → DAL per page/action/handler (`getClaims`, plus `getUser` for high-risk actions) → RLS/functions. Public pages never read cookies. Proxy matcher limited to `/studio`, `/admin`, `/sign-in`, `/auth`.
- **Status:** Proposed

## D-048 · Append-only revisions; human-only approval and publication functions; a separate public projection; derived lifecycle status
- **Decision:** `revisions`, `approvals`, `audit_events` append-only; `publications.revision_id` references `approvals`; writes only through definer functions requiring a human session and ownership; privileges of `service_role` on those tables revoked; public reads only `published_experiences` (snapshot at publish); no stored `status` (amends the Phase 0 list; `in_review` dropped for the alpha); admin takedown sets a hold; full-Zod validation attested by a server-only role.
- **Status:** Proposed

## D-049 · The AI service uses a distinct Postgres role with no approval or publication privileges
- **Decision:** `ai_service` custom role, narrow `ai_api` schema, no grants on `approvals`/`publications`; never a Supabase secret key (which has BYPASSRLS). Feasibility is unverified (U-6).
- **Status:** Proposed (refines D-018)

## D-050 · Admin is operational and does not imply content access
- **Decision:** no admin policy on drafts, revisions or feedback; MFA (aal2) for all admin operations; re-auth, reason and confirmation for suspend and takedown; admin bootstrap by documented SQL, not an app feature; owner-level access is an acknowledged trust boundary.
- **Status:** Proposed

## D-051 · New staging and production Supabase projects; the existing project is unverified
- **Decision:** treat the existing project as scratch until the owner records its facts; create new staging and production projects once region, org ownership and plan are decided; production on a plan with backups before outside publishers; keys use the new publishable/secret model.
- **Status:** Proposed (refines D-012)

## D-052 · RLS and authorisation tests are a merge gate, run against real roles and policies
- **Decision:** three layers (pgTAP, API with real JWTs, application/e2e) in CI on every PR touching `supabase/` or auth code; every table needs denial tests; frontend-only tests do not count.
- **Status:** Proposed

## D-053 · Stage 3 increments and dependency timing
- **Decision:** order 3.0–3.7 as in the implementation plan; start at 3.1 (local identity core); `@supabase/ssr` and `@supabase/supabase-js` added only at 3.3, with explicit owner approval.
- **Status:** Proposed

