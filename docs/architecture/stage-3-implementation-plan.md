# Stage 3 implementation plan

> **Status:** Stage 3 design · **Proposed**, except where §4.1 records an owner approval. Increment 3.1 (local-only identity core) is merged; 3.2 (local-only experience core) is implemented on its own branch and PR (§4.2); later increments have not started. No hosted Supabase resource was created or connected and the production domain and deployment were not touched.
> **Companions:** [`identity-and-access-control.md`](./identity-and-access-control.md), [`supabase-data-model.md`](./supabase-data-model.md), [`authentication-and-rls-test-plan.md`](./authentication-and-rls-test-plan.md). Labels (V-n, U-n, Rec D-nnn, Q-nn) are defined in the identity document §0. Roadmap position: Stage 3 of the five-stage roadmap in [`phase-2-readiness.md`](./phase-2-readiness.md); the publisher workspace UI is Stage 4.

## 1. Recommended starting point

**Start with increment 3.1: identity core in a local database only.** It needs no hosted Supabase project, no dependency in the Next.js app, no email provider and no change to the production domain. It produces the artefacts everything else depends on (migration tooling, the RLS test harness, the helper functions, the first four tables) and it forces the biggest unknowns to be answered cheaply: how claims are set in tests, whether custom roles work, whether the local Postgres version supports what the design assumes.

Prerequisite for 3.1 is only the owner's approval of the decisions in §4 and a machine or CI runner that can run the Supabase local stack (container runtime requirement **not verified** here [V-13 does not state it]).

## 2. Ordered increments

Each increment is a separate branch and PR, follows `development-workflow.md`, and updates docs and `DECISIONS.md` in the same PR. **No increment merges without its negative tests passing in CI** (test plan §1).

| # | Increment | Depends on | Delivers | Acceptance criteria | Security-review checkpoint |
|---|---|---|---|---|---|
| **3.0** | Decision and environment gate (no code) | this PR reviewed | Owner answers Q-30, Q-31, Q-32, Q-33, Q-34, Q-38, Q-40, Q-43; chooses new vs existing Supabase project; records region and plan with evidence | each answer recorded in `OPEN-QUESTIONS.md`/`DECISIONS.md`; existing-project facts either read by the owner from the dashboard or the project is replaced | — |
| **3.1** | **Identity core, local only** | 3.0 approvals for dependencies and the Supabase CLI | `supabase/` directory, migration tooling, L1 pgTAP harness in CI, `private` helpers, tables `admins`, `publishers`, `invites`, `audit_events`, functions `create_invite`, `revoke_invite`, `redeem_invite`, `set_publisher_status`; spikes U-3, U-4, U-6 recorded | T-M01–T-M06; T-A05 (for these tables), T-I01–T-I09, T-D01, T-D02, T-D04, T-D06, T-P11, T-S01 (SQL level), T-X05 pattern proved for a custom role; all green in CI; no real data | **Review 1** before 3.2: grants hygiene, definer functions, claim-setting method in tests |
| **3.2** | Experience core, local only | 3.1 | Tables `topics`, `experiences`, `experience_topics`, `revisions`, `revision_validations`, `approvals`, `publications`, `published_experiences`; lifecycle functions; roles `validator_service`, `ai_service` (no grants); spike U-6 conclusion | T-A01–T-A04, T-P01–T-P08, T-P12–T-P15, T-P18, T-L01–T-L13, T-X01–T-X07, T-D03, T-D05, T-M05; shape gate verified against both existing experiences' documents | **Review 2:** the approval/publication write path and the revocation of `service_role` privileges |
| **3.3** | Auth integration in the Next.js app (hosted **staging** project) | 3.1, 3.2, owner approval of `@supabase/ssr` and `@supabase/supabase-js`; staging project; custom SMTP | `proxy.ts` (matcher limited to `/studio`, `/admin`, `/sign-in`, `/auth`), server clients, DAL (`requireActivePublisher`, `requireAdmin`), sign-in, confirm page (POST button), sign-out, redeem, a minimal `/studio` identity page and `/admin/invites`, admin MFA enrolment; privileged module; spikes U-2, U-3, U-7 | T-S01–T-S10 at L2/L3, T-I04–T-I09 end to end, T-D01, T-D02, T-M07; public pages unchanged and set no cookies (T-S10) | **Review 3:** session handling, cache headers, enumeration, abuse limits |
| **3.4** | Admin operations | 3.3 | Suspend/reinstate, takedown with reason and confirmation, audit-log view, hold/lift | T-D03–T-D06, T-S02, T-S03, T-L10, T-L12 at L2/L3 | — |
| **3.5** | DB-backed public read path (behind a flag) | 3.2, 3.3, Q-42 decided | Public pages read `published_experiences` with a parity test against the file-based pages; revalidation on publish, unpublish, takedown; files remain the source until parity holds and the owner switches | parity tests; T-A01–T-A04; takedown visible within the agreed lag (Q-42) | **Review 4** |
| **3.6** | Feedback and aggregate events | 3.5, Q-17/Q-37 answered, legal gate partly met | `feedback`, `events_daily`, `record_event`, route handlers with rate limit and challenge | T-A06–T-A09, T-P09, T-P10, T-P17 | — |
| **3.7** | Pre-outside-publisher review | 3.1–3.6, legal gate (§6), Q-16 closed | Independent security review, recovery drill (restore a backup to a new project), runbook for admin bootstrap and exceptional access | all test layers green; backups proven; items in §6 answered | **Final review** — required before any non-owner publisher |

