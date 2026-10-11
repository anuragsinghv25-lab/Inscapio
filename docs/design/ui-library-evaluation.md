# UI library evaluation: MUI, HeroUI, UI Lora

> **Status:** Phase 1.5 · Proposed, pending owner review. **Nothing was installed, added to `package.json`, or imported.** Facts come from the npm registry (`npm view`, 10 Oct 2026) and the vendors' own pages fetched in this session; anything not verified is labelled **unverified**. Decision record proposed: D-040 (see `../DECISIONS.md`).

## 1. The question

Should InScapio adopt MUI, HeroUI or UI Lora, and for what? The answer depends on what InScapio actually has to build, so the requirements come first.

### 1.1 What InScapio actually needs

| Surface | Need | Constraint |
|---|---|---|
| **Reader: the renderer's 15 blocks** | Bespoke interaction (scrubber chart, stepper, classify, claims, selector) and editorial typography; identity is flat, bordered, small radii, large type, accent "territory" | D-004, D-015, D-028; no runtime CSS-in-JS; server-rendered baseline; works with `@media (scripting: none)`; no shadows |
| **Reader: platform chrome** | Site nav, experience bar, outline, reading controls, end state, feedback | Same identity; few primitives (Chip, ButtonLink exist) |
| **Publisher workspace (Stage 4+)** | Forms, dialogs, menus, comboboxes/selects, tabs, toasts, tables, drag-free reorder, file upload, a chat-like panel | Complex interaction a11y that is costly to hand-roll; no brand constraint as strong as the reader's, but must still feel like one product |
| **Both** | Next.js 16 App Router, React 19, TypeScript strict, WCAG 2.2 AA, small JS on the reader path | D-009, D-017, D-019 (one app, lint-enforced boundaries) |

The critical observation: **the reader surface is the product's identity and is almost entirely bespoke blocks; the part that benefits most from a library is the publisher workspace, which does not exist yet.** Decisions for the two should not be coupled, and there is no need to make the workspace decision now.

### 1.2 Current stack facts that constrain the answer

- Styling is CSS Modules plus CSS custom-property tokens, no Tailwind, no CSS-in-JS (D-015).
- Next 16.4.0, React 19.3.0, TypeScript 5.9.3 strict.
- Reader JS today is ~487–505 KB decoded (unminified-size as served, not compressed; framework-dominated; see the review). Any library must be judged against *adding to* that on the reader path, which is why library code should not be imported in the renderer.

## 2. What each option is (verified)

### 2.1 MUI (Material UI)

- **Version:** `@mui/material` **9.5.0**, MIT, last published 9 Oct 2026 (npm).
- **React:** peer `^17 || ^18 || ^19`. **Next:** the companion `@mui/material-nextjs` 9.5.0 declares Next `^13 … ^16` and exposes `v16-appRouter` (npm exports); the official guide shows wrapping `<body>` in `AppRouterCacheProvider` and notes a Next 16 caveat when passing `next/link` as `component` (needs a `'use client'` wrapper).
- **Styling engine:** Emotion (`@emotion/react`, `@emotion/styled`) by default; both marked optional peers in metadata, and there is a Pigment CSS peer (optional). The docs describe `enableCssLayer` so MUI styles sit in `@layer mui` beside CSS Modules, and `cssVariables: true` for theme variables. Emotion is a **runtime** styling engine; that is the thing D-015 rejected for the reader.
- **Look:** Material Design. Overriding it to flat, bordered, 0–4 px, display-type-led is possible through the theme but is work against the grain, and the default component set (elevation, ripples, rounded controls) is the "someone else's site" risk named in `design-principles.md`.
- **Breadth:** the widest component set of the three, including data grid, date pickers, autocomplete, dialogs, menus, tabs, snackbars (general knowledge; not re-verified here).
- **Accessibility:** MUI documents ARIA patterns and keyboard support. **Unverified in this session**; it would need to be tested, not trusted.

### 2.2 HeroUI

