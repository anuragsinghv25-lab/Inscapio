# Phase 2 readiness: staged roadmap, dependencies and Supabase decisions

> **Status:** Phase 1.5 · Proposed, pending owner review. Documentation only. **No Supabase connection, table, auth setting, dependency, environment variable, secret or deployment configuration is created or changed by this document or its PR.** A Supabase project is reported to exist; it was not accessed, inspected or connected from this session.
> **Supersedes nothing.** It refines the phasing in [`../product/mvp-scope.md`](../product/mvp-scope.md) after Phase 1; see Section 1.

## 1. How these stages relate to the earlier phases

`mvp-scope.md` proposed Phases 0–5. Phase 0 (foundation) and Phase 1 (schema + renderer) are done. The owner's Phase 1.5 brief frames the next work as five **stages**. Mapping, so the two vocabularies do not drift:

| Stage (this document) | Corresponds to | Summary |
|---|---|---|
| 1 · Design decisions | New (Phase 1.5) | Settle what the experience and workspace should be |
| 2 · Visible design evolution | New (between 1 and 2) | Change what readers see, without a backend |
| 3 · Backend foundation | Old Phase 2 (platform) | Database, auth, publish pipeline, stored feedback |
| 4 · AI authoring | Old Phase 3 | Interview, structuring, structured editing |
| 5 · Closed alpha | Old Phase 4 | QA, approval, revisions, analytics, first outside publishers |
| (later) | Old Phase 5 | Reader-side growth: follow, email |

Proposed as D-039. The old numbering is kept in `mvp-scope.md`; this table is the bridge.

## 2. Staged roadmap

Each stage has an objective, what it contains, what it must **not** contain, dependencies, decisions required, and an exit test. Effort and dates are deliberately absent: team size, timeline and AI budget are unanswered (Q-15).

### Stage 1 · Design decisions (this PR and the owner's review)

- **Objective:** agree what an InScapio experience and homepage are, what is standard versus subject-specific, which UI approach to take, and the order of work.
- **Contains:** the four Phase 1.5 documents; owner answers to the questions in Section 6; first-impression sessions on the current build (cheap; see the review, Section 7).
- **Does not contain:** code, dependencies, Supabase, deployment.
- **Depends on:** owner review. Optionally on one or two conversations with candidate publishers (Q-02, Q-03).
- **Decisions needed:** D-038 (reader shell elements), D-039 (stage mapping), D-040 (UI-library direction), plus Q-24..Q-30 below.
- **Exit test:** the owner can say, for each shell element in the experience specification (3.2), "in Stage 2" or "later", and for each open question "answered" or "deferred, by when".

### Stage 2 · Visible design evolution (no backend)

- **Objective:** make the reader experience visibly better on the review's highest-value findings, using the existing content and renderer.
- **Candidate contents (all front-end, no new service):** persisted reading preferences; section outline and size line; end state; homepage first-fold rework; presentation variants for the claims block; point-of-use evidence; a reordered climate body; fixes to the clipped home strip. Each is optional and decided in Stage 1.
- **Does not contain:** accounts, database, AI, analytics, new third-party services, a UI library.
- **Depends on:** Stage 1 decisions. Preference persistence depends on the Q-19/Q-22 approach (cookie read on the server vs client storage; CSP).
- **Decisions needed:** which schema additions are acceptable (end-state summary lines, optional per-section purpose line), because CLAUDE.md requires schema/block changes to be proposed first; whether Whose Body stays unpromoted until Q-16 closes (recommended).
- **Exit test:** the first-fold test (specification 2.4) passes at 375 and 1280 px; first-impression sessions on the new build show visitors can say what each experience is and how long it is; the Playwright, axe and parity suites still pass; no change to `prototype/v0`.

### Stage 3 · Backend foundation

