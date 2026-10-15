# Authentication and RLS test plan

> **Status:** Stage 3 design · **Proposed**. **Only the 3.1 subset exists** (L1 pgTAP, L1c concurrency, L2 API; inventory and results in `stage-3-implementation-plan.md` §4.1 and the `Database` workflow). Every other test described here does not exist yet and no property it covers is verified. The plan says what must be proved, against which real roles, before each increment can merge.
> **Companions:** [`identity-and-access-control.md`](./identity-and-access-control.md) (permission matrix P-xx), [`supabase-data-model.md`](./supabase-data-model.md) (tables, functions), [`stage-3-implementation-plan.md`](./stage-3-implementation-plan.md). Labels (V-n verified vendor fact, U-n unverified, Rec D-nnn recommendation) are defined in the identity document §0.

> **3.1 implementation note (15 Oct 2026):** where this document differs from the migrations, the migrations and `stage-3-implementation-plan.md` §4.1 (deviations, FORCE RLS, own-row read, invitation expiry) are authoritative for the local identity core. Deviations remain Proposed (D-054).

## 1. Principle: tests run against the real policies and roles

Frontend tests, mocked clients and "the button is hidden" tests prove nothing about access control. Every protected-table test must run **in Postgres, as the real database role, with real JWT claims, against the real migrations**. Three layers, each catching what the others cannot:

| Layer | What it is | Runs against | Catches |
|---|---|---|---|
| **L1 · SQL (pgTAP)** | `supabase test db`; each test in a transaction that rolls back; `SET LOCAL ROLE anon / authenticated`; JWT claims set per user; also `reset role` to a custom role for `ai_service` / `validator_service` [V-13] | Local Supabase Postgres built from `supabase/migrations` | Policy and grant mistakes, function checks, constraints, triggers, FK guarantees |
| **L2 · API (Vitest + supabase-js)** | Real sign-in against the local Auth service; publishable-key clients as each user; the secret key only where a test is *about* the secret key [V-13] | Local stack (Postgres + Auth + API) | Real JWTs, `aal`, stale tokens, tampered metadata, rate limits, RPC exposure, key behaviour |
| **L3 · Application (Vitest + Playwright)** | DAL unit tests and browser tests of `proxy.ts`, route guards, server actions, public caching headers | Built Next.js app + local stack | Route guards, action authorisation, cookies/caching, enumeration, UX of denial |

The pgTAP and Vitest patterns come from Supabase's own testing guide [V-13]. The exact mechanism for setting claims in L1 (`request.jwt.claims` configuration) and the helper packages are confirmed in increment 3.1; if a pattern differs, this plan is amended before tests are written.

**Rules for all tests.** Each test names the role it runs as. Every negative test also has a *positive twin* proving the same operation succeeds for the right principal (otherwise a typo can pass a negative test). A denied read must be *indistinguishable from "no rows"/"not found"*, not a different error that reveals existence, except where a distinct error is the specification. Fixtures: two publishers A and B (active), publisher S (suspended), an admin M with and without `aal2`, an authenticated user U with no capability, anon, `ai_service`, `validator_service`, and the secret key (`service_role`). All synthetic.

**CI gate.** The L1 and L2 suites run on every pull request that touches `supabase/`, `src/server/`, or `proxy.ts`; the pipeline starts the local stack and runs `supabase test db` [V-13]. A migration PR without tests for each new table and function does not merge.

## 2. Meta-tests (catalogue checks; one run per migration set)