The workspace editor, AI authoring, media, reader accounts and organisations are **not** part of Stage 3.

## 3. Environments, Supabase project and secrets

### 3.1 The existing Supabase project is unverified

The owner reported that a Supabase project exists but is not connected. Its **organisation, owner and recovery path, region, plan, Postgres version, auth settings, API key model, and contents are all unverified** [U-1]. It could not be inspected from this session, and no credential was requested or may be. Nothing here assumes any of it.

**Recommendation (Rec D-051):** treat the existing project as *scratch* until the owner has recorded its facts (checklist below). **Create a new project for staging and another for production** once Q-30/Q-31 are answered, because:

- A region is one per project and the docs read do not say it can be changed in place; the documented route to a different region is a backup-and-restore into a new project [V-12]. Real data must not be put in a project whose region is unknown or unsuitable.
- Supabase's own environment guide says a staging project must be a **new** project, not one already modified to match production [V-13].
- Moving a project between organisations is a separate project-transfer operation [V-12], so ownership of the organisation should be settled **before** data exists (Q-34).

**Owner checklist to record (do not paste secrets anywhere):** organisation and who owns it; account recovery method; project region; plan; Postgres version; whether "Allow new users to sign up" is on; which API key model is in use (new publishable/secret vs legacy `anon`/`service_role`, the legacy ones being deprecated by end of 2026 [V-5]); whether any data or tables exist; whether RLS is enabled on them.

**Region suitability.** Mumbai (`ap-south-1`) and Singapore (`ap-southeast-1`) both exist [V-12]. Likely audience and publishers are in India (Phase 0 leaning: Mumbai, *verify*). Whether a given region matters for the DPDP Act 2023 (cross-border transfer, data residency) is a **legal** question for counsel (§6), not a technical one. The region should also be chosen jointly with the Next.js hosting region (Q-32).

### 3.2 Environments

| Environment | Database | Auth/email | Data | Secrets |
|---|---|---|---|---|
| **local** | Supabase local stack from `supabase/migrations` + synthetic `seed.sql` [V-13] | local Auth, local mail catcher (not verified which) | synthetic only | none that matter; env file untracked |
| **test / CI** | local stack started in CI, `supabase test db`, Vitest [V-13] | local | synthetic; per-run users | CI secrets only for deployment jobs |
| **preview / staging** | one hosted **staging** project, a *new* project [V-13]; preview deployments share it (D-012) | custom SMTP (sandbox) | synthetic, never production data | host secret store |
| **production** | a separate hosted project, paid plan before real data (see backups) | custom SMTP, production sender domain | real | host secret store, minimum people |

Production deployment is a **separate decision** (Q-23) and is not made or prepared here; DNS and the `inscapio.in` deployment are untouched.

### 3.3 Migrations

`supabase migration new` → `supabase db reset` locally → pull request → CI starts the stack and runs the tests → CI deploys to staging → after verification, to production via a CI job using an access token, DB password and project id stored as encrypted secrets, the token scoped to the projects it deploys to [V-13]. Never run migrations from a developer's machine against production. Forward-only; destructive changes use expand → migrate → contract and need explicit approval.

### 3.4 Backups and recovery

