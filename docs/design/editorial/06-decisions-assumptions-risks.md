# 06 · Unresolved decisions, assumptions, risks, dependencies, and what not to build yet

**Status:** Proposed. New questions are numbered Q-45 to Q-54 and are mirrored in `docs/OPEN-QUESTIONS.md`; the matching proposed decision is D-062 in `docs/DECISIONS.md`. Existing decisions are cited, not changed.

## 1. Unresolved decisions with recommended defaults

| ID | Question | Why it matters | Recommended default | Needed by |
|---|---|---|---|---|
| **Q-45** | The positioning says "timeless understanding rather than timely reporting" (`docs/product/positioning.md`). A daily edition is timely. Which wins? | Public promise, home page, legal framing | Keep the promise, add an **Edition** layer: timely stories that each point to a timeless explainer; update `positioning.md` after approval | Before any Editorial work |
| **Q-46** | Headline rail: manual or auto-scroll? The Phase 1.5 spec says "auto-playing anything" is not allowed and `design-principles.md` says "Reader owns the pace" | Accessibility, identity | **Manual rail**; if auto-scroll is wanted, amend the spec and ship the pause/hover/focus/reduced-motion safeguards | Before 4.1 |
| **Q-47** | Does the public site show a "Sign in" link? | Readers must never feel gated; admin surface exposure | **No public link.** Studio at a direct address given to people; footer carries no sign-in | Before 3.3 UI |
| **Q-48** | Separate "approve" and "publish" steps, or one confirmation? | Workflow speed vs control for 5–10 stories/day | **One explicit confirmation** (checklist + checkbox) that the database records as approval and publish together; keep two steps available for future publishers | Before 4.2 |
| **Q-49** | Editorial and legal policy: corrections wording, AI-use disclosure, quotation limits for third-party reporting, defamation handling, applicable Indian rules for digital news publishers | Legal exposure of publishing news | Draft method/corrections/AI pages shown in the prototype; **counsel review before public launch**. Not legal advice | Before public pilot |
| **Q-50** | Topic taxonomy | IA clarity | Six topics: Conflict & security; Diplomacy & institutions; Trade & economy; Energy & resources; Technology & power; India & the world. Regions are a filter. Do **not** add a topic until it has ≥5 stories | Before 4.1 |
| **Q-51** | Edition model: a dated daily edition, or a rolling feed? Who sets the lead? | Layout, archive, empty states | **Dated daily edition** with a rolling archive; lead = the admin's "Set as lead" (new `featured_rank`); falls back to the newest story | Before 4.0 |
| **Q-52** | May a files-first pilot (stories as JSON in the repo, with redeploys) precede Stage 3.5? Does 3.7 apply to an **owner-only** public studio? | Timeline vs rule compliance | Allow a files-first reading pilot only for design validation; treat 3.7 as required before **outside** publishers, and require a lighter independent review of studio routes before the owner uses the studio publicly | Before 4.1 |
| **Q-53** | Per-story AI disclosure vs site-wide method note | Transparency vs clutter | Site-wide note + a one-line footer on each story ("Draft prepared with AI assistance; reviewed and published by the editor"); revisions already record `author_kind` | Before 4.1 |
| **Q-54** | Does *Whose Body Is It?* appear on the news front page? (links to existing Q-16 and Q-28) | Content safety | **No**: keep it held (`HELD_FROM_NEXT`) until Q-16 closes | Before 4.1 |

Existing open items that block this work (not duplicated): Q-33 (email provider/sender), Q-34 (administrator count and recovery), Q-38 (publisher MFA), Q-40 (invitation delivery), Q-41 (session window), Q-42 (takedown visibility lag), Q-44 (invitee Auth account).

## 2. Assumptions (each needs confirmation)

1. The owner is the only author for the pilot (one administrator, also holding a publisher record, because admin does not imply draft access, D-050).
2. Stories are produced externally with ChatGPT or Claude and imported as JSON that follows the published schema; no AI API in the app.
3. Stories are text, tables and simple charts; no photography, video or maps in the MVP.
4. Readers are anonymous; no reader analytics or cookies unless decided separately.
5. IST is the display timezone; stories show absolute dates.
6. English only.
7. Sources are linked, not copied; quotations are short.
8. The prototype's two stories are **invented**; real stories will be sourced and dated.
9. The public site continues on Next.js with server rendering; Vercel preview deployments are used for staging (D-059, Proposed).

## 3. Risks

| # | Risk | Likelihood / impact (judgement) | Mitigation |
|---|---|---|---|
| 1 | Publishing news carries legal exposure (defamation, copyright, rules for digital news publishers) | Medium / high | Q-49; method and corrections pages; counsel review; conservative sourcing and short quotes |
| 2 | AI errors reach readers | Medium / high | Human approval only; mandatory labels and sources; checklist; correction workflow |
| 3 | Daily load (5–10 stories) is too heavy for one person | High / medium | Prompt pack, fast validation, start at 2–3 per day, measure time per story |
| 4 | Sole administrator lock-out | Low–medium / high | D-058 runbook; recovery drill before public pilot; consider a second admin later |
| 5 | A daily news product contradicts the positioning | Medium / medium | Q-45 |
| 6 | The public cannot see new stories without a redeploy until 3.5 | Certain / high | Sequence 3.5 before the studio pilot; files-first only as a reading pilot |
| 7 | Schema v2 and a new kind need a migration | Certain / medium | Forward-only migration; owner approval; fixtures; keep existing rows valid |
| 8 | Auto-scroll hurts accessibility and conflicts with the spec | Medium / medium | Manual default (Q-46) |
| 9 | Corrections and tombstones are not currently public | Certain / medium | Public change log and tombstone fields in 4.0 |
| 10 | Mobile editing is error-prone | Medium / low | Desktop-only structured editing; phone is preview and typo fix |
| 11 | Invented demo content mistaken for real news | Low / high | "Illustrative" ribbon on every frame; never deploy prototype content to production |
| 12 | Scope creep into AI features and automation | High / medium | The "do not build yet" list below |

## 4. Dependencies

- Owner confirms a staging Supabase project (D-057) → 3.3.
- Email provider and sender domain (Q-33) → sign-in links.
- Approval of schema v2 and migration (03) → 4.0.
- Validator service code and identity (D-056) → import.
- 3.5 read path → no-redeploy publishing.
- Counsel input (Q-49) → public launch.
- Fonts: Bricolage Grotesque and Literata are already in the app; the prototype loads them from Google Fonts only for review.

## 5. Do not build yet

AI API integration or any AI call from the studio; automatic or scheduled publication; automated news ingestion or scraping; reader accounts, comments, newsletters, push alerts; search; analytics dashboards; media library; multi-admin and outside-publisher management; self-service password reset, social login, open registration; per-story translation; public API; monetisation. Also: **do not** present any prototype screen as live.

## 6. Conflicts found in the repository (for the owner)

1. `positioning.md` (timeless) vs a daily edition → Q-45.
2. Homepage spec and design principles vs a moving ticker → Q-46.
3. Stage 3 excludes the workspace editor → new stage proposed (05).
4. `scrubber-chart` is climate-specific → generic `chart` block (03).
5. DB `kind` CHECK and shape gate hard-code two kinds → migration (03).
6. Projection has one `published_at`, no update log, tombstone text or lead flag → migration (03).
7. Admin does not imply draft access (D-050) → the owner must also be a publisher to author; confirm in 3.3.
