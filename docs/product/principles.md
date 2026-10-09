# Product principles

> **Status:** Phase 0 · Proposed. These are meant to be used to settle arguments, so each one states what it rules **out** as well as what it rules in.

Seven principles. Each has an example from the existing prototype where one exists, so they describe what InScapio already does well, not only what it hopes to do.

---

## 1. Knowledge should be explorable, not merely scrollable.

The reader acts, not just receives: choosing, comparing, predicting, opening. The default alternative (scrolling prose) is always available as the baseline.

- **In the prototype:** the home page's *Read ↔ Explore* slider puts one idea in both forms side by side. The climate experience asks the reader to guess before it reveals.
- **Rules out:** interaction that is only decoration; experiences that cannot be understood without interacting.

## 2. The experience must serve the idea.

An interaction earns its place only if the idea would be weaker without it. If a paragraph does the job better, use the paragraph.

- **In the prototype:** the climate chart exists because the point is a *relationship over time*. "Whose Body Is It?" is mostly text because its ideas are arguments, and it uses interaction sparingly: accordions, a classification quiz, filtered cards.
- **Rules out:** adding a block because it looks impressive; "interactive" as a goal in itself. The test is in [`../design/design-principles.md`](../design/design-principles.md).

## 3. Readers control depth. Simple first, deeper when curious.

Every experience has a clear surface a reader can finish. Context, sources, nuance and harder questions sit behind an explicit, reader-initiated "Deeper" layer. The reader is never forced into depth and never denied it.

- **In the prototype:** the *Deeper* toggle in both experiences; the About page's "Every experience has a deeper layer. It stays closed until you ask for it."
- **Rules out:** hiding essential caveats in the deeper layer; making depth the only way to understand the surface.

## 4. AI amplifies the publisher's knowledge. It does not replace the publisher's voice.

The knowledge, claims and judgement are the publisher's. The AI interviews, structures, edits for clarity, and points out gaps. It does not invent expertise or substitute its own opinions.

- **Rules out:** generating claims the publisher did not make or confirm; flattening distinct voices into one house style; presenting AI-originated text as the publisher's own without their review.

## 5. Nothing is published without human approval.

AI output is always a draft. A publisher reviews and explicitly approves every experience before it goes public. The platform's own review (QA checks) informs the decision; it never makes it.

- **Rules out:** auto-publish, "publish on schedule without a final look", background AI edits to a live experience.

## 6. InScapio owns the experience layer.

Publishers provide knowledge and intent. InScapio provides the schema, the renderer, the design system and the quality bar. AI generates *structured content*, never arbitrary front-end code.

- **Why:** consistency, accessibility, performance, security and the ability to improve every experience at once by improving the renderer.
- **Rules out:** AI-generated HTML or JavaScript shipped to readers; publishers injecting arbitrary scripts; one-off per-experience front-end code outside a reviewed block. See [`../architecture/content-architecture.md`](../architecture/content-architecture.md) and [`../architecture/ai-architecture.md`](../architecture/ai-architecture.md).

## 7. Be honest about what we know.

Claims have sources. Models and data say what they are. Uncertainty is shown, not hidden. A confident tone is not a substitute for evidence.

- **In the prototype:** the climate experience states *"Demo data, not a forecast"* and names the real sources for real numbers. "Whose Body Is It?" lists its sources, separates what a case can show from what it cannot, and warns that open cases can change.
- **Rules out:** unlabelled illustrative data; AI-generated statistics; certainty beyond the evidence.

---

## Supporting commitments

Not headline principles, but equally binding. They are enforced in the design and engineering docs.

- **Accessible by default.** Keyboard, screen reader, reduced motion, readable contrast, large touch targets. The prototype already does much of this and the bar must not drop.
- **Fast on modest devices.** A reader on a mid-range phone and a slow connection is the design target, not the exception.
- **Respect the reader.** No account to read, no dark patterns, no scroll-jacking, privacy-preserving analytics.

## Using these principles

When a decision is contested, name the principle in the discussion and the decision log ([`../DECISIONS.md`](../DECISIONS.md)). A proposal that violates a principle needs the *principle* to be revised first, deliberately, rather than being quietly worked around.
