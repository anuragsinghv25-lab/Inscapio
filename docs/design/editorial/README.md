# InScapio Editorial: design phase package

> **Status: Proposed. Design only.** Nothing here is implemented, merged to the application, or deployed. No application code, migration, dependency, hosting, DNS, Supabase project or `prototype/v0/` file was changed. Phase 3.3 has **not** started. Work stops here until the owner reviews.

## What this is

A product and UX design package for an **admin-curated, AI-assisted editorial news experience** on InScapio: a public Edition front page and interactive story pages, plus a private studio where the owner imports AI-drafted structured stories, reviews, approves and publishes them, and later updates, corrects or unpublishes them.

## Figma: not available, stated plainly

**No Figma file was created.** No Figma integration was connected in the working session: a Figma connector exists in the connector registry but is not installed or enabled for this account, and no Figma tool was available. A Figma URL is therefore not provided and none should be assumed.

**What was produced instead** (the most useful artifact available):

1. `prototype/index.html`: a **clickable, responsive HTML prototype** of all seven design pages (18 screens), using the real InScapio colour, type and shape tokens, with a device toggle (1280 / 768 / 375), an annotation layer, state switches (edition with 2, 8, 16 stories, empty, loading, error; manual vs auto-scroll rail; reduced-motion simulation), and working dialogs and flows.
2. A hosted, private copy for easier review (link given in the review message; not stored in the repository).

**To get a real, editable Figma file** the owner can do any one of these:

- Install and enable a **write-capable Figma connector** for the Claude account, grant it access to a Figma team or file the owner creates, and ask for the frames to be built (screen list and tokens are ready in `01`, `04`);
- or create an empty Figma file and share edit access with a Figma-connected tool;
- or try an HTML-to-Figma import plugin on `prototype/index.html` (untested here; layout fidelity and editability are not guaranteed).

No credentials should be pasted into chat or committed.

## Contents

| File | What it gives you | Deliverable |
|---|---|---|
| [`01-screen-inventory.md`](./01-screen-inventory.md) | Repository-backed inventory: Implemented / Partial / Placeholder / Not yet / Proposed | 1 |
| [`prototype/`](./prototype/index.html) | Clickable prototype, 7 pages, desktop and mobile | 2 (substitute), 3, 4 |
| [`02-editorial-mvp-prd.md`](./02-editorial-mvp-prd.md) | PRD, complete screens and flows list | 3, 6 |
| [`03-content-schema-mapping.md`](./03-content-schema-mapping.md) | Block mapping: reuse vs change; migration needs | 7 |
| [`04-design-system-proposal.md`](./04-design-system-proposal.md) | Tokens and components, accessibility, ticker evaluation | 5 |
| [`05-phased-implementation-proposal.md`](./05-phased-implementation-proposal.md) | 3.3, prerequisites, Editorial MVP, later | 8 |
| [`06-decisions-assumptions-risks.md`](./06-decisions-assumptions-risks.md) | Open questions Q-45 to Q-54 with defaults, assumptions, risks, do-not-build | 9, 10 |
| [`07-review-guide.md`](./07-review-guide.md) | What to look at and what feedback helps most | 11 |

## How to open the prototype

- Check out the branch `docs/editorial-design-phase`, then open `docs/design/editorial/prototype/index.html` in a browser (double-click works; no build, no dependencies). Fonts load from Google Fonts if online; offline falls back to system fonts.
- Use the top bar: page tabs (1 to 7), the screen row below it, the device buttons, **Annotations** (shows design notes, dependencies and conflicts), and **Simulate reduced motion**.
- Every screen carries a status badge (Existing / Partial / Proposed / Later) and a banner on public screens: *"Illustrative content … invented for design review, not news."*

## Checks that were run (design package only)

- Automated accessibility scan (axe-core 4.13, WCAG 2.0/2.1/2.2 A and AA tags) on all 18 screens at desktop and 420px widths: no violations after fixes. Not a substitute for manual testing, assistive-technology testing, or an audit.
- Scripted interaction checks in Chromium: 24 checks (edition states, rail pause and reduced motion, timeline, chart keyboard, import validation, block reorder, publish dialog gating, revision preview).
- WCAG contrast ratios of proposed colours computed (see `04`).
- Not run: screen readers, forced-colours mode, real web fonts in the sandbox, other browsers, real devices.

## What this PR changes

Adds `docs/design/editorial/`, a row in `docs/README.md`, decision **D-062** (Proposed) in `docs/DECISIONS.md`, and questions **Q-45 to Q-54** in `docs/OPEN-QUESTIONS.md`. Nothing else.
