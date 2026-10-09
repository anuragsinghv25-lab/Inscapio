# Publisher journey

> **Status:** Phase 0 · Conceptual design. **Nothing here is implemented, and Phase 0 does not implement any of it.** The purpose is to document the intended workflow and the *architectural implications* so later phases do not paint themselves into a corner.

## The feeling to design for

The publisher should feel they are working with **an intelligent editorial partner**: someone who asks good questions, remembers what they said, spots what is missing, and proposes how to show an idea, while the publisher stays the author and the final judge.

Not a form. Not a text generator. Not a page builder.

## The workflow

```
Create ─► AI interview ─► Knowledge capture ─► Structure ─► Experience generation
                                                                      │
Analytics ◄─ Publish ◄─ Human review ◄─ AI review ◄─ Edit ◄─ Preview ◄┘
```

The flow is **not strictly linear**. The publisher can return to the interview from the editor ("I forgot an important example"), regenerate one section without touching the rest, and leave and resume at any time. State must be durable at every step.

## Stage by stage

| # | Stage | Publisher does | AI does | System produces | Main risk |
|---|---|---|---|---|---|
| 1 | **Create** | States what they want to make, in their own words: *"I want to create something about India's semiconductor industry."* | Acknowledges, proposes an experience *kind* (explainer, opinion, investigation, data story, deep dive) and a short plan for the conversation | A draft record; a topic guess | Too broad a premise; AI fixing the kind too early |
| 2 | **AI interview** | Answers questions conversationally; can paste notes, links, data, or documents | Asks one good question at a time: central idea, audience, what they believe, evidence and proprietary knowledge, key examples, what readers should understand afterwards, counter-arguments, sources, where interaction could help | An interview transcript | Shallow questions; leading the publisher; interrogating too long |
| 3 | **Knowledge capture** | Confirms or corrects a running summary | Extracts discrete, attributable statements ("knowledge items"): claims, examples, data points, definitions, sources, each linked to where the publisher said it | A set of knowledge items with provenance | AI inventing or "improving" claims; losing nuance |
| 4 | **Structure** | Reviews an outline: sections, order, what is surface and what is deeper | Proposes a narrative structure and a surface/deeper split; flags gaps ("you haven't addressed the strongest counter-argument") | An outline referencing knowledge items | One-size-fits-all structures |
| 5 | **Experience generation** | Approves, rejects or redirects each proposed interaction | Maps ideas to blocks from the **fixed vocabulary** (e.g. "this is a relationship over time → scrubber chart") and drafts block content from knowledge items | A structured experience (schema-valid JSON), **never HTML** | Interaction for its own sake; text the publisher did not say |
| 6 | **Preview** | Sees exactly what readers will see, on phone and desktop | n/a | A rendered preview through the production renderer | Preview that differs from production |
| 7 | **Edit** | Edits text, reorders, deletes, switches a block's type, or asks the AI to revise one block ("shorter", "more plain", "add a counter-argument") | Applies scoped changes; explains what it changed | New revisions | AI rewriting more than asked; voice drift |
| 8 | **AI review** | Reads a QA report | Checks unsupported claims, missing context, contradictions, readability, structure, accessibility, interaction consistency | An advisory report with locations | False positives wearing the publisher out; false negatives giving false comfort |
| 9 | **Human review** | Resolves findings; optionally invites a colleague to review; **explicitly approves** | Nothing: only the publisher can press publish | An approved revision | Rubber-stamping; review fatigue |
| 10 | **Publish** | Chooses title, slug, share image, topics; publishes | Suggests metadata | A publication of an immutable revision | Publishing the wrong version; irreversible exposure |
| 11 | **Analytics** | Reads where readers explored, went deeper, dropped off, or gave feedback | Suggests improvements (as drafts, per stage 7) | Aggregate metrics | Vanity metrics; privacy |

## Illustration: a first conversation

*Purely illustrative of tone and sequencing. Not a script.*

> **Publisher:** I want to create something about India's semiconductor industry.
> **InScapio:** Good. Before we shape anything: what's the one thing you want a reader to understand afterwards that they probably don't today?
> **Publisher:** That it's not about building a fab, it's about the whole supply chain.
> **InScapio:** That's a clear thesis. Who's it for: policy people, students, general readers? And is this your opinion, an explainer, or an investigation of something you found?
> …
> **InScapio:** You've said the chain has several stages, each with different players. That's a natural place for readers to *open one stage at a time* instead of reading a list. Want me to propose that? Also, what's the strongest argument against your thesis?

Note what the AI does *not* do: assert facts about the industry. It asks, structures and proposes, and only the publisher supplies the claims.

## Architectural implications

These are why the publisher journey belongs in Phase 0 even though nothing is built.

1. **Everything is a draft until a human says otherwise.** Drafts, revisions and publications are separate things. See [`content-model.md`](./content-model.md).
2. **Provenance is first-class.** Knowledge items link to the interview, and blocks link to knowledge items and sources. This is how QA can detect "AI wrote a claim the publisher never made".
3. **The AI's output type is structured content.** Every AI step returns schema-validated data. Free-form text is never rendered directly into a page. See [`../architecture/ai-architecture.md`](../architecture/ai-architecture.md).
4. **The renderer is the single source of preview and production.** Preview and publish use the same code path.
5. **Edits are scoped and reversible.** The system needs revision history and per-block regeneration with diffs, so the AI cannot silently rewrite the whole piece.
6. **Long-running and resumable.** Interviews span sessions. Server-side persistence at every step; no state held only in a browser tab.
7. **Cost and latency are product constraints.** Each stage's model calls need budgets, streaming for the conversational parts, and retries with clear error states.
8. **Human approval is an enforced state, not a convention.** Publishing is a server-side action that requires an approved revision; no AI path can set that state.

## What the MVP includes

Stages 1–11 in their *simplest* form (see [`../product/mvp-scope.md`](../product/mvp-scope.md)):

- Interview: one guided conversation with a core question set, not an open-ended agent.
- Knowledge capture and structure: shown to the publisher as editable summaries.
- Generation: limited to the MVP block set.
- Edit: structured, scoped, no free-form canvas.
- AI review: advisory report.
- Review and publish: single publisher; explicit approve-and-publish.
- Analytics: basic aggregates.

**Later:** teams and reviewers, comments, scheduled publish (still human-approved), A/B experiments, deeper analytics, richer research assistance, reusable publisher style profiles.

## Open questions

Tracked in [`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md): how much AI editing is acceptable, where the boundary between publisher voice and AI sits, whether publishers must attest to sources, and whether a second reviewer is ever required.
