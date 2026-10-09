# AI architecture

> **Status:** Phase 0 · Direction. **Nothing here is implemented and no AI integration is built in Phase 0.** The aim is to fix the *shape* so we do not build the wrong thing, while staying free to change implementation.

## The architectural stance

> **The AI proposes structured content. Code validates it. The publisher approves it. The renderer displays it.**

Not: *Publisher → AI → arbitrary HTML.*

Corollaries, each enforced technically rather than by convention:

1. AI output is **data conforming to InScapio's schema**. Never HTML, CSS or JavaScript. (Principle 6)
2. AI output is **always a draft**. It cannot approve or publish. (Principle 5)
3. Every claim in AI-generated content is **traceable to something the publisher said or a source they supplied.** (Principles 4 and 7)
4. The AI's job is **amplification of the publisher's knowledge**, not supplying its own. (Principle 4)

## Capabilities

Seven capabilities map to the publisher journey ([`../ux/publisher-journey.md`](../ux/publisher-journey.md)). Each is a **narrow, schema-bound function**, not an open-ended autonomous agent.

| # | Capability | Input | Output (schema-validated) | Notes |
|---|---|---|---|---|
| 1 | **Interview** | Conversation so far, knowledge items so far, what is missing | Next question(s); a running summary; new/updated knowledge items | Conversational and streaming. One good question at a time. Adapts to the experience *kind*. |
| 2 | **Structuring** | Confirmed knowledge items, kind, audience | An outline: sections, ordering, surface/deeper split, each item referenced by id | Identifies gaps and missing counter-arguments. |
| 3 | **Experience design** | Outline + knowledge items | For each idea, a proposed **block type with parameters** from the fixed vocabulary, with a one-line *reason* | Applies the interaction test: if text is better, it says so. |
| 4 | **Drafting** | One block's brief + referenced items | Block content (schema-valid), with provenance links | Scoped per block. Preserves the publisher's own wording where available. |
| 5 | **Editorial** | A block or section + an instruction ("shorter", "plainer", "add the counter-argument") | A **proposed change as a diff**, with a rationale | Never rewrites beyond the scope; preserves voice; the publisher accepts or rejects. |
| 6 | **Research** *(Later)* | A claim or gap | Candidate sources with verifiable links | MVP: only publisher-supplied sources. Research must return **verifiable** citations; no invented URLs. |
| 7 | **QA** | A full revision | A report: unsupported claims, missing context, contradictions, structure, readability, accessibility gaps, interaction consistency, each located by block id | **Advisory.** Never blocks or alters. |

Plus a **non-AI** step: **Human approval**, a server-side state transition only a human session can perform.

## Pipeline

```
 Publisher ─► [1 Interview] ─► knowledge items ─► publisher confirms
                                    │
                                    ▼
                            [2 Structuring] ─► outline ─► publisher edits/approves
                                    │
                                    ▼
                           [3 Experience design] ─► block proposals ─► publisher accepts/changes
                                    │
                                    ▼
                              [4 Drafting] ─► schema-valid blocks ──► validator ──► Draft
                                                                         │ invalid → repair loop (bounded) → else surfaced as error
 Publisher edits ─► [5 Editorial] ─► diff ─► publisher accepts ─► new Revision (author=ai)
                                    │
                                    ▼
                                [7 QA] ─► advisory report
                                    │
                                    ▼
                         Human review ─► ✔ Approve (human only) ─► Publish (human only)
```

Each arrow into the Draft passes the **validator**. A bounded repair loop may ask the model to fix schema errors; if it still fails, the publisher sees a clear failure and no partial content is written.

## Provenance and grounding

This is the main defence against "AI wrote something the publisher never said".

- **KnowledgeItem** (claim, example, definition, data point, source) is extracted from the interview and **confirmed by the publisher** before use.
- Each generated block records `derivedFrom: [knowledgeItemId…]` and `sources: [sourceId…]`.
- QA checks groundedness: *every factual statement should trace to a confirmed item or a source.* Statements that don't are flagged *unsupported*.
- Statistics, dates, quotations and names must come from a knowledge item or source. **The AI must not generate numbers.** If a block needs data (a chart), the data comes from the publisher or a cited dataset.
- The prototype's honesty pattern ("Demo data, not a forecast") becomes a required `illustrative` flag on datasets, enforced by schema.

## Constraining the output

| Mechanism | Purpose |
|---|---|
| **Structured output against a JSON Schema generated from the Zod schema** *(verify current provider features)* | Guarantees shape |
| **Closed enumerations** for block type, theme, accent, layout variant | No invented components or styles |
| **Content-only fields**: no HTML, URLs restricted to allowlists, rich text as a small AST | No code channel |
| **Tool/function interface limited to draft mutation** (`propose_block`, `propose_edit`…) | No path to publish, delete or read other data |
| **Validators** after generation | Never trust the model |
| **Separate credentials** for the AI service | Least privilege (see [`backend-architecture.md`](./backend-architecture.md)) |

## Untrusted input and prompt injection

Publishers will paste notes, upload documents and (Later) point at web pages. That material may contain instructions aimed at the model.

