# Product vision

> **Status:** Phase 0 · Draft for owner review
> **Source of truth for:** where InScapio is going. For what exists today, see [`../design/current-design-audit.md`](../design/current-design-audit.md).

## One sentence

**InScapio is an AI-native publishing platform where a publisher's knowledge becomes an experience a reader can explore, not just scroll.**

The reader-facing line, already in the prototype, stays: *Don't just read it. Explore it.*

## The problem

Most knowledge on the web arrives as a headline, a paragraph, another paragraph, and a scroll. That format is cheap to produce and cheap to consume, and it is often the wrong shape for the idea.

- Some ideas are about **relationships between quantities** (how a city's climate changes with time). A paragraph can state them, but a reader only *feels* them by moving a slider.
- Some ideas are about **layers and trade-offs** (why harm has roots, not just a cause). A reader understands them faster when they can open one layer at a time.
- Some ideas are **contested** (the arguments people throw at each other online). A reader benefits from seeing the claim, what is true in it, and what does not follow from it, side by side.

Interactive explanations exist, but they are expensive. A single good one takes a designer, an engineer, an editor and weeks. So almost nobody who *has* knowledge (an analyst, a researcher, a domain expert, an NGO, a trade publication) can produce one.

## The opportunity

Two things changed:

1. Language models can now hold a structured conversation with a domain expert and turn what the expert says into organised content.
2. If that content is **structured data rather than free text or code**, a platform can render it as a designed, accessible, interactive experience without every publisher needing a front-end team.

InScapio is a bet that the combination (AI interview + structured content + a controlled experience layer) lets an expert publish something far richer than an article at roughly the effort of writing one.

## What InScapio is

| | |
|---|---|
| **For readers** | A place to discover and explore ideas that are designed to be understood, with progressive depth that the reader controls. Editorial, immersive, intelligent. |
| **For publishers** | An editorial partner that interviews them, structures what they know, proposes where interaction would help, and produces a reviewable experience. The publisher stays the author. |
| **For the platform** | InScapio owns the experience layer: the schema, the renderer, the design system, the accessibility baseline and the quality bar. |

## What InScapio is not

- **Not an AI article writer.** Text generation is a commodity. The product is the transformation of knowledge into an *experience*, and the AI is in service of the publisher's knowledge, not a substitute for it.
- **Not a Medium or Substack alternative.** We are not competing to host essays. See [`positioning.md`](./positioning.md).
- **Not a CMS with an AI sidebar.** The publisher's primary interface is a conversation and a preview, not a form.
- **Not an AI website builder.** The AI does not generate arbitrary pages. It generates structured content that InScapio's renderer displays. See [`principles.md`](./principles.md) (Principle 6) and [`../architecture/ai-architecture.md`](../architecture/ai-architecture.md).
- **Not a feed.** Discovery should feel curated and editorial, not like an infinite algorithmic scroll.

## The bet, stated so it can be tested

We believe:

1. There are publishers with real knowledge who currently publish it as plain articles or PDFs because anything richer is out of reach.
2. An AI-led interview can extract enough structure from them to produce a draft experience that they judge *better than their own article* and would put their name on.
3. Readers who go through such an experience understand or retain more, and share it more, than they do with the equivalent article.

The MVP exists to test (2) and (3). Claim (1) is validated by who says yes to the first conversations. See [`mvp-scope.md`](./mvp-scope.md) for what we build to test them and what we deliberately do not.

## Long-term shape

Stated as direction, not commitment. Anything beyond the MVP is **Future**.

1. **Now (prototype v0).** Two hand-built experiences prove the *feel* and the reader interactions. No publishers, no accounts, no backend.
2. **Next (MVP).** The same experiences expressed as structured data and rendered by an InScapio renderer. A small group of invited publishers create experiences with AI assistance. Readers browse and read without accounts.
3. **Later.** Follow publishers and topics, subscriptions and notifications, analytics for publishers, a richer block library, review tooling.
4. **Future.** Premium content and payments, publisher organisations and teams, a marketplace of experience templates, embeds, an API.

## How we will know it is working

Leading indicators, to be instrumented in the MVP (targets are placeholders to be set with real data; see [`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md)):

- **Publisher:** time from first conversation to a published experience; share of AI drafts a publisher accepts with light edits; whether the publisher returns for a second experience.
- **Reader:** completion of an experience; use of the "Deeper" layer; interaction rate per block; share rate; return visits.
- **Quality:** accessibility audit pass rate; rate of AI-QA findings caught before publication versus after.

## Honest risks to the vision

Detail is in [`positioning.md`](./positioning.md). In brief: the hardest part is not the AI interview, it is expressing genuinely different ideas in a *finite* vocabulary of blocks without making every experience feel templated, and getting enough publishers to care about interactivity over plain text.
