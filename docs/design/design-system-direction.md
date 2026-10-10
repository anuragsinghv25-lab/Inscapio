# Design system direction

> **Status:** Phase 0 · Direction, not a spec. Nothing here is built. This document says what the design system *should become* and how it grows out of the prototype, so Phase 1 does not have to rediscover it.

## Why a design system, and what it is for

The design system is the **experience layer** InScapio owns (Principle 6). It exists so that:

1. The AI can compose experiences from a *closed, high-quality vocabulary* instead of inventing front-end code.
2. Every experience inherits accessibility, performance and visual quality by construction.
3. Improving a component improves every experience that uses it.
4. A publisher's choices are limited to ones that cannot produce an ugly or inaccessible result.

It is therefore not a generic UI kit. It is **a block library with a visual language**.

## Starting point

The prototype already contains the seeds ([`current-design-audit.md`](./current-design-audit.md)):

- **Tokens:** colour, type, a fluid gutter, a motion vocabulary.
- **Components, unnamed:** each interaction pattern.
- **A presentation mechanism:** the per-section `--c` accent, and the climate `--w` data-bound theme.

The work is to *name, consolidate and constrain*, not to redesign.

## Layers

```
Tokens ──► Primitives ──► Blocks ──► Section / Page templates ──► Experience
(raw values) (Button, Chip,  (Accordion, Stepper,   (Hero, Chapter,       (renderer composes
              Callout…)       Classify, Scrubber…)    Closing…)            from structured content)
```

