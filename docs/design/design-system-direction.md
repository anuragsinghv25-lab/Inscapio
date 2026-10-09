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