- **Treat all such material as data, never instructions.** Clearly delimit it in prompts and say so.
- **Capability limits are the real defence:** even a hijacked model can only propose draft changes that still pass the validator, and cannot publish, read other tenants' data or call external services.
- **No automatic fetching of arbitrary URLs** in the MVP.
- **Log inputs and outputs** (subject to the retention policy) so incidents can be investigated.
- Test with an **injection suite** as part of the evaluation set.

## Voice and editorial boundary

The line between *help* and *replacement* is a product question ([`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md)). The default stance until decided:

- **Preserve** the publisher's wording where it is already clear; offer **alternatives** rather than silently replacing it.
- Edits are **diffs** the publisher accepts, not overwrites.
- Distinguish **structural help** (ordering, gaps, interaction suggestions), which is generous, from **wording changes**, which are conservative and scoped.
- Track **authorship per revision** (`human` / `ai`) so the proportion of AI-originated text is observable.
- An optional **voice profile** (Later) drawn from the publisher's own writing, used for suggestions.

## Prompts, models and configuration

- **Prompts are code:** versioned in the repo, reviewed, with their purpose documented. No prompts assembled ad hoc in feature code.
- **Model choice is configuration**, not hard-coded: different capabilities may use different models (cheaper for classification and QA checks, stronger for interview and structuring). Model IDs live in config and are never written into docs or business logic. *(Check current model names and capabilities at implementation time.)*
- **Thin provider interface:** `generateStructured(capability, input, schema)` and `streamConversation(...)`. Swapping providers, or mocking, is a change in one module.
- **Context management:** the interview carries a rolling summary plus confirmed knowledge items rather than the entire transcript forever.
- **Caching:** use prompt caching where the provider supports it for stable instructions and the schema *(verify)*.

## Evaluation

AI quality is the product. We will not guess; we measure.

| What | How |
|---|---|
| **Interview quality** | Rubric scored by humans on recorded sessions: Did it find the central idea? Ask about evidence and counter-arguments? Avoid leading? Know when to stop? |
| **Groundedness** | Share of generated claims traceable to confirmed items/sources. Target: near total; unsupported = defect. |
| **Schema validity** | Rate of first-pass valid output; repair-loop rate. |
| **Voice preservation** | Human review on a sample: is the publisher's voice intact? |
| **QA detection** | Seed known flaws (an unsupported claim, a contradiction) into test documents and measure recall and false-positive rate. |
| **Injection resistance** | A suite of hostile inputs; must never publish, leak, or emit disallowed content. |
| **Publisher outcomes** | Draft acceptance rate, edit distance between AI draft and published text, time to publish, satisfaction. |

Evaluation sets live in the repo, run in CI on changes to prompts or schemas (with recorded responses for determinism plus periodic live runs), and gate prompt changes the way tests gate code.

## Cost, latency and reliability

- Per-capability **token and spend budgets**; per-publisher and global limits.
- **Streaming** for the interview; background jobs for heavy structuring and QA, with visible progress.
- **State saved before every model call;** failure is never data loss.
- Observability: every call logged in `ai_calls` (capability, model, tokens, latency, outcome) to track cost and quality over time.

## Safety, responsibility and review

- **Human approval is mandatory** and enforced in the data layer.
- **Content policy checks** run as part of QA for categories that raise legal or harm risk (identifiable private individuals, minors, open legal cases, health claims). These raise *flags for the human*, not automatic rejections.
- **Disclosure:** experiences may carry a note that AI assisted in drafting. Whether that is mandatory is an open question.

## What about "AI-generated interactive elements"?

The brief lists this as a possible future block. The honest position:

1. **Safe tier (now):** the AI *selects and parameterises* existing blocks. It cannot produce a new interaction.
2. **Constrained tier (Future):** the AI emits a *specification* in a small, verifiable DSL (for example a parametric model: variables, ranges, a formula over them, a mapping to a chart) that a platform-built block interprets. This would let something like the climate model be expressed as content. It requires a designed, sandboxed expression language; it is a substantial piece of work.
3. **Unsafe tier (not planned):** the AI writes JavaScript/HTML that runs in the reader's browser. This contradicts Principle 6 and brings security, accessibility, performance and quality risks. It would only be reconsidered in a **sandboxed, isolated-origin** form after a dedicated architecture review, and with human and automated review of every instance.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Shallow interviews produce confident, shallow content | Evaluation rubric; kind-specific question sets; publisher-visible knowledge summary; QA flags thin sections |
| Hallucinated facts or sources | No AI-generated statistics or URLs; grounding and provenance; source verification (Later) |
| Voice flattening | Diff-based edits; wording-conservative defaults; authorship tracking |
| Review fatigue → rubber-stamping | Concise, prioritised QA; explicit approval checklist; track findings ignored then regretted |
| Vendor dependency | Provider interface; evals portable across models |
| Cost blow-ups | Budgets and limits; cheaper models for checks |
| Prompt injection | Capability limits; delimiting; injection suite |
| Legal exposure from AI-assisted claims | Human approval; content-policy flags; publisher agreement |

## What the MVP includes

Interview → knowledge capture → structuring → block proposals → drafting → scoped editorial edits → advisory QA, over the **MVP block set**, with **publisher-supplied sources only**, single publisher, mandatory human approval. Research, voice profiles, constrained-DSL blocks and AI-assisted analytics are **Later/Future**.