Free plan: no backups included and none downloadable; the guidance is to export regularly with `db dump` [V-8, V-6]. Pro: 7 days of daily backups; point-in-time recovery is a paid add-on needing at least a Small compute and costing about $100/month per 7 days at the time of reading [V-8]; daily backups **exclude Storage objects**; deleting a project deletes its backups [V-8]. Also on the free plan, projects pause after a week of inactivity and only two active projects are allowed [V-8]. **Recommendation (Rec D-051):** the production project must be on a plan with backups before any non-owner publisher joins, and a restore into a new project must be rehearsed (3.7). The plan to use, and pricing, must be re-checked at purchase time.

### 3.5 Environment variables and keys

| Variable | Where | Notes |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | browser + server | not secret [V-3] |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | browser + server | safe to expose; limited by RLS [V-5] |
| `SUPABASE_SECRET_KEY` | **server only**, one module (`server-only`) | bypasses RLS [V-5]; used only for the Auth admin API (invite, end sessions). One key per backend component [V-5]. Never in a client bundle, log, error or commit. T-M07 enforces. |
| validator and AI database credentials | **server/worker only**, separate variables | custom roles; only after spike U-6; distinct from every human-session path |
| SMTP credentials | Supabase dashboard / host secret store | provider chosen under Q-33 |

Use the new key model from the start; do not build on legacy `anon`/`service_role` keys [V-5]. Rotation: create new, replace everywhere, confirm, retire old [V-5]. No `.env` with real values is committed; `.env.example` lists names only. **This milestone requested and wrote no secret.**

## 4. Decisions needed from the owner before implementation

These are recommendations in `DECISIONS.md` as **Proposed**; none is approved by this PR.

| Decision | Needed for |
|---|---|
| D-045 roles and ownership live in tables, not JWT/metadata; ownership via helper functions | 3.1 |
| D-046 invite-only magic-link auth; invitation is an email-bound authorisation record, no token | 3.1, 3.3 |
| D-047 three-layer authorisation; public site is session-free | 3.3 |
| D-048 append-only revisions, human-only approval/publication functions, public projection table, no stored lifecycle status, held-takedown | 3.2 |
| D-049 AI uses a distinct custom Postgres role with no approval/publication privileges | 3.2 |
| D-050 admin ≠ content access; MFA, re-auth, audit; admin bootstrap by SQL | 3.1, 3.4 |
| D-051 new staging and production Supabase projects; existing one unverified; backups before outside publishers | 3.0 |
| D-052 three-layer RLS test strategy as a merge gate | 3.1 |
| D-053 increment order; start at 3.1; add `@supabase/ssr` and `@supabase/supabase-js` only at 3.3 with approval | 3.0 |

Open questions to answer: Q-30…Q-43 in `OPEN-QUESTIONS.md`.

### 4.1 Increment 3.1 reconciliation (15 Oct 2026)

**Approvals (3.1 portions only).** The owner approved: D-045; the invitation portion of D-046; the 3.1 portion of D-050; D-052; the 3.1 portion of D-053. D-047, D-048, D-049, D-051 and the remaining parts of D-046/D-050/D-053 are **not** approved. See `DECISIONS.md`.

**3.0 versus 3.1.** 3.0 gates hosted work. The 3.1 build is local only, so only the items below block it; everything else in 3.0 waits for staging (3.3).

| Question | Blocks local-only 3.1? | Where it is needed |
|---|---|---|
| Q-30, Q-31, Q-32, Q-33, Q-34 (hosting, project, SMTP, admin count) | No | 3.3 staging; before outside publishers |
| Q-38 (publisher MFA) | No (admin aal2 is approved in D-050) | 3.3 |
| Q-40 (invite delivery, 7-day default) | No: the default is a function parameter bounded 1–30 days and can change | 3.3 |
| Q-43, Q-35, Q-36, Q-37, Q-39, Q-41, Q-42 | No | 3.2 and later |

**Test layers required for 3.1, and the merge gate.** The gate is the `Database` workflow, which runs on the real Supabase local stack (CLI 2.120.0, local Postgres 17; hosted version unverified, U-4):

