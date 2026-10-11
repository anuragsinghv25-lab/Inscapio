# Phase 1.5 · Experience specification

> **Status:** Phase 1.5 · Proposed, pending owner review. This is a **design specification**, not an implementation. Nothing here is built; nothing here changes the schema, the renderer or any page. Where a proposal would need a schema or block change, it says so and is marked **needs decision** (CLAUDE.md: for schema or block-vocabulary changes, propose, don't implement).
> **Evidence:** [`phase-1-5-product-design-review.md`](./phase-1-5-product-design-review.md). Finding numbers (F1…) refer to its Section 9.

## 1. What this specification covers

1. The homepage.
2. The reader-experience architecture: what is the same in every experience and what varies by subject, tested against the two existing experiences.
3. The publisher workspace at information-architecture and user-flow level only (no screens, no components).

It deliberately does **not** specify colours, components, visual styling of the publisher workspace, or any AI behaviour beyond what the workspace must show.

## 2. Homepage

### 2.1 Job of the homepage

One job: **let a first-time visitor do the thing InScapio is about, within seconds, without being told how.** The positioning line is "Don't just read it. Explore it." A homepage that only *says* this is a landing page. A homepage that lets the visitor *do* it is evidence.

### 2.2 What exists and what is wrong with it

Today (screenshots, both widths): a headline, a Read↔Explore strip that wipes one idea from prose to chart, a "Whose Body Is It?" band with a six-layer accordion, a climate band with a city wall, an About line, and a closing call to action. The structure is right. Specific problems (F8):

- **Correction (Stage 2):** an earlier draft said the "explore" half was a narrow sliver at 1280 px; that came from a screenshot taken before the one-off wipe animation ran. Once settled, the real problems are: at 1280 × 800 the large headline pushes the strip down so its slider is below the fold; at 375 px the strip has a fixed height and fades out its text; and the wipe seam cuts through words at rest.
- Both bands have a working in-place interaction (the accordion; the city wall, where tapping a city reveals the city it will resemble). In the 1280 px screenshot, however, the city wall reads as a list of names and the answer line is easy to miss, because nothing is selected until the visitor taps.
- No indication of how many experiences exist, how long each takes, or what to do after finishing one.

### 2.3 Proposed structure (top to bottom)

| Block | Purpose | Notes |
|---|---|---|
| **Header** | Name; "Explore", "About" | As today |
| **1. Hero with one live interaction** | The headline *and* the Read↔Explore control, both visible on the first fold at 375 and 1280 px | The control's two states must each be readable in full at rest. Default position shows the **Explore** state's visual and the Read state's first sentence, so the visitor sees both. |
| **2. The experiences** | One entry per published experience: title, one-line promise, "takes about N minutes", and the interaction in miniature | N is stated only where measured or reasonably estimated from word and interaction count, and labelled an estimate until measured. |
| **3. Try one in place** | Each entry has **one** working micro-interaction (the accordion today; the existing city wall for climate) that works without leaving the page | The micro-interaction is the real block rendered in a reduced frame, not a mock. Reuse of the same renderer is the point: it proves the platform. |
| **4. What this is** | Two or three sentences and one link | Not a feature grid. |
| **5. Closing line + one action** | Single call to action | As today |
| **Footer** | As today | |

Explicitly **not** on the homepage: pricing, logo walls, testimonials, feature grids, newsletter capture, email sign-up, "How it works in 3 steps", stock imagery, auto-playing anything. These are SaaS-landing conventions and the opposite of the claim being made.

### 2.4 The first-fold test

At 375 × 740 and 1280 × 800, with JavaScript on, a reviewer must be able to answer yes to all of:

1. Can I read the headline and the promise?
2. Can I see something I can touch or drag, and is it obvious what it does?
3. Can I see that there is more than one experience below?
4. Is anything essential clipped mid-sentence?

With JavaScript off, the homepage still states what InScapio is and links to each experience (the `@media (scripting: none)` baseline).

### 2.5 States and edge cases the homepage must handle

- **One experience, two, then many.** The layout must read sensibly with one entry (during early publishing) and degrade to a simple list at many, without a carousel (design principles: no carousels as primary navigation).
- **Unpublished or flagged experience.** Not shown; no empty placeholder. (Q-16 applies to Whose Body Is It? today.)
- **Reduced motion.** The Read↔Explore wipe becomes a direct toggle; no information is removed.
- **Slow device.** First fold must render from server HTML; the interaction enhances it.

### 2.6 Success measures

Qualitative first (Section 7 of the review): in a first-impression session, a visitor can say what InScapio is and tries the interaction without prompting. Quantitative later (Stage 5 analytics): share of home visits that start an experience; share that interact in place. No target is set until a baseline exists.

## 3. Reader-experience architecture

### 3.1 The principle

An experience has **a shell the reader can predict** and **a body the subject shapes**. The reader should never have to relearn how to navigate, change text size, open "Deeper" or leave; they should *always* expect the content to differ in kind, because ideas differ in kind.

### 3.2 Standardised across every experience (platform, not publisher choice)

| Element | Spec | Why standard | Today |
|---|---|---|---|
| **Entry hero** | Title, one-sentence promise, primary action ("Begin" or equivalent), and a **size line** (parts and an estimated time) | Orientation and commitment (F1) | Hero and action exist; no size line |
| **Reading controls** | Deeper, text size, theme, in one consistent place; **persist** per reader | Reader control (F4) | Exist; do not persist |
| **Outline / progress** | A reachable list of the experience's sections with the current one marked; progress shown as position in the list, not only a thin line | Long pieces must be navigable (F3) | Thin line only |
| **Section frame** | Each section has a title, a one-line purpose where the author gives one, and the accent territory | Consistent rhythm | Exists |
| **Evidence at the point of use** | Source and data-note affordance attached to the claim or chart; footer list remains | Trust (F7) | Footer only (data note is block-level for climate) |
| **Deeper behaviour** | Same toggle, same dashed "going deeper" treatment, same rule: nothing essential only in Deeper | Predictability | Exists |
| **End state** | Always present: what this covered (2–4 lines authored), one next action (next experience if one exists, otherwise share), then feedback | Continuation (F2) | **Missing** |
| **Share** | Native share or copy link; a per-experience preview image and title (needs server metadata work, Stage 3+) | Growth path | Share exists; no per-experience image |
| **Feedback** | Optional, after the end state, never before | Not an interruption | Exists, local-only (Q-17) |
| **Accessibility contract** | Landmarks, heading order, skip link, focus on entry, live-region results, data-table alternative for charts, reduced-motion equivalents | WCAG 2.2 AA (D-017) | Partly; see review Section 8 |

### 3.3 Varies by subject (chosen by the author within a closed set)

| Dimension | What the author chooses | Mechanism |
|---|---|---|
| **Blocks and their order** | Which of the 15 blocks, and their sequence | Content (schema) |
| **Theme and section accents** | From the closed list | Content selects names, never values (D-028/D-032) |
| **Data-bound theme** | Whether a block drives the page's visual state (climate warming) | Block behaviour parameter |
| **Presentation variant of a block** | E.g. claims as one-at-a-time or as a collapsible list; cards as a grid or a column | **Needs decision**: presentation options are a closed per-block list (D-004), so variants are additive but are design-system surface area |
| **Hero treatment** | Type-led (both today); a data or chart-led hero in future | **Needs decision**; only if a real experience requires it |
| **Pacing** | How densely interactive blocks alternate with prose | Authoring guidance (Section 3.5), not enforced by the system |

### 3.4 Test cases

**Climate.** Subject shape: one relationship over time, one instrument. Shell effects: size line "1 interactive, about 3 minutes" (an estimate to be measured); outline of three sections; the data note appears *at* the chart as well as below; end state names what the reader saw (their city's analogue in 2070) and offers one other city or experience. Subject-specific: the chart, the prediction, the data-bound warm theme. **Proposal for the body**: place the chart before the three framing questions or immediately after a single sentence of framing, so interaction starts at the first scroll; keep the three questions as Deeper context. This is content ordering, no schema change.

**Whose Body Is It?** Subject shape: a layered, contested, sensitive argument, mostly prose with distinction-teaching interactions. Shell effects: size line "12 parts, about N minutes"; **outline is essential**; Deeper is core; end state links the helpline and a next step; sensitive-content handling (a visible, early route to the helpline and a way to skip a section) is an author-declared property to be specified with the safeguarding reviewer (Q-16 first). Subject-specific: accordion of layers, steppers, classify, claims, compare table, selector. **Proposal for the body**: the claims block gets a collapsible one-at-a-time variant (F6); consider one more interactive moment in the long run of chapters 3–5 so prose does not run unbroken (authoring/content decision).

What the two cases prove: nearly everything that failed review (F1–F4, F7) is **shell**, and is shared; nearly everything that makes each piece distinctive is **body**, and is not.

### 3.5 Authoring guidance this implies (for Stage 4 prompts and Stage 5 editors)

- Interaction must pass the five-part test; "no interaction" is a valid output for a section.
- A long section run (an indicative rule: more than a handful of paragraphs or cards in a row) should be broken by a different block type, a callout, or a Deeper container. The threshold is a judgment to calibrate, not a rule.
- Every claim of fact carries a source reference, or is marked as the publisher's own view.
- Every experience states what it does *not* show (a "what this cannot tell you" line), as the climate data note does.

### 3.6 What the shell needs from the platform (summary of build implications)

- Persisted reading preferences (cookie or equivalent read on the server; interacts with Q-19/Q-22).
- A section outline derived from the document (no schema change if sections already have titles; optional per-section one-line purpose is **needs decision**).
- A size line (needs an estimate source; could be derived from word count and block counts, labelled an estimate).
- An end-state template (needs a small optional schema addition for the authored summary lines: **needs decision**; a document-level `closing` or reuse of existing blocks).
- Source/data-note placement at the point of use (renderer composition of existing `sourceRef`/`data-note`; may need a presentation option).

## 4. Publisher workspace (IA and flows only)

> Everything here is **Planned/Future** (Stage 4 onward). No UI, component or library choice is made. It is written so the Supabase and renderer decisions in Stage 3 do not foreclose it.

### 4.1 Principles

1. **A conversation and a preview, not a form** (publisher-journey).
2. **The renderer is the preview.** There is one rendering path (D-004, publisher-journey implication 4).
3. **Every AI change is a visible, scoped, reversible proposal.** Nothing is applied silently.
4. **Only a human publishes**, enforced by the data layer (D-018).
5. **State is durable**; any session can be resumed.

### 4.2 Information architecture

```
Workspace
├─ Home (my experiences: drafts, in review, published; "Start something")
├─ Experience
│  ├─ Interview            conversation + material (paste, upload, links)
│  ├─ Knowledge            running summary: claims, examples, data, sources, each with where it came from
│  ├─ Outline              sections; what is surface vs deeper; AI-proposed interactions with reasons
│  ├─ Draft                structured editor (blocks) beside live preview (phone/desktop)
│  ├─ Review               AI QA findings (advisory), sensitive-content flags, source gaps, accessibility checks
│  ├─ Publish              metadata (title, slug, share image, topics), approval, publish / unpublish
│  ├─ History              revisions, diffs, restore
│  └─ Insights             aggregate reader signals (Stage 5)
└─ Account                profile, settings (invite-only access)
```

Navigation is by stage but not linear: any stage can send the publisher back to another (e.g. Draft → Interview: "I forgot an example"). Each stage shows its status (not started, in progress, needs attention) so a returning publisher sees where they are.

### 4.3 Core user flows

**Flow A: First experience from a conversation.**
Home → Start → say what you want to make → conversation → confirm running summary → review outline (accept/reject each proposed interaction, each with its stated reason) → draft appears in editor with preview → edit → Review → resolve findings → Publish (explicit approval screen listing what is going live and what is still flagged) → published URL.

**Flow B: Start from material.** Home → Start → upload or paste a document, notes or data → AI proposes a knowledge summary → publisher corrects → rejoins Flow A at Outline. (Q-03: both entry paths feed one knowledge step.)

**Flow C: Edit one block.** Draft → select a block → edit text directly, or ask for a scoped change ("shorter", "add the counter-argument") → see a diff of that block only → accept or discard. Never a whole-document rewrite.

**Flow D: Handle a finding.** Review → open a finding → jump to the block → fix, dismiss with a reason, or ask for a proposal → finding resolves or stays visible. Advisory only; dismissing is allowed and recorded.

**Flow E: Publish and revise.** Publish → approval of an immutable revision → live. Later: edit creates a new draft revision; live version is unchanged until a new approval. Unpublish is always available.

**Flow F: Come back later.** Home shows each experience's stage and the next suggested action; the interview and draft resume exactly where they were.

### 4.4 Signals the workspace must surface (before publish)

Illustrative or unsourced data; claims with no source or marked as opinion; AI-originated text proportion per revision (Q-08); sensitive-content categories (real identifiable people, minors, open legal matters; Q-07); accessibility gaps (missing alt text, chart without table); blocks the publisher has not seen.

### 4.5 What the workspace is **not**

Not a page builder (no free canvas, no drag-anywhere layout), not a code editor, not an "AI writes everything" button, and not multi-user in the MVP (the model must not preclude it; Q-04).

### 4.6 Open design questions for this surface

- Does the conversation live beside the draft permanently, or only in the Interview stage?
- How are AI proposals shown for a block that the publisher has already edited by hand?
- What does a publisher see when AI QA contradicts a claim the publisher insists on?
- How much of the workspace must work on a phone? (Publishers are likely at a desk; readers are on phones. Decide before design, not after.)

## 5. Acceptance criteria for this specification

The specification is adequate for Stage 2 when: the first-fold test (2.4) can be applied to a mock by someone who did not write it; every standardised shell element in 3.2 has an owner decision on whether it ships in Stage 2; each **needs decision** item is recorded in `OPEN-QUESTIONS.md`; and the publisher IA has been read by at least one real prospective publisher (Q-02/Q-03) before any publisher UI is designed in detail.
