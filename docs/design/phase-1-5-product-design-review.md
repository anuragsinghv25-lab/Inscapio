# Phase 1.5 · Product design review

> **Status:** Phase 1.5 · Proposed, pending owner review. Documentation only: no application code, dependency, deployment or Supabase change accompanies this document.
> **Companions:** [`phase-1-5-experience-specification.md`](./phase-1-5-experience-specification.md) (what to design), [`ui-library-evaluation.md`](./ui-library-evaluation.md) (what to build it with), [`../architecture/phase-2-readiness.md`](../architecture/phase-2-readiness.md) (in what order).

## 1. Purpose, method and limits

Phase 1 proved that both prototype experiences can be expressed as validated data and rendered by a small Next.js app. Phase 1.5 asks a different question: **is what we rebuilt the right thing to build on?** This review judges the running application against the product vision, and defines how later design work will be judged.

**What was done (this session).**

- Read the repository: `docs/` (vision, users, MVP scope, reader and publisher journeys, design principles and direction, audit, architecture, `DECISIONS.md` D-001..D-037, `OPEN-QUESTIONS.md` Q-01..Q-23), the renderer, design system, content files and tests.
- Built and ran the app locally from a clean clone of `main` at `71d3aa0` (`pnpm build`, `pnpm start`); `pnpm test` (42 unit tests), `pnpm lint` and `pnpm typecheck` passed. `prototype/v0/index.html` still hashes to `d7c21eac…6061fa`.
- Rendered all four routes in headless Chromium at 375 × 740 and 1280 × 800; reviewed screenshots (fold and full page); counted headings, landmarks, controls and transferred bytes.
- Verified UI-library facts from npm registry metadata and the vendors' own pages (see the library evaluation).

**What was not done, and so is not claimed.**

- No human reader or publisher was observed. Everything about *comprehension* and *engagement* below is expert review and reasoning, not evidence of reader behaviour. Section 7 says how to get that evidence.
- The Playwright suites (`pnpm test:e2e`) were not re-run in this session; only the unit tests, build, lint and typecheck were.
- No screen reader, Safari, Firefox, throttled network or real phone was used. Bytes below are **decoded** bytes from a local production server, not compressed transfer sizes, and were not measured on a device.
- I did not play through every interaction by hand; interaction behaviour is taken from the code, the existing tests and the screenshots.

## 2. Measured facts about the current application

| Route | Words | Page height at 375 px | Buttons | Links | JS decoded | Total decoded |
|---|---|---|---|---|---|---|
| `/` | 267 | 3,545 px | 18 | 8 | 487 KB | 756 KB |
| `/about` | 105 | 1,275 px | 1 | 5 | 487 KB | 745 KB |
| `/experiences/whose-body-is-it` | 2,168 | 21,038 px | 68 | 4 | 505 KB | 962 KB |
| `/experiences/climate` | 359 | 5,071 px | 42 | 3 | 505 KB | 937 KB |

- No horizontal overflow at 375 or 1280 px on any route (`scrollWidth` equals viewport width).
- Block mix. *Whose Body Is It?*: 12 sections, 30 paragraphs, 29 cards, 7 callouts, 7 deeper containers, 2 steppers, and one each of accordion, classify, compare-table, claims, selector-content, resource-box, source-list. *Climate*: 3 sections, 5 paragraphs, 1 fact-row, 2 deeper containers, **one** scrubber chart, one data note.
- Whose Body at 375 px is about 28 phone screens tall. The "What people say on X" block alone renders as a long run of near-identical bordered cards (screenshot reviewed).
- The unminified decoded JS is almost the same on the About page as on an experience, so the framework dominates; interaction code is not the main cost. The ~150 KB climate dataset ships with the climate page (Q-18). These figures are a starting point, not a budget.
- `/about` has 1 button and 5 links; `/experiences/*` pages use `HEADER`, `MAIN`, `NAV`, `FOOTER` landmarks; Whose Body has a single `h1` and 13 `h2`s (12 content sections plus the feedback heading), with `h3`s inside blocks. Heading structure is sound.

## 3. The question: what makes an InScapio experience understandable, engaging and different?

Stated without adjectives, as testable properties. An experience is **different from a conventional article** when all of the following are true, and an article-shaped page cannot satisfy them:

1. **The reader acts before being told.** At least one moment asks the reader to commit to something (a guess, a choice, a classification) *before* the answer appears, and the answer then depends on what they chose. (Climate: pick a city, predict which city it will resemble, then drag time. Whose Body: classify advice as "safety" or "blame".)
2. **The reader sets the depth.** The default path is complete and short; more evidence and harder questions are reachable on request, reversibly, and nothing essential hides behind that request.
3. **Something on the page responds to the reader.** A number, a chart, an ordering or a piece of text changes as a direct result of an input, within the time a reader perceives as immediate.
4. **Structure is visible before it is read.** The reader can tell, without scrolling the whole thing, how many parts there are, where they are, and what kind of work each part asks of them.
5. **Evidence is attached to what it supports.** Sources and data caveats appear at the claim or chart, not only in a footer.
6. **It still reads as text if the interaction is removed** (no JavaScript, keyboard only, screen reader). This is what keeps interaction honest rather than decorative.