- **Version:** `@heroui/react` **3.2.6** (`latest`), MIT, with `3.0.0-rc.1` and `3.0.0-beta.2` still on other tags (npm).
- **Requirements (npm peers and the v3 migration page):** `react >= 19`, `react-dom >= 19`, **`tailwindcss >= 4`**, `react-aria-components ^1.21.1`, `react-aria ^3.52.1`. v3 "uses React Aria Components"; v3 drops the provider and the Tailwind plugin; Framer Motion removed.
- **Next App Router:** the fetched migration page mentions Next.js and Server Components only as keywords and does not state App Router support. **Not verified**; would need a spike.
- **Accessibility:** inherits React Aria Components' behaviour (well regarded; that is the substantive reason to consider it). No formal WCAG conformance claim was found on the page fetched.
- **Fit problem:** it requires Tailwind v4. InScapio has none by decision (D-015). Adopting HeroUI would mean adding Tailwind, which brings a **second styling system** next to CSS Modules, and a second source of design tokens next to `tokens.css`.
- **Maturity note:** v3 is a recent major (an RC existed, and v2 → v3 is a breaking migration). Fine to watch; riskier to depend on early.

### 2.3 UI Lora

- **What it is (uilora.com, fetched):** a "premium UI component library for Next.js and React Native" distributed as **copy-paste source code**, installed with `npx uilora@latest add <component>`; no versioned runtime package for the components; Tailwind CSS plus Framer Motion on web (Reanimated on React Native); components "follow WAI-ARIA guidelines" (a claim, not a conformance statement).
- **Licence and price (as stated on the page):** free tier ($0, "490+" components, source behind login), Pro $99 one-time, Ultimate $179 one-time with "22+ complete landing page templates"; commercial licence stated for paid tiers.
- **Evidence quality:** the page is internally inconsistent (it advertises "700+" components while its tiers add to about 546, and calls itself "100% Free" while selling paid tiers); the FAQ asks about Next.js 14/15 support without answering; no version, changelog or Next 16 / React 19 statement was found. An `uilora` npm package exists (v1.0.6) and is the CLI, not the components.
- **Fit problem:** it is a source library, so "maintenance" means *you own the copied code*; there is no upgrade path and no accessibility owner. It also needs Tailwind and Framer Motion. Its emphasis on landing-page templates is the opposite of the homepage direction (no SaaS landing page).
- **Verdict on category:** a source of ideas and starter snippets, not a dependency to build a platform on.

### 2.4 Not requested, but material: headless primitives

The real decision for the publisher workspace is not "which look" but "who owns the hard accessibility behaviour". Headless libraries give behaviour without a look:

| Option | Version (npm, 10 Oct 2026) | Licence | Notes |
|---|---|---|---|
| React Aria Components | 1.22.1 | Apache-2.0 | Adobe; the accessibility engine HeroUI v3 is built on; ships `react-aria`/`react-stately`; unstyled with data-attribute states, so it styles cleanly with CSS Modules |
| Base UI | `@base-ui/react` 1.9.0 (stable; the older `@base-ui-components/react` is 1.0.0-rc.0) | MIT | From the MUI team; unstyled primitives |
| Radix Primitives | e.g. `@radix-ui/react-dialog` 1.2.0 | MIT | Widely used, unstyled; individually installable |

I did not benchmark these or verify their accessibility; the table records only what the registry reports.

## 3. Comparison matrix

Legend: ● meets, ◐ partly or with work, ○ does not, ? unverified. "Reader" = renderer and chrome; "Workspace" = publisher UI.

| Criterion | MUI 9.5 | HeroUI 3.2 | UI Lora | Headless (RAC / Base UI / Radix) |
|---|---|---|---|---|
| React 19 / Next 16 compatibility | ● (peers, `v16-appRouter`) | ◐ React ≥19 ok; App Router **?** | ? (no version info) | ● (peers allow 19) |
| Fits D-015 (CSS Modules, no CSS-in-JS runtime) | ○ (Emotion by default; CSS-variables/layer options reduce but do not remove it) | ○ (needs Tailwind 4) | ○ (Tailwind + Framer Motion) | ● |
| Keyboard / ARIA quality | ? (documented, untested here) | ◐ via React Aria | ? (claim only) | ● RAC is the strongest-known; Base UI/Radix well regarded (**unverified here**) |
| Customisable to InScapio's flat editorial identity | ◐ theme work against the grain | ◐ Tailwind tokens; second token system | ◐ you own the code | ● no look to fight |
| Editorial typography for long-form reading | ○ not a goal of the library | ○ | ○ | n/a (you supply it) |
| Form, dialog, menu, select, tabs primitives | ● | ● | ◐ (quality unknown) | ● |
| Data-heavy widgets (tables, grids, date pickers) | ● | ◐ | ? | ◐ (RAC has tables/dates; Radix does not) |
| Suitability for the **reader** | ○ | ○ | ○ | ◐ (only for a few chrome controls, if at all) |
| Suitability for the **workspace** | ● | ◐ | ○ | ● |
| Bundle impact on reader path | **Not measured** (Emotion + components); must be kept out of reader routes | **Not measured** | Not applicable (copied) but adds Framer Motion | **Not measured**; per-component imports, tree-shakeable |
| Maintenance / migration cost | Large API, major-version upgrades (now v9) | Recent v3 major; v2→v3 was breaking | You maintain copies; no upgrade path | Smaller surface; you own styling |
| Risk of a **second design system** | High (Material look + theme) | High (Tailwind tokens) | High (copied styles) | Low (all styling is ours) |
| Licence | MIT | MIT | Commercial terms per tier | Apache-2.0 / MIT |