| ID | Layer | Assertion |
|---|---|---|
| T-M01 | L1 | Every table in `public` has RLS **enabled and forced**. A new table fails the build until listed in an explicit allowlist with its policy tests. |
| T-M02 | L1 | `anon` holds privileges only on the allowlist (`published_experiences` SELECT, `topics` SELECT, `publishers` public columns SELECT, `feedback` INSERT columns, EXECUTE on `record_event`); `authenticated` and `service_role` hold none beyond the section tables of the data model (catches the default-grants problem [V-4]). |
| T-M03 | L1 | Every `SECURITY DEFINER` function has `search_path` set to empty, is schema-qualified, has no `EXECUTE` for `PUBLIC`, and its grantees match the data-model function table. |
| T-M04 | L1 | No view in an exposed schema lacks `security_invoker = true`. |
| T-M05 | L1 | Append-only triggers exist on `revisions`, `revision_validations`, `approvals`, `audit_events` and the publication-mutation trigger; each raises for **every** role including `service_role`. |
| T-M06 | L1 | Every column referenced in a policy has an index (catches the performance advice [V-4]); `auth.uid()` appears only inside `(select …)`; every policy has an explicit `TO`. |
| T-M07 | L3 | A repository check fails if any file other than the privileged module reads the secret-key variable or imports it, and no `NEXT_PUBLIC_*` variable contains a secret. |

## 3. Test catalogue

"Role" = the database role and identity the test runs as. "Proves" = permission-matrix rows.

### 3.1 Anonymous and public

| ID | Layer | Role | Assertion | Proves |
|---|---|---|---|---|
| T-A01 | L1, L2 | anon | Can read a live row from `published_experiences`, public columns of an active `publishers` row, and `topics` (positive). | P-01, P-02 |
| T-A02 | L1, L2 | anon | `select` on `experiences` is denied (permission error or zero rows, per grant design), for draft, published and unpublished experiences. | P-03 |
| T-A03 | L1, L2 | anon | `select` on `revisions`, `revision_validations`, `approvals`, `publications` is denied. **A public query cannot expose an unpublished revision.** | P-04 |
| T-A04 | L1 | anon | After `unpublish_experience` or `admin_takedown`, the row is absent from `published_experiences`; a query by slug returns nothing; a newer draft revision never appears. | P-01 |
| T-A05 | L1, L2 | anon | Parametrised over `admins, invites, audit_events, feedback, events_daily, experience_topics, experiences`: select, insert, update, delete all denied; private `publishers` columns (`status*`) cannot be selected. | P-02 |
| T-A06 | L1, L2 | anon | Can insert feedback for a live publication within limits (positive). | P-05 |
| T-A07 | L1, L2 | anon | Feedback insert is rejected for a non-live or unknown pair, an oversize message, extra columns; anon cannot select, update or delete feedback. | P-05 |
| T-A08 | L1, L2 | anon | `record_event` works for a live experience and rejects unknown events/unpublished experiences; direct insert/update on `events_daily` is denied. | P-06 |
| T-A09 | L1, L2 | anon | Calling any other function through the API (`approve_revision`, `publish_revision`, `create_invite`, `redeem_invite` …) is denied. | P-06 |

### 3.2 Publisher and ownership isolation

| ID | Layer | Role | Assertion | Proves |
|---|---|---|---|---|
| T-P01 | L1, L2 | A | `create_experience` succeeds; the owner is A; passing B's id anywhere is impossible or ignored. | P-09 |
| T-P02 | L1, L2 | A | **A cannot read B's experience** (draft or published-then-unpublished): zero rows. Positive twin: A reads own. | P-03 |
| T-P03 | L1, L2 | A | **A cannot update B's experience** (zero rows affected, state unchanged). | P-10 |
| T-P04 | L1, L2 | A | **A cannot read B's revisions** or validations. | P-04 |
| T-P05 | L1, L2 | A | **A cannot save a revision to B's experience** (`save_revision` refuses). | P-11 |
| T-P06 | L1, L2 | A | **A cannot approve B's revision.** | P-14 |
| T-P07 | L1, L2 | A | **A cannot publish B's revision or experience.** | P-15 |
| T-P08 | L1, L2 | A | **A cannot unpublish B's publication.** | P-16 |
| T-P09 | L1, L2 | A | A cannot read or update B's feedback. | P-17 |
| T-P10 | L1, L2 | A | A cannot read B's `events_daily`. | P-18 |
| T-P11 | L1, L2 | A | A can update own `display_name` and `bio`; cannot update B's profile; cannot change own `status`, `handle` or `id`. | P-08 |
| T-P12 | L1, L2 | A | Positive: A reads own experiences, revisions, validations. | P-12 |
| T-P13 | L1, L2 | A | A cannot change `publisher_id`, `slug` after first publish, `head_revision_id` or `held_*` of own experience (column grants) and cannot insert directly into `experiences`. | P-09, P-10 |
| T-P14 | L1 | A, admin, owner role | Updating or deleting any revision is impossible for every role (trigger + grants). | P-11 |
| T-P15 | L1, L2 | A | Direct INSERT/UPDATE/DELETE into `approvals`, `publications`, `published_experiences`, `audit_events` is denied. | P-14, P-15 |
| T-P16 | L3 | A, B | Preview of A's revision by B returns *not found*; unauthenticated redirects; response is `noindex` and `no-store`. | P-13 |
| T-P17 | L1, L2 | A | Positive: A reads and updates `status` on own feedback and reads own analytics. | P-17, P-18 |
| T-P18 | L1 | A | No self-service deletion of the publisher row or experiences; removal blocked while publications exist. | P-19 |