An experience is **immediately understandable** when a first-time visitor, within the first screen and without instruction, can say (a) what the subject is, (b) what they will do, and (c) roughly how long it takes. It is **engaging** when readers use the interactive moments voluntarily and finish more often than they would an equivalent article. (b) and (c) are what the product currently under-delivers (Section 5).

## 4. Reader and publisher needs

### Readers (hypotheses from `product/users.md`, sharpened by what the app shows)

| Need | Why | Where the app stands |
|---|---|---|
| Know the subject and the promise on the first screen | The dominant arrival path is a shared link on a phone (reader-journey A) | Experience heroes do this well (both state subject and first action). Home does it only in part. |
| Know the size of the commitment | A 28-screen page read on a phone is a decision | No time estimate, no chapter count, no outline anywhere |
| Move around a long piece | Whose Body has 12 sections | Only a progress line and two hero buttons; no table of contents, no section navigation |
| Control reading comfort | Mid-range Android, varied eyesight | Deeper, A+/A−, light/dark exist; **none persist** (Q-19) |
| Trust what is said | Sensitive subject matter, illustrative data | Strong: data notes are schema-enforced (D-025); sources are footer-only |
| Know when they are done and what next | Shared-link readers rarely return | **No end state**: the page just ends in a feedback form; no "next experience" |
| Be able to share meaningfully | Link sharing is the main growth path | Share exists; no per-experience share image (reader-journey gap) |

### Publishers (hypotheses; no publisher has been observed — Q-02, Q-03)

| Need | Design consequence |
|---|---|
| Get from what they know to a draft they can judge, fast | The first screen after "create" must be a conversation or an upload, not a form |
| See exactly what readers will see | Preview must be the production renderer (already a Phase 1 property) |
| Stay the author | Every AI change is visible, scoped and reversible; provenance is shown per block |
| Know why a block was chosen | The system proposes an interaction *with a stated reason* (the interaction test) and the publisher can decline it |
| Fix things without a page-builder | Structured editing at block level; no free canvas |
| Know whether it worked | Few, honest signals (completion, interaction use, deeper use), not page views |
| Be safe from their own mistakes | Illustrative-data disclosure, source gaps and sensitive-content flags are surfaced *before* publishing |

## 5. Evaluation of the two experiences

Each assessed against the Section 3 properties. "Retain / improve / redesign / remove" is a recommendation for Stage 2 design work, not a change made here.

### 5.1 *What will your city feel like in 2070?* (climate)

**What works.**

- The first screen is a promise and one button; the prompt "Pick a city, drag time forward, and see which place it starts to resemble" tells the reader what they will do.
- The predict-then-reveal moment ("Before you drag: which city's climate will London come closest to by 2070?") is the product's strongest pattern and passes properties 1 and 3.
- The warming background tied to the data (`--warm`) carries meaning rather than decoration.
- Honesty is structural: a data note is required by the schema when the data is illustrative.

**What aids understanding.** The three framing questions (how hot / how cold / how dry) before the chart give the reader a vocabulary for what the numbers mean; the chart then shows the year's shape against today's.

**What encourages exploration.** 20 cities and a continuous year control; the reader can try several. Nothing, however, *invites* a second city after the first.

**What still feels like ordinary web content.** After the chart, the closing section is a paragraph and a data note; then a feedback form of seven questions. The piece has **one** interactive block in about 5,000 px of page. The delta line under "warmest month" reads "(0.0)" at the starting year, which is correct but looks like a missing value to a first-time reader.

**Friction.**

- The page opens with three static text sections before the chart, so the reader must scroll past nearly four phone screens of framing text (the chart starts roughly 2,800 px down at 375 px) to reach the thing the hero promised.
- The prediction offers three options with no way to see why one is "closer"; the reveal explains the answer but the reasoning behind "closest" is not visible.
- No way to compare two cities, which is the obvious next question.
- The climate data is a demo model (invented warming rule). The note says so; the headline "what will your city feel like in 2070?" is stronger than the evidence. This is an honesty tension to resolve in copy, not code.

**Recommendation.** *Retain* the hero, the predict-then-reveal and the data-bound background. *Improve* by moving the chart up so interaction starts at the first scroll, adding an end state that states what the reader learned and offers a next city, and softening the headline or promoting the "illustrative" status next to the chart rather than below. *Do not* add a comparison feature in Stage 2 (it needs a schema change; propose only). *Remove* nothing.

