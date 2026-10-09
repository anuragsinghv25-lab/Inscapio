# Product positioning

> **Status:** Phase 0 · Draft. Comparisons describe each category's *primary design intent* as we understand it, not a feature audit. **Verify before using any of this externally.** We make no claim that InScapio is better than any of them.

## Intended positioning

> **AI-native publishing of interactive knowledge experiences.**

Unpacked:

- **Publishing**: there are publishers, readers, and a public surface. This is a platform, not a tool.
- **Knowledge**: the unit is an *idea someone understands deeply*, not a post, a page or a product.
- **Interactive experiences**: the output is designed to be explored (choose, compare, predict, go deeper), not scrolled.
- **AI-native**: the AI is how the publisher *creates*, via interview → structure → experience, not a text box bolted onto an editor.

## Where InScapio sits

| Category | Primary job | Where InScapio differs (intent) | Where they are stronger today |
|---|---|---|---|
| **Medium** | Hosted writing and a reading network | Output is an interactive experience, not a post. We are not trying to host every essay. | Network effects, reader habits, distribution, brand |
| **Substack** | Newsletters with paid subscriptions | Experience-first rather than inbox-first. Subscription is a later layer, not the core. | Direct publisher-to-reader relationship, payments, proven monetisation |
| **Traditional CMS** (WordPress, Ghost, headless CMSs) | Manage and publish content to a site the owner controls | Publisher doesn't fill fields or design pages; the platform owns the experience layer. Trade-off: less flexibility. | Flexibility, ownership, plugin ecosystems, SEO control |
| **Generic AI writing tools** | Produce text quickly | Not text generation. The AI interviews the publisher and structures *their* knowledge into an experience, with their voice and review. | Speed of raw drafting; broad general-purpose use |
| **Blogging platforms** | Low-friction personal publishing | Higher ceiling on what a piece can be; higher floor on design quality | Simplicity, familiarity, price |
| **AI website builders** | Generate a site or page from a prompt | InScapio does not generate arbitrary pages. It generates *structured content* inside a controlled system. | Visual freedom, breadth of what can be built |
| **News sites** | Report the day's events | Timeless, explorable *understanding* rather than timely reporting | Reach, authority, immediacy |
| **Data-viz and interactive tools** (e.g. chart builders, notebook platforms) | Make charts or interactive pieces | Whole-experience scope: narrative, structure, depth control and an AI interview, not a single chart | Chart depth and polish for their specialty; established publisher workflows |
| **Interactive-journalism studios** | Bespoke, high-craft interactive stories | Aims to bring *some* of that to publishers without a studio. Will not match bespoke craft. | Craft, originality, ambition |

The last two rows matter most. They are the closest in *output*, and the honest comparison is that InScapio will be less bespoke and more accessible.

## Why this is interesting

1. **The cost curve.** Interactive explanation is expensive because it needs several disciplines. If structured content plus a controlled renderer collapses that cost, an entire class of publisher who cannot currently afford it becomes viable.
2. **The AI is used where it is strongest.** Interviewing, structuring, spotting gaps and proposing where interaction helps are all language tasks. Rendering is deterministic code. The split plays to each side's strengths.
3. **It answers the main objection to AI publishing.** The common worry is generic, untrustworthy AI content. Here the *knowledge* comes from the publisher, the *structure* is constrained, and *a human approves*.
4. **Quality can be enforced.** Because InScapio owns the renderer, accessibility, performance and design quality are properties of the platform, not of each publisher's skill.

## What problem it solves

For publishers: *"I know this deeply, I can't make it explorable, and an article undersells it."*
For readers: *"I want to understand this, not skim it."*

## Risks (be critical here)

| # | Risk | Why it is real | What would reduce it |
|---|---|---|---|
| 1 | **The block vocabulary is too small or too generic.** | The prototype's two experiences already need very different interaction logic: a parametric climate model with time scrubbing and prediction, versus accordions, quizzes and flip cards. A finite block set risks every experience feeling templated, or being unable to express the publisher's idea. | A tiered block model: declarative blocks, a constrained parametric-model block, and platform-built custom blocks. See [`../architecture/content-architecture.md`](../architecture/content-architecture.md). Test early by re-expressing the prototype as data. |
| 2 | **Publishers may not value interactivity enough to change behaviour.** | Many publishers are happy with text. The pain may be weaker than assumed. | Validate with real publishers before building the editor. Measure whether they *prefer* the experience to their own article. |
| 3 | **AI-interview quality is the product, and it is hard.** | A shallow interview yields shallow content that sounds confident. | Evaluation sets, human review gates, narrow experience types first. See [`../architecture/ai-architecture.md`](../architecture/ai-architecture.md). |
| 4 | **Trust and liability.** | The platform will host others' claims. The prototype itself includes content about a real, recent criminal case involving minors. That is exactly the kind of content that raises defamation, privacy and legal exposure at scale. | Human review before publication, a publisher agreement and content policy, a sources-and-claims layer, legal advice before opening to the public. Not legal advice. |
| 5 | **Two-sided cold start.** | Publishers want readers; readers want content. | Invite-only publishers; publishers bring their own audience; reader side stays light and account-free in the MVP. |
| 6 | **Foundation-model commoditisation.** | Anyone can prompt a general model to build an interactive page. | Defensibility comes from what a general model cannot do alone; see below. |
| 7 | **"Interactive" can become gimmicky.** | The web is full of animation that makes content harder to read. | Principle 3 and the interaction tests in [`../design/design-principles.md`](../design/design-principles.md). |
| 8 | **Distribution and SEO.** | Interactive pages can be thin for crawlers; discovery depends on search and sharing. | Server-rendered content, meaningful text in every block, per-experience share metadata. |

## What would make it defensible

None of these exist yet. They are the things to build *toward*.

1. **The experience schema and renderer as a quality system.** A well-designed, versioned block vocabulary with accessibility, performance and design baked in is hard to replicate and compounds as blocks are added.
2. **An interview and structuring pipeline tuned on real publisher data.** Prompts, evaluations and review tooling improve with use.
3. **Publisher trust and credit.** A reputation for accurate, well-sourced experiences, with sources visible and human review enforced.
4. **Publisher-owned audiences on InScapio.** Follows and subscriptions, once they exist, create switching costs.
5. **Analytics that explain *understanding*,** not page views: where readers use depth, where they drop off, which interactions are used. A plain article cannot offer this.

A model that can write HTML is not, on its own, a threat to any of these; it is a *tool* the pipeline may use inside constraints.

## What the MVP needs to prove

1. **A publisher can get to an experience they are proud of, faster and with better results than their own article.** (the critical claim)
2. **A finite, well-chosen block set can express enough different ideas.** Test: express both prototype experiences, then one new idea from a real publisher, without writing custom code for the new one.
3. **Readers engage differently.** Compare completion and sharing against a plain-text version of the same content.
4. **Human-in-the-loop review is tolerable.** Review must feel like editing a strong draft, not repairing a bad one.

If (1) fails, no amount of reader polish saves the product. If (2) fails, the architecture needs rethinking. If (3) fails, the premise is weaker than assumed. Each of these must be treated as a legitimate possible outcome.

## Open positioning questions

See [`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md): what qualifies as an experience, the initial publisher segment, individuals versus organisations, and how much AI involvement is acceptable.