### 3.3 Invitations and redemption

| ID | Layer | Role | Assertion | Proves |
|---|---|---|---|---|
| T-I01 | L1, L2 | A (publisher), U | **An ordinary publisher cannot create, read, revoke or update invitations**; neither can a user with no capability. | P-21, P-22 |
| T-I02 | L1, L2 | admin M at `aal1` | Cannot create or revoke invitations; the same call at `aal2` succeeds (T-I03). | P-21, P-22 |
| T-I03 | L1, L2 | M at `aal2` | `create_invite` succeeds (TTL ≤ 30 days; audit row written in the same transaction). | P-21 |
| T-I04 | L1, L2 | invited user | Redemption with a *verified* email matching a pending, unexpired invite creates the `publishers` row, marks the invite redeemed, writes the audit row, atomically. | P-07 |
| T-I05 | L1, L2 | invited user / U | Redemption fails with **no `publishers` row created** when the invite is expired, revoked, already redeemed, absent, or the email differs; revoking a pending invite works. | P-07, P-22 |
| T-I06 | L1 | M | A second pending invite for the same email is rejected; after redemption or revoke a new one is allowed. | P-21 |
| T-I07 | L2 | invited user | Two concurrent `redeem_invite()` calls produce exactly one `publishers` row and one redeemed invite. | P-07 |
| T-I08 | L1, L2 | any | `redeem_invite` accepts no email, role or status parameter; identity comes only from the database. | P-07 |
| T-I09 | L1, L2 | S (suspended) | Redemption or sign-in does not reactivate a suspended or revoked publisher; only an admin's `set_publisher_status` does. | P-07, P-23 |

### 3.4 Sessions, revocation, role tampering, route guards

| ID | Layer | Role | Assertion | Proves |
|---|---|---|---|---|
| T-S01 | L1, L2, L3 | U | **An authenticated but unapproved account** (no `publishers` row) gets zero rows from every private table, every write function refuses, and `/studio` denies. | P-03 |
| T-S02 | L2 | S | **A revoked or suspended publisher with a still-valid access token** is denied on the very next read and write, with no wait for token expiry. Sequence: sign in, succeed, admin suspends, repeat with the *same* token. | P-23 |
| T-S03 | L2 | S | After revoke + ban, refresh-token use fails and the server ends sessions [U-7 to resolve in the spike]. | P-23 |
| T-S04 | L2 | A | **User changes client-supplied role metadata** (`updateUser({ data: { role: 'admin' }})`, forged `app_metadata` in the request): no admin function, table or route becomes accessible; `user_metadata` is never read by any policy [V-4]. | all |
| T-S05 | L2 | any | A JWT with altered claims (role, aal, sub) or a bad signature is rejected by the API; an `aal1` token cannot pass an `aal2` policy. | P-20 |
| T-S06 | L2 | A | Expired token rejected; after sign-out the old refresh token is unusable. | P-07 |
| T-S07 | L3 | none, A, M | Unauthenticated request to `/studio` or `/admin` redirects; a publisher gets *not found* on `/admin`; a server action invoked directly (no session, or the wrong role) is rejected without side effects; the *proxy* being bypassed (direct call) changes nothing. | P-03, P-20 |
| T-S08 | L3 | A | Role, `publisher_id` or `status` fields injected into a server-action body, query string or header are ignored; the actor always comes from the verified session. | all |
| T-S09 | L2, L3 | none | Sign-in responses for a known, an invited and an unknown email are identical in body and similar in timing; per-email and per-IP limits return 429 [V-7]; magic link and invitation links are single-use. | P-07 |
| T-S10 | L3 | anon | Public pages set no cookies, never read the session, and are served with cacheable headers; no `Set-Cookie` on any public route. | P-01 |