### 5.2 *Whose Body Is It?*

**What works.** Strong typographic hero with the subject stated plainly; a clear "Read it simply, tap Deeper" instruction; coloured chapter accents create territory and rhythm; the classify quiz and the claims block ("They say… Tap for a fair answer") are real interactions that teach a distinction.

**What aids understanding.** Surface/deeper separation works for long prose; the compare-table ("what can be true / what does not follow") is exactly the structure the vision calls for.

**What encourages exploration.** The "Six layers behind one harm" accordion and the steppers invite opening one thing at a time.

**What still feels like ordinary web content.** Most of the page is paragraphs, cards and callouts: 30 paragraphs and 29 cards against 6 interactive blocks. The claims block renders a long vertical list of structurally identical cards, which reads as a list, not an exploration. Two interactions per 10,000 px is closer to a long article with interludes than to the Section 3 definition.

**Friction.**

- Length without navigation: about 28 phone screens, 12 sections, no outline, no "jump to chapter".
- Reading preferences reset on each visit (Q-19).
- On a topic readers may find distressing, there is no pause or "skip this section" affordance, and the helpline box is near the end rather than reachable from the top (to be decided with the safeguarding reviewer; see Q-16).
- Content risk is not a design question but it gates everything: Q-16 (a real recent case involving minors, unreviewed) blocks any public promotion, and the design must not make that content *more* shareable until it is resolved.

**Recommendation.** *Retain* hero, classify, steppers, compare-table, the Deeper model. *Improve* the claims block (show one claim at a time with a filter, or collapse to a scannable list with the reader opening what interests them — a presentation variant of the same block, no schema change) and add chapter navigation. *Redesign* the page's pacing so interaction and prose alternate more evenly — this is an authoring/content decision as much as a design one. *Remove* nothing; **hold public promotion** until Q-16 is closed.

### 5.3 Summary across both

| Question | Climate | Whose Body |
|---|---|---|
| Understandable in the first screen | Yes | Yes |
| Size of commitment visible | No | No |
| Reader acts before being told | Yes (predict) | Yes (classify), weaker elsewhere |
| Evidence at the claim | Partly (data note, footer sources) | Footer sources only |
| Navigable | Short; n/a | **No** |
| End state | **None** | **None** |
| Preferences persist | No | No |

The shared gaps (size, navigation, end state, persistence, evidence placement) are platform concerns, not content concerns, which is why they belong in the reader-experience architecture (see the experience specification) rather than in each experience.

## 6. Measurable design principles

These restate `design-principles.md` as questions that can be answered with evidence. **No numeric target is set here without a stated basis.** Where a number is useful but no honest basis exists yet, the criterion says how the baseline will be measured and that the target is to be set from it. The existing proposed performance budgets in `design-principles.md` (LCP, INP, CLS) remain *proposed*; none has been measured on a device.

### P1 · Comprehension
- **Rule.** A reader leaves able to restate the central idea and to use the distinction the experience teaches.
- **Evaluate with.** Moderated sessions: show the experience, then ask (a) "what is this about?" before interaction, (b) a short recall/transfer question after. Compare against the same content as a plain article with a matched group. Heuristic basis for session size: small-n moderated studies surface most severe usability problems (a widely used rule of thumb), but they do **not** estimate comprehension rates; treat results as findings, not statistics.
- **Pass when.** Participants can state subject and action from the first screen without prompting, and post-test answers are not worse than for the article control. A comprehension *advantage* is a hypothesis (vision claim 3), not a launch requirement.

### P2 · Curiosity and discovery
- **Rule.** Each interactive moment gives the reader a reason to try one more thing.
- **Evaluate with.** Per-block counts of voluntary interactions beyond the first (e.g. cities tried, claims opened); observed hesitation points in sessions. Instrumentation is Stage 5 (analytics, D-022); before that, observe.
- **Pass when.** Each block passes the five-part interaction test in `design-principles.md` and every experience has an explicit "what next" after each interaction (even if only a prompt).

### P3 · Reader control
- **Rule.** The reader decides depth, pace, text size, theme and motion, and the choice sticks.
- **Evaluate with.** Checklist: Deeper, text size and theme persist across visits and across experiences; no autoplay or forced advance; every reveal is reversible.
- **Pass when.** All checklist items are true; today three of three persistent preferences fail (Q-19).

### P4 · Cognitive load
- **Rule.** At any moment one main thing is asked of the reader.
- **Evaluate with.** Per screen: count of competing calls to action and of simultaneously moving things; for long pages, whether an outline exists. Reviewer rubric, scored the same way every time.
- **Pass when.** No screen has two primary actions; a page longer than a few screens has visible structure. (The "few screens" threshold is a judgment to be calibrated in Stage 1, not a measurement.)