Unpacked sizes on npm are not bundle sizes and are not used here; no bundle comparison was made because nothing may be installed. A fair comparison needs a spike (Section 5).

## 4. Recommendation

**Do not adopt MUI, HeroUI or UI Lora as InScapio's design system.** Keep `src/design-system/` (tokens, CSS Modules, closed accents) as the single source of the product's look, for both the reader and, eventually, the workspace.

**Use headless primitives where hard interaction behaviour is needed and nowhere else.** For the publisher workspace, and for the few reader controls that need robust behaviour (a dialog, a menu, a combobox), prefer an unstyled accessibility library (React Aria Components, Base UI or Radix), wrapped in our own thin components and styled with our tokens. This is a **hybrid**: not a second design system, because the library supplies behaviour only.

Reasoning in four lines:

1. The reader surface is bespoke by necessity and by identity; no off-the-shelf look serves it, and importing a library there adds bytes to the path that most needs to be small.
2. The workspace is where hand-rolled accessibility is most expensive, so a behaviour library earns its place there.
3. Every styled option brings its own token system (Emotion theme or Tailwind), which breaks "tokens are the only place a raw value appears" (`design-system-direction.md`) and creates a second design system to reconcile.
4. UI Lora is a poor foundation (copy-paste, unversioned, Tailwind, thin evidence), though its components may still be read for ideas.

**What would change this recommendation.** If, when the workspace is designed, the team wants speed over identity there (an internal-tool look is acceptable), MUI is the most complete and is viable *if confined to workspace routes*, with `enableCssLayer`, no import from the renderer, and a lint boundary (D-019) preventing leakage. HeroUI becomes attractive only if the project adopts Tailwind v4 for other reasons, which nothing currently suggests.

## 5. What to do before deciding for real (Stage 3 or 4, not now)

A time-boxed spike, in a throwaway branch, when the first workspace form or dialog is needed:

1. Build the same two pieces (a labelled form with validation messages; a modal dialog with focus return) with React Aria Components and Base UI (and optionally Radix), styled from our tokens.
2. Record bundle cost on a workspace route with the build's own analysis, keyboard behaviour, screen-reader announcements (VoiceOver, NVDA at least), and lines of wrapper code.
3. Confirm Next 16 App Router and React 19 behaviour from the build, not from docs.
4. Decide; record the result as a D-xxx superseding the proposed D-040 if it differs.

## 6. Risks and caveats

- Versions and metadata are a snapshot from 10 Oct 2026; re-check at decision time.
- The accessibility column for MUI, Base UI and Radix is **unverified** in this session; only React Aria Components' role under HeroUI is documented by HeroUI's own page.
- HeroUI's App Router support and UI Lora's Next/React versions could not be confirmed from the pages fetched; absence of a statement is not evidence of absence.
- No performance or bundle number is reported because none was measured.

## 7. Sources

- npm registry metadata via `npm view` (10 Oct 2026): `@mui/material`, `@mui/material-nextjs`, `@heroui/react`, `@heroui/styles`, `react-aria-components`, `@base-ui/react`, `@base-ui-components/react`, `@radix-ui/react-dialog`, `uilora`.
- MUI: https://mui.com/material-ui/integrations/nextjs/
- HeroUI: https://heroui.com/docs/guide/introduction (v3 migration content)
- UI Lora: https://uilora.com/
