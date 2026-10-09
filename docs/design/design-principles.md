# Design principles

> **Status:** Phase 0 · Proposed. These turn the product principles ([`../product/principles.md`](../product/principles.md)) into design rules. Where the prototype already embodies a rule, it is noted.

## Goal

> **Premium editorial experience + interactive storytelling + modern product usability.**
> Not: *a website with lots of animations.*

## On inspiration

Award-winning sites (Awwwards-style work) are a legitimate source of *craft lessons*: confident typography, composition, pacing, restraint, how a transition carries meaning. We learn from them. We do **not** copy layouts, signature effects, brand devices or identifiable compositions from any specific site. InScapio's visual language is original and already has foundations (see [`current-design-audit.md`](./current-design-audit.md)).

A practical test: if someone could say *"that looks like <site>"* about a screen, it is not done.

Two further cautions:

- **Award-site techniques are often hostile to the reader.** Scroll-jacking, heavy WebGL, cursor effects and long intro animations tend to hurt accessibility, performance and comprehension. InScapio's readers are trying to *understand something*.
- **Spectacle is not the product.** The product is understanding. Craft serves it.

---

## 1. Editorial first

1. **Typography leads.** Type carries the identity (large, confident display type; a readable serif for sustained text). Decoration is secondary.
2. **Hierarchy is unmistakable.** At any moment a reader should know what to read first, second and third.
3. **Whitespace is structural.** Generous vertical rhythm separates ideas; density is reserved for data.
4. **Measure and size are comfortable.** Body text at about 17px or larger, around 34em line length, 1.5–1.65 line-height, user-adjustable.
5. **Colour is meaningful.** Accents mark sections, state or data, not mood-board decoration. Prefer a small number of tokens used consistently.

## 2. Interaction principles

### The interaction test

Before adding an interaction, answer yes to **all** of these:

1. **Idea:** Would the idea be understood *less well* as plain text?
2. **Action:** Does the reader *do* something that changes what they understand (choose, predict, compare, reveal), rather than just watch?
3. **Outcome:** Is there a clear, immediate response that teaches something?
4. **Cost:** Is the cost (attention, time, bytes, complexity) smaller than the benefit?
5. **Fallback:** Does the experience still work without it (no JavaScript, keyboard only, screen reader, reduced motion)?

If it fails the test, use text. The prototype passes it: the climate chart is a *relationship over time*, the classify quiz is a *distinction*, the stepper is a *sequence*.

### Patterns to prefer

- **Predict, then reveal.** Ask the reader to commit to a guess before showing the answer. Highest-value pattern in the prototype.
- **Progressive depth.** Surface first; *Deeper* is reader-initiated, explicit and reversible. Never hide essential caveats there.
- **One thing at a time.** One main interaction per screen.
- **Immediate feedback.** Responses within about 100 ms; explanations in plain language.
- **Reader owns the pace.** No auto-advancing, no scroll-jacking, no forced waits. (The one auto-play, the home wipe, runs once and yields to the reader immediately.)

### Patterns to avoid

Scroll-jacking · parallax that moves *content* · carousels as primary navigation · modal interrupts · autoplaying audio or video · gamification that has no learning value · hover-only interactions · anything that cannot be operated by keyboard.

## 3. Motion principles

**Motion must communicate.** Use it only to (a) show a change of state, (b) show change over time, (c) orient the reader after a transition. Do not use it as decoration.

| Allowed | Example in the prototype |
|---|---|
| Orienting transitions | Circular reveal from the tapped point when entering an experience |
| Showing change | Year tween; background warming with the data |
| State feedback | Accordion open/close; button state |
| Direct manipulation | Slider-driven wipe |

**Rules**

1. Everything honours `prefers-reduced-motion`. In reduced motion, state changes still happen, instantly. Never remove *information*, only motion.
2. Duration is short (≈150–400 ms for UI; up to ≈800 ms for a major transition; longer only when the motion *is* the content, such as a time tween the reader asked for).
3. Use easing with a purpose: ease-out for arrivals, symmetrical for toggles.
4. Only animate `transform`, `opacity`, `clip-path` and similar composited properties. No layout-thrashing animation.
5. **One motion idea per screen.** If two things move, one of them is wrong.
6. A **motion budget** per experience is reviewed like a performance budget: how many distinct animated elements, and why each earns its place.

## 4. Composition and layout

- Large scale is allowed and encouraged for *one* thing per view (a title, a number, a statement).
- Variety of rhythm: alternate dense and open sections so a long piece has pace. (Whose Body does this with accent rules and callouts.)
- Mobile is the primary canvas. Design the phone layout first; desktop adds room, not different content.
- Fluid sizing over fixed breakpoints where possible (`clamp()`, `minmax()`), as in the prototype.
- Respect safe areas and dynamic viewport units.

## 5. Accessibility is a design constraint

- **WCAG 2.2 AA** as the baseline; checked automatically in CI and manually per release.
- 4.5:1 text contrast (3:1 for large text and UI boundaries) **in every theme and every accent**. This is a known gap in the prototype's dark theme for accent text.
- Touch targets ≥ 44px (the prototype uses 44–56px).
- Keyboard complete, visible focus, logical order, focus management on navigation.
- Meaningful text alternatives, including a **data-table alternative for every chart**.
- Don't rely on colour alone to convey meaning.
- Readers can control text size, theme and motion.

## 6. Performance is a design constraint

Proposed budgets (to be validated and tightened with real measurement). Audience assumption: a mid-range Android phone on a slow mobile connection.

| Metric | Target |
|---|---|
| Largest Contentful Paint | ≤ 2.5 s (p75, mobile) |
| Interaction latency | ≤ 200 ms (INP, p75) |
| Layout shift | ≤ 0.1 (CLS) |
| JavaScript for a reading-only experience | small enough that the reading path works before it loads |
| Fonts | self-hosted, subsetted, `font-display: swap`, variable axes limited to those used |

An interaction that blows the budget is cut or deferred, not shipped.

## 7. Honesty in the interface

Treat honesty as a component, not an afterthought: data notes, source notes, "what this can and cannot show", and clear labelling of illustrative data are part of the design vocabulary. If a chart uses invented numbers, the page must say so where the chart is.

## 8. Tone

Plain, direct, warm. Short sentences. Verbs over nouns (*Begin*, *Deeper*, *Enter experience*). No jargon in reader-facing text. Humour is welcome if it never undercuts the idea.

## 9. How to review design work

A change is ready when it:

1. Serves the idea (passes the interaction test).
2. Uses existing tokens and components, or proposes a reusable addition.
3. Works at 375px and 1280px, keyboard-only, with a screen reader, in reduced motion, and in each theme.
4. Meets contrast and target-size rules.
5. Fits the performance and motion budgets.
6. Doesn't look like someone else's site.