### P5 · Trust
- **Rule.** The reader can see what is known, from where, and what is illustrative.
- **Evaluate with.** Schema checks (already: illustrative data requires a data note); per-claim source coverage; sensitive-content review recorded before promotion.
- **Pass when.** Every claim block can show its source at the point of use; no experience is promoted without a recorded content review where Q-07/Q-16 apply.

### P6 · Accessibility and responsiveness (WCAG 2.2 AA)
- **Rule.** Everything works by keyboard, with assistive technology, in reduced motion, at 320 CSS px reflow and at 200 % text size.
- **Evaluate with.** axe in CI (exists, Chromium only); plus manual: VoiceOver (iOS/macOS), TalkBack, NVDA; Firefox and WebKit; zoom and reflow; forced colours. Automated tools find only a subset of issues, so a zero-violation axe run is necessary, not sufficient.
- **Pass when.** Per-block accessibility contracts are written and each is verified manually once per release (D-017). Today: axe passes in Chromium; manual AT coverage is zero (Q-20).

### P7 · Publisher usability
- **Rule.** A publisher can go from material to a reviewed draft without learning the schema, and never publishes by accident.
- **Evaluate with.** Task-based sessions with real or realistic publishers: time to first draft, number of AI proposals accepted/edited/rejected, errors caught before publish, and the publisher's own statement of whether the result is better than their article (vision claim 1).
- **Pass when.** Defined with the first publisher conversations; no target is proposed before one has been observed.

## 7. Evidence still to be gathered (cheap, before large design spend)

1. Five-ish moderated first-impression sessions on a phone with the **current** build (what is this, what would you do, how long do you think it takes). Directly tests the Section 5 findings.
2. A reading-order and tap-path walkthrough with a screen reader on both experiences.
3. One real-device load on mid-range Android over throttled mobile, to replace the decoded-bytes figures above with something budgetable.
4. Two or three conversations with candidate publishers about what they would bring (Q-02, Q-03).

## 8. Tests the design work will need

**Mobile.** 320, 375 and 430 px portrait; 200 % text; landscape; iOS Safari safe areas and dynamic viewport; touch-target size and spacing for every control; long-page behaviour (chapter navigation must not depend on hover or on precision scrolling); real-device scroll performance on the climate chart.

**Accessibility.** Per-block keyboard and screen-reader scripts (stepper, classify, claims, scrubber, accordion, selector); focus management on route entry and on "Deeper"; live-region announcements for results (classify, predict, scrubber outputs); chart data-table alternative parity; reduced motion and forced colours; contrast for every theme × accent × mode (partly automated already); and for any new navigation (outline, skip links) a landmark and focus-order check.

## 9. Findings, ranked

| # | Finding | Evidence | Kind | Needs |
|---|---|---|---|---|
| F1 | Experiences do not state their size or structure | Screens; no outline; 28-screen Whose Body | Platform | Design (Stage 1), small build (Stage 2) |
| F2 | No end state or next step | Both pages end in the feedback form | Platform | Design, build |
| F3 | Long experiences are not navigable | 12 sections, no outline | Platform | Design, build |
| F4 | Reading preferences do not persist | Q-19 | Platform | Decision, build |
| F5 | Interaction density is low in Whose Body and the chart sits late in Climate | Block counts; screenshot | Content + presentation | Authoring guidance; presentation variants |
| F6 | Claims block is a long identical-card list | Screenshot | Block presentation | Design variant, no schema change |
| F7 | Evidence is footer-only for Whose Body | Content | Schema (optional per-claim `sourceRef` exists in rich text) | Authoring + design |
| F8 | Home first-fold at 1280 px does not demonstrate interaction (the Read/Explore panel is a narrow sliver beside text) | Screenshot at 1280 | Home | Design (see specification) |
| F9 | No per-experience share preview | Reader-journey gap | Platform | Stage 3+ |
| F10 | Feedback goes nowhere | Q-17 | Backend | Stage 3 |
| F11 | Whose Body content unreviewed (real case, minors) | Q-16 | Content/safeguarding | Owner decision; gates promotion |
| F12 | Assistive-technology and browser coverage minimal | Q-20 | Quality | Test plan above |

F1–F4 and F8 are the highest value-for-cost: they affect every experience, need no new block type and no backend.

## 10. Consistency with existing decisions

Nothing here contradicts D-001..D-037. Two intentional tensions are flagged rather than resolved: (a) the five-part reader architecture in the specification proposes presentation variants and an outline, which sit inside D-004 (presentation is a closed set) but add to the design-system surface; (b) preference persistence (F4) interacts with Q-22 (CSP) and Q-19. Proposed decision records and new open questions are listed in `../architecture/phase-2-readiness.md` and appended to `DECISIONS.md` / `OPEN-QUESTIONS.md` as **Proposed** only.
