# Target users

> **Status:** Phase 0 · Draft. Personas are hypotheses to be tested with real conversations, not research findings.

InScapio serves two groups. They are not equally difficult to win, and the platform's ordering of priorities follows from that.

## Priority order

1. **Publishers** are the strategic constraint. Without publishers there is no content, and the AI-native workflow is the differentiator.
2. **Readers** are the proof. An experience nobody explores shows the bet is wrong, however good the tooling is.

The MVP therefore optimises for a **small number of high-quality publishers** and an **excellent but account-free reader experience**. See [`mvp-scope.md`](./mvp-scope.md).

---

## Readers

### Who they are (hypothesis)

Curious, time-poor adults who read to *understand* rather than to be informed about today's news. They have already tried long-form articles and explainers. They are comfortable on a phone. In India-first terms, many will arrive on mid-range Android over mobile data, so performance and legibility are not optional.

### What they want

- To grasp an idea quickly at a surface level, then go deeper only where curious.
- To trust what they are reading: sources visible, claims honest, uncertainty acknowledged.
- To feel they did something, not only consumed something: chose, compared, predicted, tested.

### What frustrates them today

- Articles that bury the idea under preamble.
- Interactive pieces that are gimmicks: scroll-jacking, animation for its own sake, content that is harder to read than the plain text.
- No way to control depth: either a shallow summary or a 5,000-word wall.
- Feeds that reward outrage over understanding.

### Reader value proposition

> **Ideas you can step inside. Simple first, deeper when you're curious, and honest about what's known.**

### Reader sub-types (to refine, not to build for separately yet)

| Sub-type | Behaviour | Needs | Phase |
|---|---|---|---|
| **Drop-in** | Arrives from a shared link; may never return | Instant load, zero friction, no account, a reason to explore another | MVP |
| **Explorer** | Browses topics, opens several experiences | Discovery, topic pages, a sense of place | MVP (light) |
| **Follower** | Wants more from a publisher or topic | Follow, email updates | Later |
| **Supporter** | Willing to pay for a publisher | Subscriptions, entitlement | Future |

---

## Publishers

### Who they are (hypothesis)

People and small organisations who *know something deeply* and publish it today as articles, reports, threads, newsletters or PDFs. They are not necessarily writers, and certainly not front-end developers.

Candidate segments, in rough order of fit. **The initial segment is an open decision; see [`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md).**

| Segment | Why a fit | Why risky |
|---|---|---|
| **Independent domain experts and analysts** (e.g. a semiconductor-industry analyst, an economist, a public-health researcher) | Own proprietary knowledge and data; need a way to stand out; the user's own example ("India's semiconductor industry") is in this segment | Small individual audiences; unclear willingness to pay |
| **Mission-driven organisations** (NGOs, research institutes, think tanks) | Explaining complex ideas is their purpose; have credibility and data | Slow decision cycles; compliance and sign-off requirements |
| **Educators and course creators** | Interactive explanation is directly valuable | Crowded with existing tools; may want LMS features |
| **Niche trade and specialist media** | Existing audience, regular output | Likely to want integration with their current CMS |
| **General media houses** | Large audiences | Heavy workflow and brand requirements; long sales cycles; not an MVP segment |

### What they want

- To get a *complex idea across* and be taken seriously.
- To spend their time on what they know, not on layout, charts or code.
- To keep their voice and credit, and control what goes live.
- To know whether it worked: who read it, how far, where they dropped off.

### What frustrates them today

- Interactive journalism is out of reach without a team.
- CMS forms ask for fields, not for thinking.
- Generic AI writing tools produce text that sounds like everyone else's and invites distrust.
- They have no signal beyond page views.

### Publisher value proposition

> **Bring what you know. InScapio interviews you, structures it, and shows you an experience you can edit and publish, under your name and your control.**

### Publisher sub-roles (Future, noted so the model does not block them)

Individual author · editor · contributor · reviewer · organisation owner. The MVP assumes a single publisher account per experience. The data model should not make multi-user ownership impossible later. See [`../ux/content-model.md`](../ux/content-model.md).

---

## What we do not know yet

These materially affect priorities and are tracked in [`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md):

- Which publisher segment will tolerate an early, imperfect tool in exchange for a strong result.
- Whether publishers want a *conversation* or just a better starting point; the AI-interview thesis is a hypothesis about preference, not a fact.
- Whether readers will seek out InScapio, or mostly arrive through publishers' own audiences (which changes the importance of discovery).