### 3.5 Lifecycle and publication

| ID | Layer | Role | Assertion | Proves |
|---|---|---|---|---|
| T-L01 | L1, L2 | A, anon | Happy path: create, save, validated, approve, publish; anon reads it; unpublish; anon no longer does; the slug stays reserved. | P-01, P-16 |
| T-L02 | L1 | A | **A revision that failed validation cannot be approved**; one with no attestation cannot be approved; the publisher cannot write an attestation. | P-14 |
| T-L03 | L1 | A | **An unapproved revision cannot be published** (function refusal) and a publication row for it cannot be inserted at all (FK). | P-15 |
| T-L04 | L1 | A | Approval is bound to the content hash; an approval for revision 3 cannot publish revision 4; "approve latest" does not exist. | P-14 |
| T-L05 | L1, L2 | A, anon | New draft revisions saved while an older revision is live do not change what anon sees; publishing a newer approved revision supersedes the old publication in one transaction. | P-15 |
| T-L06 | L1, L2 | A | **Concurrent edit detection:** two saves from the same parent: the second gets a conflict; no overwrite; the head is the first. | P-11 |
| T-L07 | L1 | A | Restore creates a new revision with `restored_from` set; the old revision is byte-identical. | P-11 |
| T-L08 | L1 | A, B | A slug stays reserved after unpublish; B cannot take it; A cannot change a slug after first publish. | P-10 |
| T-L09 | L1 | A | At most one live publication per experience (partial unique). | P-15 |
| T-L10 | L2 | S | Suspension committed between the editor opening and saving: the next function call refuses; already committed work is intact. | P-23 |
| T-L11 | L1 | A | Publication history retained after unpublish; an audit row is written in the same transaction; forcing the audit insert to fail rolls the whole action back. | P-16 |
| T-L12 | L1, L2 | M | `admin_takedown` removes the public row, records code and note, sets the hold; the owner cannot republish until the hold is lifted by an admin. | P-25 |
| T-L13 | L1 | A | A malformed document (wrong `schemaVersion`, unknown block type, oversize) is rejected by the shape gate at save; a document that is shape-valid but fails Zod is stored with `passed=false` and cannot be approved. | P-11, P-14 |

### 3.6 Admin boundaries

| ID | Layer | Role | Assertion | Proves |
|---|---|---|---|---|
| T-D01 | L1, L2, L3 | A, U | A non-admin cannot call any admin function or reach `/admin`. | P-20 |
| T-D02 | L1, L2 | M at `aal1` | Admin operations require `aal2`; `is_admin()` is false at `aal1`. | P-20 |
| T-D03 | L1, L2 | M `aal2` | **An admin cannot read** any `experiences`, `revisions`, `revision_validations`, `approvals`, `feedback` row (zero rows); takedown works without content access. | P-04, P-25, P-28 |
| T-D04 | L1, L2 | M | `set_publisher_status` requires a reason; writes audit; effect immediate (see T-S02). | P-23 |
| T-D05 | L1, L2 | M, A | Topics: write only for an `aal2` admin; publisher and anon read only. | P-24 |
| T-D06 | L1, L2 | M, A | Audit log and all-publisher aggregates readable only by an `aal2` admin; the audit log contains no document content or email; reading it writes `audit.read`. | P-26, P-27 |

### 3.7 AI service and privileged-credential restrictions