- **Objective:** a hand-authored experience can be stored, previewed and published end to end by an authenticated person, and reader feedback is stored.
- **Contains:** Supabase project wiring (after Section 5 decisions), schema migrations as plain SQL, row-level security on every table with tests, invite-only publisher auth, content stored as versioned JSON documents validated by the existing Zod schema (D-005), draft/revision/publication separation, repository layer, preview using the same renderer, stored feedback (Q-17), per-experience share metadata, environments (local, preview, production; D-012).
- **Does not contain:** any AI call, the interview, the studio editor, analytics dashboards, reader accounts, payments.
- **Depends on:** Stage 1 (what is stored), Section 5 decisions, a legal/privacy position for stored feedback (India's DPDP Act is already flagged in `backend-architecture.md`; counsel needed, not decided here), and the **separate** production deployment decision (Q-23; the current `inscapio.in` state is untouched by this work).
- **Exit test:** an experience document is created through a server action, validated, stored, previewed and published by a human session; RLS tests prove an unauthenticated or other-publisher session cannot read drafts or publish; the AI-credential-cannot-approve test (D-018) exists even though no AI exists yet.

### Stage 4 · AI authoring

- **Objective:** a publisher goes from conversation or material to a schema-valid draft they can review.
- **Contains:** the provider interface (D-011), interview and structuring prompts, knowledge items with provenance, outline, block proposals with stated reasons, scoped block edits as diffs, evaluation sets, cost/latency budgets, the workspace IA and flows in the specification (Section 4) designed in detail.
- **Does not contain:** auto-publish, arbitrary HTML or code from AI, multi-user collaboration, reader accounts.
- **Depends on:** Stage 3 (durable state, auth, separate AI credential), the UI-library spike (`../design/ui-library-evaluation.md`, Section 5), answers to Q-03, Q-08, Q-09, and an AI budget (Q-15).
- **Exit test:** internal "publishers" produce experiences judged against their own articles; AI output always validates against the schema; no AI path can set an approved or published state.

### Stage 5 · Closed alpha

- **Objective:** invite a small number of outside publishers and test the vision's claims with them.
- **Contains:** AI QA report, human approval flow (D-018), revisions and restore, first-party aggregate analytics (D-022), content policy, publisher agreement, takedown process, export (Q-14), manual assistive-technology and cross-browser coverage (Q-20).
- **Depends on:** Stage 4; legal groundwork for Q-06 and Q-07; a named content reviewer.
- **Exit test:** the MVP exit criteria in `mvp-scope.md`.

### Dependency summary

```
Stage 1 ─► Stage 2 ─┐
   │                ├─► (Stage 2 is independent of the backend; it can run beside Stage 3 planning)
   └──────► Stage 3 ─► Stage 4 ─► Stage 5
              ▲
   Supabase decisions (Section 5) and the separate deployment decision (Q-23)
```

Stage 2 and Stage 3 are not strictly sequential: Stage 2 needs no backend, and Stage 3 does not need the Stage 2 visuals. Doing Stage 2 first produces visible evidence and the first-impression findings that shape what Stage 3 must store; doing Stage 3 first gets the long-lead legal and infrastructure items moving. **Recommendation:** run Stage 1, then Stage 2 on a small scope, and start the Stage 3 legal/privacy and Supabase decisions in parallel because they have the longest lead time.

## 3. Readiness assessment today

| Area | State | Evidence |
|---|---|---|
| Schema and renderer | Ready as a foundation | D-023..D-033; 42 unit tests pass; both experiences render |
| Content storage format | Ready | Documents are plain JSON validated by Zod; export-friendly |
| Design system | Adequate for the reader; no workspace primitives | Tokens, 2 primitives; no gallery or visual regression |
| Accessibility assurance | Partial | axe in Chromium only; no manual AT (Q-20) |
| Performance evidence | Weak | Decoded local bytes only; no device measurement (Q-18) |
| Content/safeguarding | **Blocked for one experience** | Q-16 |
| Feedback pipeline | Missing | Q-17 |
| Auth, DB, publish pipeline, AI | Not started | By design |
| Deployment | Separate and unresolved | Q-23 |

Verified by a clean clone, build, 42 unit tests, lint and typecheck in this session; the Playwright suites were not re-run.

## 4. Principles for Stage 3 (inherited, not new)

Content stays versioned JSON validated by one Zod schema (D-005); human approval is an enforced data-layer state (D-018); RLS on every table with tests (D-010); a repository layer so Supabase is replaceable (D-010); drafts, revisions and publications are separate things; no secret enters the repository, ever; preview and production use the same renderer.

## 5. Supabase decisions Stage 3 must resolve

None of these is decided here. None requires touching the existing Supabase project today. Each has a leaning where one is defensible; the rest need the owner.

| # | Decision | Why it matters | Leaning / note |
|---|---|---|---|
| S1 | **Ownership and access** of the existing project: which account/organisation owns it, who has admin, whether it is the free tier | Billing, recovery, continuity | Record owner and a second admin before storing real data |
| S2 | **Region and data residency** | Latency for an India-first audience; DPDP obligations for any stored personal data | Choose before data is stored; changing region later means migration. Needs the owner and privacy advice |
| S3 | **One project or several** (production vs staging/preview) | D-012 says preview shares a staging database; a single project mixing preview and production data is risky | At least separate production from non-production; decide whether previews share staging |
| S4 | **Auth method** for invite-only publishers: magic link, OAuth, passwords, or a mix; how invitation is enforced | Public sign-up must be impossible (D-008) | Prefer passwordless; disable open sign-up; test that disabled sign-up holds |
| S5 | **Roles and the AI credential** | D-018: AI must not be able to approve or publish | Separate credentials/roles; test it |
| S6 | **Schema shape**: documents-per-revision table, publications, approvals, feedback, knowledge items, analytics counters | D-005 | Plain SQL migrations in the repo; JSON document column for content, relational columns for ownership and state |
| S7 | **RLS policy design and test method** | The classic Supabase failure mode | RLS on every table; automated tests with real roles |
| S8 | **Migrations workflow**: how SQL migrations are run and reviewed; who can apply to production | Reproducibility, rollback | Migrations in repo, applied by a controlled step, never by hand in the dashboard |
| S9 | **Storage**: what is stored (share images, uploads), buckets, size and type limits, public vs signed access | Uploaded material is an attack and privacy surface | Decide at Stage 4; minimal at Stage 3 |
| S10 | **Keys and secrets**: where the anon key, service-role key and database URL live; who can read them | A leaked service-role key bypasses RLS | Service role on the server only, never in client bundles; secrets in the hosting provider's secret store; none in the repo, none in docs |
| S11 | **Environment and deployment wiring** | Production deployment is explicitly separate (Q-23) | Not touched until the owner asks; Supabase and deployment are decided together |
| S12 | **Backups, point-in-time recovery, pausing/limits** of the chosen plan | Free tiers can pause and have limits; this is real user content | Confirm plan limits before depending on it |
| S13 | **Feedback storage and privacy** | Q-17; free text may contain personal data | Aggregate answers first; minimise free text; privacy statement; retention rule |
| S14 | **Analytics counters** | D-022: first-party, aggregate | Stage 5; design counters so no personal identifier is needed |
| S15 | **Extensibility for organisations and members** | Q-04 | Ownership column and membership table shape that does not preclude teams |
| S16 | **Vendor exit** | D-010 | Standard Postgres, SQL migrations, repository layer; keep Supabase-specific features (Auth, Storage) behind interfaces |

**Not done, and not to be done before the owner decides:** connecting the app to any Supabase project, adding the Supabase client library or any other dependency, creating tables, enabling or configuring auth, setting environment variables or secrets, or editing deployment configuration.

## 6. Questions the owner needs to answer

New questions raised by Phase 1.5 (appended to `OPEN-QUESTIONS.md` as Q-24..Q-30):

- **Q-24** Which shell elements ship in Stage 2 (outline, size line, end state, persistence, point-of-use evidence)?
- **Q-25** Is a small schema addition acceptable for authored end-state lines and optional per-section purpose lines, or should these reuse existing blocks?
- **Q-26** Should presentation variants of a block (for example claims one-at-a-time) be added, and who approves new variants?
- **Q-27** Is the publisher workspace expected to work on a phone, or desktop first?
- **Q-28** Should "Whose Body Is It?" remain unpromoted (and un-featured on the homepage) until Q-16 is closed? The homepage specification assumes it can be omitted when flagged.
- **Q-29** Do we run first-impression sessions on the current build before Stage 2 design, and with whom?
- **Q-30** What is the Supabase ownership, region and plan (S1, S2, S12), and when does legal/privacy advice start?

## 7. Risks to the roadmap

- **Stage 2 expanding into a redesign.** Mitigation: Stage 1 lists each shell element explicitly; anything not listed waits.
- **Schema additions creeping in** (end state, section purpose). Mitigation: each is a proposal with a decision record, per CLAUDE.md.
- **Stage 3 started before the privacy and region decisions.** Data stored in the wrong place is expensive to move.
- **Q-16 left open** while the homepage features the sensitive experience.
- **The UI-library choice made implicitly** by whoever builds the first workspace form. Mitigation: D-040 and the spike.
- **No real publisher input** until Stage 4. Mitigation: two or three conversations during Stage 1/2 (Q-02, Q-03).