| Layer | Command | Covers |
|---|---|---|
| L1 pgTAP | `supabase test db` (six files, 222 assertions, `supabase/tests/database/`) | catalogue/grant/RLS/policy inventory (T-M01–T-M06, T-A05 for these tables), roles and every denied operation with a positive counterpart (T-I01, T-D01, T-D02, T-D04, T-D06, T-P11, T-S01), invitation rules at SQL level (unverified email, mismatched email, expired, revoked, redeemed, success, no partial records), audit append-only |
| L1c concurrency | `supabase/tests/concurrency/redeem-invite-race.sh` (two real sessions; unique data per run; CI runs it twice on one stack) | T-I07 and the audit append-only invariant |
| L2 API | `node --test supabase/tests/api/` against real GoTrue and PostgREST | anon RPC/table denial, private schema not exposed, aal1 versus aal2 with real TOTP (T-I02, T-I03), metadata tamper (T-S04), same-token suspension (T-S02), forged token (T-S05) |

L3 (application/e2e) is **not implemented** and not claimed: there is no Next.js auth in 3.1. It is added to the gate before the application functionality that needs it (3.3). Tests for later increments stay in the inventory, marked deferred.

**Recorded deviations from the design documents.** Each is narrower or stricter than the design; none is individually approved (D-054 stays Proposed). The tests listed are those that prove the implemented behaviour on the real stack.

| Deviation | Reason | Proved by |
|---|---|---|
| `text` + lowercase/trim CHECK instead of `citext` for email | no extension dependency; same normalisation guarantee | `020_invites` (normalisation, CHECK) |
| `publishers.handle` nullable, set-once by trigger | `redeem_invite()` takes no arguments, so no handle is known at redemption | `030_publishers` (set-once, format, reserved, duplicate) |
| invites gain status `expired` | lets a lapsed invitation stop blocking a new one for the same email | `020_invites` |
| no `anon` access to `publishers` in 3.1 | public profile belongs with the public projection in 3.2 | `050_anon_and_service_role`, API anon test |
| no `owns_experience` helpers | need the `experiences` table (3.2) | not applicable in 3.1 |
| audit `details` allow-list `invite_id, ttl_days, from, to`; `request_id` column exists but is unset | prevents free-form personal data in the log; request ids arrive with the application layer | `040_audit` |

**Not a deviation any more.** RLS is now `ENABLE` **and** `FORCE` on all four tables (T-M01), verified on the real local stack: the catalogue test checks `relrowsecurity` and `relforcerowsecurity`, and every function and API test passes with FORCE on. The SECURITY DEFINER functions still write because they are owned by the migration role, which has `BYPASSRLS` in the Supabase local stack; `001_catalogue` asserts that every definer function's owner has `BYPASSRLS`. Whether the hosted `postgres` role has the same attribute is **unverified** and must be checked before any hosted migration (U-4/Q-31).

**Own-row read (T-S02 / T-S03).** `publishers_select_own` requires `private.is_active_publisher()`. A suspended or revoked publisher with a still-valid token can neither read nor update their row (no status-visibility exception in 3.1); an administrator at aal2 can still inspect every publisher row; a publisher cannot change `status` (no column grant) and cannot self-reactivate; reinstatement by an administrator restores access to the same token. Proved by `030_publishers` and the API test "T-S02 / T-S03".

**Invitation expiry semantics.** Expiry is determined by `expires_at`, evaluated whenever an invitation is used. The stored status `expired` is **not** set automatically or by a scheduled job. It is written only when `create_invite` runs for the same email and finds a lapsed `pending` row. `redeem_invite` refuses a lapsed invitation (`expires_at <= now()`) without changing its status, so a lapsed invitation can remain stored as `pending`. Any reporting must therefore treat `pending AND expires_at <= now()` as expired. A scheduled sweep, if wanted, is later work.

### 4.2 Increment 3.2 reconciliation (15 Oct 2026)

**Scope.** The eight tables of the data model (`topics`, `experiences`, `experience_topics`, `revisions`, `revision_validations`, `approvals`, `publications`, `published_experiences`), the lifecycle functions, and the roles `validator_service` and `ai_service`. Local database only; no application code, no hosted project, no public-site change. The 3.1 migrations are untouched; 3.2 adds four forward-only migrations (`20261016000100`–`400`).

**Approval status.** The owner instructed this implementation on 15 Oct 2026. That instruction is **not** recorded as acceptance of D-048 or D-049, or of Q-43: those stay Proposed/open until the owner confirms them (see D-055). Nothing is merged by the PR.

**Q-43 (needed by 3.2).** Implemented as **attestation from the start**: `revision_validations` is writable only through `record_validation`, callable only by `validator_service`; the database copies the content hash from the stored revision; approval requires the *latest* attestation for the exact content to be a pass. The database cannot run Zod, so the SQL "shape gate" is a structural check only. It is not described, anywhere, as full validation; the full Zod gate is run by the future validator service and is unit-tested separately in the repository (`tests/unit/shape-gate-drift.test.ts` ties the SQL vocabulary to the Zod schema and checks both existing experiences against it).