| ID | Layer | Role | Assertion | Proves |
|---|---|---|---|---|
| T-X01 | L1 | `ai_service` | **AI credentials cannot create an approval:** no `INSERT` on `approvals`, no `EXECUTE` on `approve_revision`; calling the function fails; the function also fails with no `auth.uid()`. | P-14, P-31 |
| T-X02 | L1 | `ai_service` | **AI credentials cannot publish or unpublish:** no privileges on `publications`, `published_experiences`; no `EXECUTE` on the publish functions. | P-15, P-31 |
| T-X03 | L1 | `ai_service` | In Stage 3 the role has no table privileges at all (direct insert into `experiences` fails); once AI authoring exists, only `ai_api.create_draft` works and only for a requested experience. | P-29 |
| T-X04 | L1 | `ai_service` | Direct insert into `revisions` fails; once built, `ai_api.create_revision` sets `author_kind='ai'`, refuses a wrong parent, and cannot mark validation. | P-30 |
| T-X05 | L1 | `ai_service`, `validator_service` | Neither can run admin, invite, takedown, or the other's functions; `validator_service` cannot approve or publish. | P-31 |
| T-X06 | L1 | `ai_service` | Cannot select any publisher's private data. | P-29, P-30, P-32 |
| T-X07 | L1, L2 | `service_role` (secret key) | **Even the secret key cannot insert** into `approvals`, `publications`, `published_experiences`, or update/delete `revisions` (privileges revoked; triggers apply). A sentinel test also fails if a migration re-grants them. | P-31 |

## 4. Coverage map

**Section 8 requirement → tests**

| Required negative test | Tests |
|---|---|
| Unauthenticated draft read | T-A02, T-A03, T-A05, T-S07 |
| Publisher A reading or editing B's draft/experience | T-P02, T-P03, T-P04, T-P05 |
| Publisher publishing an experience they do not own | T-P07, T-P06, T-P08 |
| Ordinary publisher issuing invitations | T-I01 |
| Unapproved account entering the workspace | T-S01 |
| Revoked publisher retaining access via a stale session | T-S02, T-S03, T-L10 |
| AI credentials creating an approval or publishing | T-X01, T-X02, T-X05, T-X07 |
| A public query exposing unpublished revisions | T-A03, T-A04, T-L05 |
| A user changing client-supplied role metadata | T-S04, T-S05, T-S08 |

**Protected table → tests** (each table needs at least one denial test per role that must be excluded)

| Table | Tests |
|---|---|
| `admins` | T-A05, T-D01, T-D03, T-M01 |
| `publishers` | T-A01, T-A05, T-P11 |
| `invites` | T-I01–T-I09, T-A05 |
| `audit_events` | T-A05, T-P15, T-D06, T-L11, T-M05 |
| `topics` | T-A01, T-D05 |
| `experiences` | T-A02, T-P02, T-P03, T-P13, T-D03 |
| `experience_topics` | T-A05, T-P01 |
| `revisions` | T-A03, T-P04, T-P14, T-X07 |
| `revision_validations` | T-A03, T-L02, T-L13, T-X05 |
| `approvals` | T-A03, T-P06, T-P15, T-X01, T-X07 |
| `publications` | T-A03, T-P07, T-P15, T-L03, T-X02, T-X07 |
| `published_experiences` | T-A01, T-A04, T-P15, T-X07 |
| `feedback` | T-A06, T-A07, T-P09, T-P17, T-D03 |
| `events_daily` | T-A08, T-P10, T-D06 |

**Permission matrix rows → tests.** Every P-01…P-32 row in the identity document lists its proving tests in its last column; the pre-PR validation (implementation plan §8) checks that each referenced ID is defined here and each defined test proves at least one row.

## 5. Out of scope for this plan (and why)

Performance and load tests of RLS at scale (alpha volume only; revisit before open publishing); penetration testing (a separate security review checkpoint, plan §7); tests of reader accounts, AI authoring behaviour, billing, media Storage policies (not built; media needs its own plan [U-10]); end-to-end email deliverability (verified manually on the staging project with the chosen SMTP provider).