| Layer | Contents | Who may use it |
|---|---|---|
| **Tokens** | Colour, type scale, space, radius, border, motion, z-index, breakpoints | Everything |
| **Primitives** | Text styles, button, chip, toggle, slider, callout, card, rule, disclosure | Blocks and platform UI |
| **Blocks** | The renderable units of an experience; each has a content schema, a declarative behaviour schema, an accessibility contract and tests | Renderer only (publishers/AI *select* blocks, they don't style them) |
| **Templates** | Hero, chapter, closing, end-of-experience | Renderer |
| **Platform chrome** | Site nav, experience bar, reading controls, progress, feedback, share | Platform |

## Tokens

### Direction

- Express every token as a **CSS custom property**, authored once, consumable from CSS and TypeScript.
- Name by role, not value: `--color-ink`, `--color-surface`, `--color-accent`, not `--teal`.
- Provide **themes** as token sets. Initial themes derived from the prototype: *Fog* (light), *Tarn* (dark teal), *Deep*, and the *Whose Body* light/dark pair, **harmonised** with the core palette in a later phase.
- Keep **type scale and spacing fluid** (the prototype's `clamp()` approach is good and should survive).
- **Section accents** become a **named, closed palette** (e.g. 9–12 colours) with *both light-theme and dark-theme variants that each pass contrast*. This fixes the known dark-theme accent-text gap and gives publishers and AI a safe choice list.

### Proposed token groups

| Group | Contents | From the prototype |
|---|---|---|
| Colour: core | ink, ink-muted, surface, surface-raised, line, accent-primary, accent-attention, focus | `--deep`, `--mid`, `--fog`, `--paper`, `--cobalt`, `--amber` |
| Colour: section accents | closed palette, each with light/dark variants | the nine `--c` chapter colours |
| Colour: data | sequential and diverging ramps; categorical set; "cool→hot" pair | `#7FD6E8` → `#FF8A4C` |
| Type | display family, text family, scale (fluid), weights, tracking, optical-size and width axes | Bricolage Grotesque, Literata |
| Space | fluid gutter; vertical rhythm steps | `--g`, `clamp()` spacing |
| Shape | radii (0–4px), border widths, rule thickness | square-ish, flat, bordered |
| Elevation | deliberately none | no shadows |
| Motion | durations, easings, transition recipes | the audit's motion table |
| Layout | container widths, measure | 1400 / 1100 / 760, 34em |

## Identity: the visual language to preserve

Stated so Phase 1 does not accidentally produce a generic template:

1. **Big, confident, two-weight typography.** Weight *and width* contrast (thin condensed beside heavy normal) is a signature.
2. **Flat and bordered.** No shadows, no glass. Separation through rules, colour fields and scale.
3. **Colour as territory.** Large fields of deep teal, fog, cobalt and amber; sections have their own accent.
4. **Squared corners.** Radii stay small (≤4px).
5. **Functional motion only.**
6. **Honesty as a visible element:** notes, sources, "deeper" layers with a clear label.

## Blocks: the vocabulary

Each block ships with the same five things:

1. **Content schema** (what is said)
2. **Behaviour schema** (declared parameters)
3. **Presentation options** (a closed list)
4. **Accessibility contract** (roles, keyboard, announcements, alternatives, reduced-motion behaviour)
5. **Tests and a fixture** (content example + visual baseline)

The initial list is derived from the prototype's patterns (see [`../product/mvp-scope.md`](../product/mvp-scope.md) and [`../architecture/content-architecture.md`](../architecture/content-architecture.md)). A block is only added if the interaction test in [`design-principles.md`](./design-principles.md) is passed and it is useful across *multiple* experiences, not just one.

## Platform chrome

Retained from the prototype and made configurable: experience bar (back, title, Deeper, text size, theme), progress line, entrance transition, end-of-experience panel, feedback, share. Reading preferences (Deeper, text size, theme, motion) should be **persisted per reader** (locally at first).

## Theming for experiences

Publishers do not pick colours. They pick:

- A **theme** (from a short list).
- A **section accent** per section (from the closed palette).
- A **layout variant** per block where the block offers one.

An experience whose idea warrants *data-bound theming* (the climate page warming as the year advances) gets it through a block-level behaviour (`bindTheme: "warming"`), not custom CSS.

## Governance

- **Component additions** go through a short proposal: the idea it serves, the interaction-test answers, the schemas, the accessibility contract, the performance cost.
- **Design tokens are the only place a raw colour, size or duration appears.** Anything else is a bug.
- **A living reference** (a component gallery) should exist from the first block, serving as design documentation, visual-regression baseline, and a place where designers and AI can see the vocabulary. Tooling is decided in Phase 1 (see [`../architecture/frontend-architecture.md`](../architecture/frontend-architecture.md)).

## Open design questions

- How far should the two existing visual systems (InScapio core and Whose Body's palette) be harmonised, versus kept as distinct *themes*?
- Should InScapio offer a **light** theme for the whole product, or keep dark teal as the signature surface?
- Is the display typeface's width axis a core brand device or an optional flourish? (It costs bytes.)
- Imagery: the prototype has *none*. Should InScapio stay type-and-data-led, or develop an image and illustration language?
- Sound: out of scope; revisit only with a strong case.

## What this phase does *not* do

It does not build tokens, components or a gallery. Those are Phase 1+ and are scheduled in [`../product/mvp-scope.md`](../product/mvp-scope.md).

---

## Phase 1: as built

> **Status:** Current on branch `phase-1/schema-renderer`. Decisions: D-027, D-028.

- **Tokens** live in `src/design-system/tokens.css`: a raw palette (v0's), role names (`--color-page`, `--color-ink`, `--color-accent`, `--color-attention`, ...), nine accent fills with separate light and dark text variants, a fluid type scale, spacing and widths, radii, focus and motion tokens. The rule "raw values only here" holds for colours in every component CSS module (the one literal outside tokens is the `themeColor` metadata value in `layout.tsx`); it is checked by review and a grep, not by a linter. Some pixel sizes (for example 44/48/56 px control heights and chart plot margins) are still literals in components.
- **Themes** are `paper` (light/dark) and `tarn` (dark, data-bound through `--warm` and `color-mix`). Content selects a theme and accents by **name**; it never supplies a value.
- **Accents** are generated into `accents.css` / `accents.ts` and set `--c` (fill) and `--c-text` (text, mode-aware via `light-dark()`). All text variants are at least 4.5:1 on page and card surfaces (computed), and axe reports no contrast violations in light, dark, forced-light and warm-climate states.
- **Fonts:** self-hosted variable fonts (OFL). Display: Bricolage Grotesque (weight and width axes; no optical size). Text: Literata (with optical size).
- **Primitives** are deliberately few: `Chip` (toggle) and `ButtonLink`. Blocks style themselves through CSS Modules using tokens. No component library was added.
- **Identity preserved:** flat surfaces, 2 to 4 px radii, no shadows, fluid oversized display type, saturated chapter accents, cool-to-warm climate field. Side-by-side screenshots at 375 and 1280 were reviewed by me; they are saved for human review and not pixel-diffed.
- **Evolving without touching content or code:** a token or accent change is one CSS edit; a new accent also needs the generator and an enum entry (documented in `accents.ts`).
- **Not done:** a component gallery, visual regression tooling, a documented token naming guide beyond the file itself.
