# MVP scope

> **Status:** Phase 0 · Proposed boundary. Everything below is **Planned** or **Future**; nothing here exists yet except what is marked **Current (prototype v0)**.

## What the MVP is for

The MVP is not "a smaller version of the whole product." It is the **smallest thing that can falsify the core bet** (see [`vision.md`](./vision.md)):

> An invited publisher can go from *what they know* to *a published InScapio experience they are proud of*, using an AI-led interview, and readers explore it.

It must prove four claims (from [`positioning.md`](./positioning.md)):

1. A publisher gets to an experience they prefer to their own article.
2. A finite block vocabulary can express enough different ideas.
3. Readers engage differently with it than with plain text.
4. Human review feels like editing a strong draft.

## Shape of the MVP

A **closed alpha**: roughly 5–10 invited publishers, public reader pages, no reader accounts.

```
Invited publisher ─► AI interview ─► structured draft ─► preview ─► edit ─► AI QA ─► human approval ─► publish
                                                                                                   │
                                          Anonymous reader ◄─ public experience page ◄──────────────┘
                                                  │
                                                  └─► feedback + privacy-light analytics ─► publisher
```

## In scope (MVP)

### Reader side: thin but excellent

| Capability | Notes |
|---|---|
| Home page | Curated, editorial. Carries forward the prototype's opening, rooms and closing. |
| Experience page | Server-rendered, fast, accessible. The core of the product. |
| About page | Carries forward the prototype's. |
| Topic pages | Minimal: a topic title and its experiences. May be a simple list at launch. |
| Publisher profile | Minimal: name, bio, their experiences. |
| Reading controls | Deeper toggle, text size, light/dark. Carried over from the prototype. |
| Share | Native share or copy link, with a per-experience preview image and title. |
| Feedback | Carried over from the prototype but **stored in a database** (today it stays on the visitor's device). |
| Analytics | Privacy-light, aggregate: views, completion, deeper-layer use, per-block interaction. No third-party trackers. |

### Publisher side: the heart of the MVP

| Capability | Notes |
|---|---|
| Invite-only sign-in | Secure auth; no public sign-up. |
| Create from a conversation | AI interview: central idea, audience, claims, evidence, examples, counter-arguments, sources, "where could interaction help". See [`../ux/publisher-journey.md`](../ux/publisher-journey.md). |
| Structured draft | The AI output is *structured content*, not HTML. See [`../architecture/ai-architecture.md`](../architecture/ai-architecture.md). |
| Live preview | Renders through the same renderer readers see. |
| Structured editing | Edit text in blocks, reorder, delete, change a block's type, ask the AI to revise a block. **No** free-form canvas or drag-and-drop page builder. |
| Sources | Attach sources to claims; a "sources" section is generated. |
| AI QA report | Unsupported claims, missing context, contradictions, readability, accessibility gaps. Advisory only. |
| Human approval | Explicit publish action by the publisher. No auto-publish, ever. |
| Revisions | Save and restore previous versions. |
| Basic analytics | Per-experience reader metrics. |

### Platform

Experience schema and renderer · design-system components for the MVP blocks · publisher auth · content storage with versioning · preview and publish pipeline · AI interview and structuring pipeline behind a server-side boundary · automated tests and an accessibility check in CI. See [`../architecture/architecture-overview.md`](../architecture/architecture-overview.md).

## MVP block set

Each block here already exists in some form in the prototype, which is why it is a safe MVP commitment. Details and schemas are in [`../architecture/content-architecture.md`](../architecture/content-architecture.md).

| Block | Prototype origin | MVP? |
|---|---|---|
| Heading, paragraph, lead | Both experiences | **MVP** |
| Callout / pull statement | "say" blocks, climate `.an` | **MVP** |
| Info card | "Accept / Equality is not sameness" cards | **MVP** |
| **Deeper** (reader-revealed context, attachable to any block) | `.deep`, `.dp` | **MVP** (core primitive) |
| Expandable layers (accordion) | Home bands, "root causes" layers | **MVP** |
| Stepper (cumulative reveal) | "How honour becomes control", "ladder to culture" | **MVP** |
| Claim and response cards with filter | "What people say on X" | **MVP** |
| Classify quiz | "Safety advice or blame?" | **MVP** |
| Selector → content | "What you can do" persona chips | **MVP** |
| Comparison table | Claim / what can be true / what does not follow | **MVP** |
| Sources and data note | Footer sources, "Demo data" note | **MVP** |
| Resource box | Helpline box | **MVP** |
| Scrubber chart (precomputed data, time or parameter slider) | Climate experience | **MVP**, *and the key test of the schema* |
| Predict-then-reveal | Climate "which city will it resemble?" | **MVP** (as an interaction on the chart block) |
| Image (alt text required) | none today | MVP-stretch |
| Timeline | none today | Later |
| Quote (attributed) | none today | Later |
| Video, map, embed | none today | Future |
| Parametric model block (constrained formula spec) | Climate model maths | Future |
| Platform-built custom blocks | n/a | Later, by the InScapio team only |
| AI-generated interactive element | n/a | **Not planned** without an architecture review |

## Explicitly out of scope (MVP)

Each item is a deliberate "not yet", not an oversight. The reason in each case is that the MVP must test the core claims first.

- **Reader accounts, follow, subscribe, notifications, saved content.** They do not help prove the four claims, and they add privacy and compliance obligations.
- **Payments, premium content, paid subscriptions.** Monetisation should be tested after the content loop works. See [`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md).
- **Public publisher sign-up.** Quality and legal exposure first; invite-only.
- **Publisher teams and organisations.** The data model should not prevent them, but there is no UI.
- **Comments and reader-to-reader features.** Moderation burden; not core to the bet.
- **Recommendation engine and search.** Curated discovery is enough for a handful of publishers.
- **Video, maps, custom code, third-party embeds.** Each adds security and performance risk.
- **AI that publishes, edits live content or generates front-end code.** Contradicts principles 5 and 6.
- **Multiple languages, native apps, public API.**
- **Visual page builder.** The reverse of principle 6.

## Constraints on the MVP

- **Accessibility.** WCAG 2.2 AA is the target and is checked in CI. The prototype's baseline (keyboard, focus management, `prefers-reduced-motion`, 44–48px targets) must not regress.
- **Performance.** Reader experience pages are server-rendered, usable without JavaScript for the reading path, and budgeted for mid-range mobile on a slow connection. Targets are proposed in [`../design/design-principles.md`](../design/design-principles.md).
- **Preservation.** The two existing experiences must be reproducible through the new renderer with no loss of the interactions that matter. Re-expressing them as data is the **first** technical milestone. See [`../architecture/migration-strategy.md`](../architecture/migration-strategy.md).
- **Safety and legal.** A publisher agreement and content policy exist before the first outside publisher is invited. Content about identifiable private individuals or open legal cases follows an explicit review rule. This needs legal advice and is not decided here.

## Proposed phasing

A sketch for planning, not a commitment. Each phase should end in something demonstrable and be tracked in [`../DECISIONS.md`](../DECISIONS.md).

| Phase | Goal | Demonstrates |
|---|---|---|
| **0** (this one) | Foundation docs and decisions | A shared plan |
| **1** | Schema and renderer spike: express both prototype experiences as data and render them in a Next.js app | Claim 2 (finite vocabulary is enough); visual and behavioural parity with v0 |
| **2** | Platform: database, publisher auth, storage, publish pipeline, public reader site, feedback stored | A hand-authored experience published end to end |
| **3** | AI interview and structuring, preview, structured editing | Claim 1 with internal "publishers" |
| **4** | AI QA, human approval flow, revisions, analytics; legal and policy groundwork; invite first outside publishers | Claims 1, 3, 4 with real publishers |
| **5** | Reader-side growth: follow, email updates, notifications. Informed by what Phase 4 teaches | New decisions, not predetermined |

**Recommended Phase 1** is described in the final Phase 0 report and is **not started** here.

## Exit criteria for the MVP

The MVP has done its job when we can answer, with evidence, all of:

1. Did publishers prefer the experience to their own article, and would they publish another?
2. What fraction of AI drafts were accepted with light editing?
3. Did the block set express the ideas publishers brought, and where did it fail?
4. How did readers' completion and sharing compare to plain text?
5. Is the human-review step sustainable, or is it the bottleneck?

A negative answer to any of these is a valid result and changes the plan.