**U-6 (custom Postgres roles).** Verified on the real local stack: migrations can create NOLOGIN roles that hold no table privilege, that cannot be superuser/BYPASSRLS, that are members of no other role; EXECUTE grants to them work; they are denied everything else (110_service_roles). **Not verified:** role creation by migration on a hosted project, a login role and pooled/direct connection from the chosen host, and password handling (a later increment; no credential is created here).

**Test inventory and merge gate for 3.2** (the `Database` workflow, real Supabase local stack, Postgres 17):

| Layer | Files / command | Covers |
|---|---|---|
| L1 pgTAP | `supabase test db`: 14 files, 645 assertions | `001`/`100` exact catalogue (tables, grants, column grants, EXECUTE grants, policies, FORCE RLS, triggers, FKs, role attributes); `110` service roles T-X01–X07 incl. in-function re-checks; `120` isolation T-P01–P08, P12–P15, P18, T-A01–A03, T-D03, T-S02; `130` revisions T-L06, L07, L13, T-P14, T-M05; `140` validation and approval T-L02, L03, L04, T-P06; `150` publication T-L01, L03, L05, L08, L09, L11, L12, T-A04, T-P07/P08; `160` topics T-D05; `170` audit |
| L1c concurrency | `lifecycle-races.sh` (two real sessions, run twice), `redeem-invite-race.sh` | T-L06, T-L05, T-L10, T-I07 |
| L2 API | `node --test` on `identity.api.test.mjs` and `experience.api.test.mjs`: 21 tests | real GoTrue/PostgREST/aal2: ownership isolation, validator and secret-key denial, publish/unpublish/takedown/hold, same-token suspension, forged token, both real experience documents through the shape gate |
| Unit | `pnpm test` (Vitest) | drift between the SQL shape gate and the Zod schema; both existing experiences satisfy the structural gate |

Pre-merge review additions: the API test helper `asValidator` now runs grant, role switch, work and revoke in one transaction, so a failing statement rolls the membership back (a regression test in `harness.api.test.mjs` proves no membership survives a failed call, and a sentinel in `experience.api.test.mjs` checks the same); API denial tests were added for the administrator (aal2), a non-publisher user and anon on both validator functions and on direct attestation writes; the attestation retry contract is tested in pgTAP 140 and recorded as D-055 item 8a.

Not implemented, not claimed: L3 browser/application tests; T-S01–S10 at L3; anything needing Next.js auth (3.3); T-D06; publisher public profile (T-A01 `publishers` columns); the admin audit-log view.

