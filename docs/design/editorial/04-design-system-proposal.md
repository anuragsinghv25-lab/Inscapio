# 04 · Component and design-token proposal

**Status:** Proposal. No token or component in `src/` was changed. Values below marked *existing* are copied from `src/design-system/tokens.css` (read 22 Oct 2026) and reused unchanged in the prototype (`prototype/prototype.css`).

## 1. Principle

Reuse the current system; add only what the editorial product needs. The identity stays: fog and paper surfaces, deep teal ink, flat shapes with 2–4px radii, no shadows, Bricolage Grotesque for display and Literata for reading, cobalt for action and focus, amber for attention. The private studio is recognisably InScapio (same type and colour) and is separated from the public site by a dark *tarn* sidebar and a "Studio · private" label, not by a different visual language.

## 2. Tokens

### Existing (reused)

| Token | Value | Use |
|---|---|---|
| fog / paper | `#e3e9ea` / `#f5f8f8` | page / surface |
| deep / mid | `#102c33` / `#4a646b` | ink / muted text |
| tarn | `#0b2f38` | dark field (lead story, rail, studio nav, footer) |
| cobalt, cobalt-strong | `#2447d6`, `#1a36a6` | action, focus on light |
| amber | `#f2a900` | attention, focus on dark, primary on dark |
| accents | rose, teal, violet, ochre, blue, plum, green, indigo | decorative section hues |
| type | Bricolage Grotesque (display), Literata (text) | |
| shape | radii 2/3/4px, flat | |
| focus | 3px ring, 3px offset | |

### Proposed additions (roles that map to existing hues)

| Token | Maps to | Used for |
|---|---|---|
| `--topic-conflict` | rose | Conflict & security |
| `--topic-diplomacy` | blue | Diplomacy & institutions |
| `--topic-trade` | ochre | Trade & economy |
| `--topic-energy` | teal | Energy & resources |
| `--topic-tech` | violet | Technology & power |
| `--topic-india` | green | India & the world |
| `--status-draft…held` | mid, teal, green, blue, ochre, rose, plum | Draft, Ready, Published, Updated, Corrected, Unpublished, Held |
| `--ep-established…unresolved` | green, blue, rose, violet, ochre, mid | Epistemic labels |
| `--target-min` | 44px | Minimum control size |

**Contrast (computed 22 Oct 2026 with the WCAG formula, text on white / on paper):** status and epistemic text colours 4.72–8.26:1, all ≥4.5:1; white text on topic fills 4.88–7.02:1 (ochre lowest at 4.88). Mid on fog 5.14:1; cobalt on fog 5.81:1; amber on tarn 7.07:1. Axe-core 4.13 reported no WCAG 2.0/2.1/2.2 A/AA violations on any of the 18 prototype screens at 1400px and 420px viewports. *Not verified:* contrast of the real web fonts (fallback fonts rendered in the test sandbox), forced-colours mode, and screen readers.

## 3. Components

| Component | Variants / states | Behaviour and accessibility |
|---|---|---|
| **StoryCard** | standard, wide, compact, related, admin row | Top border in topic colour; headline is the single link, card is click-through via pseudo-element; chips for New/Updated/Corrected; label for epistemic state |
| **LeadStory** | with briefing stepper | Dark tarn block; 3-step briefing replaces the old read/explore wipe; stepper is buttons with `aria-pressed` and a live region |
| **HeadlineRail** | manual (default) / auto-scroll (variant) | Manual: scroll container, `tabindex=0`, arrow keys, prev/next buttons ≥44px, snap. Auto variant adds Pause/Play, pauses on hover and focus, off under `prefers-reduced-motion`; satisfies WCAG 2.2.2 |
| **StatusChip** | 7 types | Text + border style (dashed for draft/unpublished); never colour alone |
| **EpistemicLabel** | 6 types | Glyph + text + border style (solid, dashed, dotted) |
| **Timeline** | filter, expand all | Ordered list; each event a disclosure button (`aria-expanded`/`aria-controls`); no horizontal scrub |
| **StakeholderCard** | state / organisation / industry | Fields: stated position (Attributed), interest (Analysis), source. Never asserts motives as fact |
| **CauseChain** | numbered | Each step carries a label |
| **Chart** | line/bar, 1–3 series | Focusable points with arrow-key navigation, readout live region, "Show as table", direct series labels plus stroke difference, "Illustrative data" flag |
| **ComparisonTable** | — | Real `<table>` with `scope`; horizontal scroll container only if needed |
| **UpdateBanner / ChangeLog** | updated, corrected | Banner pinned under the hero; log at page end; distinct wording and chip colour |
| **SourceList** | — | Ordered, `scroll-margin` for anchors, type + dates + archive |
| **StudioShell** | sidebar ≥900px, wrapping top bar below | Dark tarn nav; current item has a left amber bar and `aria-current` |
| **ValidationList** | error, warning, pass | Field path in `<code>`, plain-English fix, icon + text |
| **Dialog** | confirm, alertdialog | Focus trap, Esc, focus returns to trigger, publish requires a checkbox |
| **Banner / Toast / Drawer** | info, warn, error, ok | Banner `role=alert` for errors; toast `role=status`, auto-hide 6 s and never the only record |
| **Form controls** | text, select, textarea, radio, checkbox, OTP | 44px height, visible label, hint, error with icon and `aria-invalid` |

## 4. Layout and responsiveness

- Mobile floor 375px; container-query breakpoints at 640, 900 and 1000px (the prototype uses container queries so a device toggle behaves like a real viewport).
- Story column: reading measure ≤34em; a 200px sticky outline appears ≥1000px only.
- Public grid: 1 column <640, 2 columns 640–999, 3 columns ≥1000.
- Studio: sidebar ≥900px; tables become cards <700px; block list becomes a drawer <700px; structured editing is desktop-only (preview and typo fix on phones).
- Spacing uses the existing gutter pattern `clamp(18px, 4.5cqw, 56px)`.

## 5. States to build for every control

default · hover · focus-visible (ring) · selected (`aria-pressed`/`aria-current`, fill and weight change) · disabled (55% opacity, `aria-disabled`, reason shown nearby) · error (icon + text + border) · loading (skeleton, off under reduced motion).

## 6. Motion

Nothing moves by default. Allowed: skeleton shimmer, disclosure open, optional rail variant. All off or instant under `prefers-reduced-motion`. The prototype has a "Simulate reduced motion" switch to check this.

## 7. Evaluation of the ticker request

Recommendation: **manual rail, no auto-scroll in the MVP.** Reasons: (1) moving text is hard to read and to click, and WCAG 2.2.2 requires a pause control for anything that moves for more than five seconds alongside other content; (2) the Phase 1.5 homepage specification lists “auto-playing anything” as not allowed, and `design-principles.md` says “Reader owns the pace. No auto-advancing” and rules out carousels as primary navigation; (3) a rail that the reader controls still gives the "alive" feeling through content freshness (timestamps, Updated chips), which matters more than motion. The auto-scroll variant is in the prototype for comparison with the safeguards that would be required.

## 8. Things deliberately not designed

Dark mode for the new components (tokens exist; verify later), illustrations or photography direction, an icon set, email templates, print stylesheet, data-visualisation beyond line/bar.
