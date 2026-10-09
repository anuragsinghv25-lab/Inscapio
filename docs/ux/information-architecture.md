# Information architecture

> **Status:** Phase 0 · Proposed. **Current** = in prototype v0. **MVP / Later / Future** = planned.

## Principles for the structure

1. **The experience is the destination; everything else is a way to reach one.** Most readers will land directly on an experience from a shared link, not on the home page. Every experience must make sense as a front door.
2. **Few top-level things.** A reader should hold the whole site in their head.
3. **Chrome gets out of the way inside an experience.** The prototype already hides the site navigation inside experiences and replaces it with experience controls. Keep that.
4. **Clean, stable, shareable URLs.** The prototype's router already mirrors future paths (`/experiences/<slug>`). Preserve the paths, drop the `#`.
5. **Two surfaces, one platform.** Reader and publisher are different products with different needs; they share a design system and a content model, not a navigation bar.

## Sitemap

### Reader surface

| Path | Page | Status | Notes |
|---|---|---|---|
| `/` | Home | **Current** → MVP | Opening (title, Read↔Explore strip), featured experiences ("rooms"), what-is-InScapio, closing call to action |
| `/explore` | Discover | Current (as a scroll target on home) → MVP | Becomes a real page: curated experiences, topics, publishers |
| `/about` | About | **Current** → MVP | Carries the philosophy and a miniature of "go deeper" |
| `/experiences/[slug]` | Experience | **Current** → MVP | The product's core page |
| `/topics` | Topic index | MVP (simple) | |
| `/topics/[slug]` | Topic page | MVP (simple) → Later | Title, framing, experiences; follow later |
| `/publishers/[handle]` | Publisher profile | MVP (simple) → Later | Bio, experiences; follow later |
| `/search` | Search | Later | Not needed at MVP scale |
| `/following` | Following | Later | Requires reader accounts |
| `/saved` | Saved | Later | Requires reader accounts |
| `/account` | Reader account | Later | Settings, subscriptions, notifications |
| `/notifications` | Notifications | Later | Likely email first, in-app later |
| `/legal/*` | Terms, privacy, content policy | MVP | Required before outside publishers |

Existing aliases in the prototype (`#/body`, `#/climate`) exist for convenience and should become redirects.

### Publisher surface ("Studio")

| Path | Page | Status |
|---|---|---|
| `/studio` | Dashboard: drafts, published, analytics summary | MVP |
| `/studio/new` | Start a new experience (opens the AI interview) | MVP |
| `/studio/drafts/[id]` | Workspace: interview, structure, preview, edit, QA | MVP |
| `/studio/experiences/[id]` | Published experience: revisions, unpublish, analytics | MVP |
| `/studio/profile` | Publisher profile and byline | MVP |
| `/studio/team` | Members and roles | Future |
| `/studio/subscribers` | Audience | Later |
| `/studio/earnings` | Payments | Future |

### Internal

| Path | Page | Status |
|---|---|---|
| `/admin` | Invites, curation of home and topics, takedown | MVP (minimal) |

## Navigation philosophy

- **Site chrome:** wordmark, **Explore**, **About**. In Later phases, **Following** and an account entry appear *only when signed in*. The reader is never nudged to sign in to read.
- **Experience chrome:** back to InScapio, the experience title, **Deeper**, text size, light/dark, a thin progress line. All from the prototype. Site navigation is hidden.
- **Within an experience:** navigation is the *content itself* (chapters, "Begin", "Jump to the arguments"), not a menu. Long experiences may add a chapter index; it should be an aid, not a requirement.
- **After an experience:** a deliberate end state: what to explore next, feedback, share, and later, follow. **Gap in v0:** today the experience simply ends in a feedback form.
- **Studio chrome:** a quiet workspace shell: draft list, current step, preview toggle. No marketing.

## Content hierarchy

```
Platform
├── Topics            (curated groupings: e.g. "Climate", "Society")
├── Publishers        (people, later organisations)
└── Experiences       (the unit of publication)
    └── Sections      (chapters; one accent / mood each)
        └── Blocks    (text, callouts, interactions, charts, sources)
            └── may carry a "Deeper" layer (reader-revealed context)
```

Details of the model are in [`content-model.md`](./content-model.md).

## Discovery model

- **MVP:** hand-curated. Home features a few experiences, each presented as a "room" with a small interactive sample (the prototype shows a live fragment of each experience on the home page, which is a strong pattern to keep). Topic pages are manual lists.
- **Later:** search, "related experiences" at the end of an experience, follower-based updates.
- **Avoid:** an infinite algorithmic feed. It contradicts the editorial positioning and rewards the wrong behaviour.

## URL and SEO rules

1. Every experience has one canonical URL and renders meaningful text server-side.
2. Every deep link should land somewhere sensible, including `#chapter` anchors within an experience.
3. Per-experience title, description and share image. **Gap in v0:** the single-page prototype shares one set of metadata for every route.
4. Draft and preview URLs are never indexable.

## Labels and voice

Short, concrete verbs: *Begin*, *Deeper*, *Enter experience*, *Explore*. No jargon in reader-facing labels (no "block", "schema", "revision"). Terms used internally are defined in [`content-model.md`](./content-model.md).