**Recorded clarifications and deviations from the data model** (all in D-055, Proposed; none individually approved): `text` + CHECK slug instead of `citext`; composite foreign keys (approval and attestation bound to the revision's hash; publication bound to approval and experience; head bound to its experience) in place of the single-column keys; `get_revision_for_validation` added so the validator can read what it attests; a revision's document slug and kind must equal the stored columns; `save_revision` is refused on an archived experience but allowed during a hold, and a hold blocks approval and publication; a hold cannot be set on a live publication (takedown is the atomic path) and an experience with a live publication cannot be archived; the latest attestation governs and a tie fails closed; only schema version 1 is accepted; a proposed reserved-slug list (the two existing file-based slugs plus route words); `approve_revision` takes no note parameter; topic writes are direct DML by an aal2 administrator with a same-transaction audit trigger; the audit-detail allow-list gains `experience_id, revision_id, publication_id, topic_id, seq, reason_code, validator_version, passed, held`. The published projection takes title, summary and language from the **approved revision's** document and the topic slugs as they are at publish time; changing topics later needs a republish.

**Owner decisions needed:** confirm D-048 (3.2 portion) and D-049 (the `ai_service` role, created with no privileges); confirm Q-43 (attestation from the start); review the D-055 clarifications; supply the reserved-slug list; decide whether `validator_service` becomes a separate login role in 3.3.

## 5. Out of scope for Stage 3

Reader accounts; AI authoring and `ai_operations`; the publisher workspace editor UI (Stage 4); media upload and Storage; `sources`/`knowledge_items`; interviews; organisations/teams; billing, subscriptions, recommendations; a configurable permissions framework; importing the two existing experiences into the database; changing the production domain, DNS or deployment; any edit to `prototype/v0/`.

## 6. Legal, privacy and content-safety gates

Nothing here is a legal conclusion. The DPDP Act 2023 was flagged in Phase 0 as needing counsel; **current official sources must be read and counsel engaged** before the items below are settled. Gate = must be answered before the stated action.

### 6.1 Questions to answer before…

| Before | Questions |
|---|---|
| **Collecting publisher personal data** (name, email, bio, handle, audit actor ids) | What is the lawful basis and notice text? Who is the data controller (an entity must exist)? What is collected and why (minimisation: already no email outside Auth and `invites`)? Retention and deletion periods (invitations 90 days after resolution, audit 24 months: proposals only)? Access, correction, export and erasure process and the contact route (Q-36)? Where is the data stored (region) and is any transfer outside India relevant? Which processors are involved (Supabase, SMTP provider, host, challenge vendor) and are agreements in place? Breach-response procedure? |
| **Storing uploaded source materials** | Do publishers warrant rights to what they upload? Copyright and takedown route; third-party personal data inside sources; storage location and retention; whether AI may process them (provider terms); scanning for unsafe content. |
| **Storing feedback** (Q-17, Q-37) | Is free text personal data? Is a notice shown at the form? Is contact detail collected (recommended: no)? Retention (proposal 12 months); who can read it (owner only by design); abuse and spam handling; whether readers can request deletion given they are not identified. |
| **Inviting outside publishers** | Terms of use and content policy for publishers; publisher agreement on rights and licence to publish; moderation and takedown policy and appeal route (Q-39); who decides and how fast; `/legal/*` pages exist (IA already requires them); a named contact; the recovery drill and security review (3.7) done; Q-16 closed. |
| **Analytics** | Aggregate-only counts without identifiers (D-022) may need no consent notice, but this is a legal question; confirm. |
| **Cookies** | Auth cookies are strictly for signed-in publishers; the public site sets none by design. Confirm the notice obligation with counsel. |

### 6.2 Q-16 "Whose Body Is It?" — a release blocker

The experience concerns a real case involving minors and is unreviewed (Q-16, Q-28, D-041, D-044). **It must not be treated as resolved by hiding it in the interface.** Specifically:

- The Stage 2 promotion hold (`HELD_FROM_NEXT`) and the homepage omission are **presentation controls only**. The page remains reachable by its URL and exists in the repository and, later, in the database. They do not close Q-16.
- **Q-16 blocks** promoting it, any public deployment of the new app that includes it, importing it into the database as published content, and inviting outside publishers.
- Closing it needs a substantive review (accuracy, consent and identification risks, treatment of the minors, claims and sourcing, whether to publish, revise or withdraw), by a named reviewer, with the outcome recorded in `DECISIONS.md`. The data model supports an enforceable **hold** (`experiences.held_at`; publication refused until lifted by an admin) so that a held item is blocked at the database, not just the UI; this is the mechanism intended for the first real use of takedown. Until the file-to-database import (not in Stage 3) exists, the file-based hold remains the control.

## 7. Rollback, migration and security checkpoints

- **Rollback:** application changes by revert PR; migrations by forward fix, never by editing an applied migration; before any production migration, a backup exists (plan with backups) and the previous app version is deployable. Feature flag for 3.5 so the file-based public path can be restored instantly.
- **Migration checkpoints:** each migration reviewed with its tests; a CI job compares `supabase db diff` to the committed migrations so no dashboard-only change exists [V-13].
- **Security reviews:** four named in §2 plus the final review (3.7). Each reviewer checks the grants listing, every definer function, and runs the negative tests from a clean checkout. A reviewer who did not write the code should do 3.7; independent external review is recommended before opening to publishers beyond the invited few.
- **Stop conditions:** any failing negative test, any table without RLS, any secret in a diff, or any unverified vendor assumption (U-n) still relied upon halts the increment.

## 8. Pre-PR validation performed on this milestone

Cross-document consistency and test completeness were checked mechanically before opening the PR: table and function names across the three architecture documents; every P-xx matrix row lists tests that exist; every T-xx defined proves at least one matrix row or is a meta/lifecycle test; every Section 8 negative test is mapped; all D-/Q- numbers referenced exist in `DECISIONS.md`/`OPEN-QUESTIONS.md`; relative links resolve; only documentation changed; `prototype/v0/index.html` hash unchanged. The results are reported in the PR description. This checks the **documents**, not the security properties.
