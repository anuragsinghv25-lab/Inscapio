# Supabase data model

> **Status:** Stage 3 design · **Proposed** (no table, migration, policy or function exists; nothing was run against any database) · written 13 Oct 2026.
> **Companions:** [`identity-and-access-control.md`](./identity-and-access-control.md) (principals, permission matrix P-xx, labels, verified facts V-n / unverified U-n), [`authentication-and-rls-test-plan.md`](./authentication-and-rls-test-plan.md) (T-xx tests), [`stage-3-implementation-plan.md`](./stage-3-implementation-plan.md).
> **Provenance labels** are defined in the identity document §0. In short: *Accepted/Proposed D-xxx* = already in the decision log; *Rec D-045…D-053* = new recommendation, Proposed only; *V-n* = verified vendor fact; *U-n* = unverified.

> **3.1 implementation note (15 Oct 2026):** where this document differs from the migrations, the migrations and `stage-3-implementation-plan.md` §4.1 (deviations, FORCE RLS, own-row read, invitation expiry) are authoritative for the local identity core. Deviations remain Proposed (D-054).

## 1. Starting point and what changes

`backend-architecture.md` (Phase 0, Proposed) lists conceptual tables: `publishers, topics, experiences, experience_topics, revisions, approvals, publications, interview_sessions, interview_turns, knowledge_items, sources, media, feedback, events_daily, invites, jobs, ai_calls`, with later `readers, follows, subscriptions, saved, notifications, entitlements, organisations, members`. This document evaluates each against "is it needed for the Stage 3 foundation?".

| Conceptual table | Verdict | Reason |
|---|---|---|
| `publishers` | **Keep (3.1)** | Identity and status anchor. No email stored here. |
| `invites` | **Keep (3.1)** | Authorisation record for invite-only access. |
| *(new)* `admins` | **Add (3.1)** | Admin must be a table fact, separate from publisher. |
| *(new)* `audit_events` | **Add (3.1)** | Required for admin and publication accountability; also written by DB functions in-transaction. |
| `topics`, `experience_topics` | **Keep (3.2)** | Small; needed for curation and public topic pages. |
| `experiences` | **Keep (3.2)** | Ownership, slug reservation, head pointer. **No stored lifecycle `status`** (see §6.1: derived). Adds a `held_at` takedown hold. |
| `revisions` | **Keep (3.2), append-only** | Versioned JSONB document validated by the existing Zod schema (D-005). |
| *(new)* `revision_validations` | **Add (3.2)** | Server-attested validation, so a publisher cannot self-certify (R-1 in the identity doc). Append-only. |
| `approvals` | **Keep (3.2)** | One human approval of one revision; sole write path is a function. |
| `publications` | **Keep (3.2)** | Explicit publication history; FK to `approvals` makes "publish unapproved" unrepresentable. |
| *(new)* `published_experiences` | **Add (3.2)** | The only table the public reads: a snapshot projection. Keeps published content physically separate from draft state. |
| `feedback` | **Keep (3.6)**, provisional | Shape depends on Q-17 and the legal gate. |
| `events_daily` | **Keep (3.6)** | Aggregate-only analytics (D-022). |
| `sources` | **Defer** | Source references already live inside the experience JSON. A table is only justified for uploaded source *materials* (legal gate, plan §6). |
| `media` | **Defer (own increment)** | Needs Storage RLS decisions [U-10]. Alt text will be NOT NULL when built. |
| `interview_sessions`, `interview_turns`, `knowledge_items` | **Defer** | Authoring-conversation features (Stage 4+). |
| `jobs`, `ai_calls` | **Defer; replace with one `ai_operations` table when AI authoring starts** | Not justified until an AI feature exists. `jobs` as a Postgres queue is a hosting question (Q-32). |
| `readers, follows, subscriptions, saved, notifications, entitlements, organisations, members` | **Out of scope** | Future. Hooks left: capability-by-table, ownership helper functions. |

**The 15 block types are not tables.** Content is one JSONB `document` per revision. [Proposed D-005]

## 2. Conventions

- **Schemas.** `public` holds tables and the API-callable functions (the schema Supabase exposes by default; confirm in the local stack). `private` holds helper functions and trigger functions and is **not exposed** to the API. A narrow `ai_api` schema is created only with AI authoring.
- **Keys.** `uuid` primary keys, `gen_random_uuid()` defaults. Time columns are `timestamptz`, default `now()`. Email columns use `citext` and are lower-cased and trimmed by the function that writes them.
- **Grants (deny by default).** On existing Supabase projects, new `public` tables can start with all four privileges granted to `anon`, `authenticated` and `service_role` [V-4]. **Every migration therefore begins each table with `REVOKE ALL … FROM anon, authenticated, service_role`** and then grants only what the table's section below lists. `service_role` bypasses RLS but **not** privileges, so revoking its write privileges on `approvals`, `publications`, `published_experiences` and `revisions` (update/delete) means even a leaked secret key cannot forge an approval through the table API. [Rec D-048] (The Postgres owner role can still do anything; see identity §8.3.)
- **RLS.** `ENABLE` and `FORCE ROW LEVEL SECURITY` on every table. One policy per operation per role, each with an explicit `TO` clause; `auth.uid() IS NOT NULL` explicit; helpers wrapped as `(select private.is_active_publisher())`; every column referenced by a policy is indexed [V-4].
- **Views.** None are exposed. If one is ever added: `WITH (security_invoker = true)` (Postgres 15+; version [U-4]) and a test.
- **Functions.** `SECURITY DEFINER`, `SET search_path = ''`, objects schema-qualified, `REVOKE EXECUTE … FROM PUBLIC`, then `GRANT EXECUTE` to named roles only. Each function re-checks the caller itself; none trusts an argument for identity.
- **Time-ordered rows** use `created_at` plus the key, never relying on insertion order.
- **No document content in audit rows or logs.**

## 3. Helper functions (private schema)

| Function | Returns | Rule |
|---|---|---|
| `private.current_publisher_id()` | `uuid` or null | `auth.uid()` if a `publishers` row exists with `status='active'`, else null |
| `private.is_active_publisher()` | `boolean` | `current_publisher_id() IS NOT NULL` |
| `private.is_admin()` | `boolean` | active `admins` row for `auth.uid()` **and** JWT `aal = 'aal2'` [V-9] |
| `private.owns_experience(id uuid)` | `boolean` | `is_active_publisher()` and `experiences.publisher_id = auth.uid()` |
| `private.can_edit_experience(id uuid)` | `boolean` | today equals `owns_experience`; the **only** place to change when organisations arrive |

## 4. API-callable functions (public schema)

| Function | Callable by | Does | Checks inside the function |
|---|---|---|---|
| `create_experience(p_slug, p_kind, p_document)` | `authenticated` | inserts experience (owner = caller), revision seq 1, head pointer | active publisher; slug format, not reserved, unique; document shape gate; size cap |
| `save_revision(p_experience_id, p_expected_parent, p_document, p_note, p_restored_from)` | `authenticated` | appends a revision; updates head and derived title | owner; not held-for-archive; **row lock**; `p_expected_parent = head_revision_id` else conflict; shape gate; size cap; if `p_restored_from` set, document is copied from that revision of the same experience |
| `approve_revision(p_revision_id)` | `authenticated` | inserts one approval | `auth.uid()` not null; owner; a **passing** attestation exists for this revision's `content_hash`; no existing approval; experience not held |
| `publish_revision(p_revision_id)` | `authenticated` | closes any live publication (`superseded`), inserts publication, upserts the public projection, locks the slug | owner; an approval exists; experience not held; active publisher re-checked after the lock |
| `unpublish_experience(p_experience_id, p_note)` | `authenticated` | marks the live publication unpublished, deletes the public row | owner (admins use `admin_takedown`) |
| `admin_takedown(p_experience_id, p_reason_code, p_note)` | `authenticated` | unpublishes with `actor_kind='admin'` and sets `held_at` so the owner cannot immediately republish | `is_admin()` (aal2); reason code allow-list; note required |
| `set_experience_hold(p_experience_id, p_held, p_note)` | `authenticated` | lifts or sets the hold | `is_admin()` |
| `create_invite(p_email, p_ttl_days)` / `revoke_invite(p_invite_id)` | `authenticated` | admin invitation management | `is_admin()`; ttl 1–30 days; one pending per email |
| `redeem_invite()` | `authenticated` | creates `publishers` row for the caller and marks the invite redeemed | **no arguments**; uid and verified email read from `auth.users`; invite pending and unexpired; row lock for single use |
| `set_publisher_status(p_publisher_id, p_status, p_reason)` | `authenticated` | active ↔ suspended / revoked | `is_admin()`; reason required |
| `record_event(p_experience_id, p_event)` | `anon`, `authenticated` | increments a daily counter | experience is live; event in allow-list |
| `record_validation(p_revision_id, p_passed, p_validator_version, p_errors)` | **`validator_service` only** | appends an attestation | the revision exists; recomputes nothing client-supplied; **not** callable by `authenticated` or `anon` [U-6] |

Every row that writes also inserts an `audit_events` row **in the same transaction** (so an action without its audit record cannot commit). Function bodies are written in the implementation increments, not here.

## 5. Tables

Legend for **CRUD**: C create, R read, U update, D delete; "fn" means only through the named function (direct DML is revoked). "own" = rows the caller owns via `owns_experience` or `id = auth.uid()`.

### 5.1 `admins` — private

| | |
|---|---|
| **Purpose** | Which authenticated users are administrators. Separate from `publishers`. |
| **Columns** | `user_id uuid` · `status text` (`active` \| `removed`) · `created_at` · `created_by uuid` (null for the bootstrap row) · `removed_at` |
| **PK / FK** | PK `user_id` · FK `user_id → auth.users(id) ON DELETE RESTRICT` |
| **Unique / indexes** | PK only; partial index on `status='active'` |
| **Public / private** | Private |
| **CRUD by role** | anon: none · publisher: none · admin (aal2): R · AI: none · service/owner: managed by a SQL runbook (identity §8.2), **not** an API |
| **RLS** | SELECT for `authenticated` where `private.is_admin()`; no INSERT/UPDATE/DELETE policy and no grants to API roles |
| **Personal data** | A user id only (email stays in `auth.users`) |
| **Retention** | Rows kept for the life of the account; `removed` rows kept for the audit trail |

### 5.2 `publishers` — public columns (limited) + private

| | |
|---|---|
| **Purpose** | The approved publisher identity; ownership anchor. Created only by `redeem_invite()`. |
| **Columns** | `id uuid` · `handle citext` · `display_name text` · `bio text` · `status text` (`active` \| `suspended` \| `revoked`) · `status_reason text` · `status_changed_at` · `status_changed_by uuid` · `created_at` · `updated_at` |
| **PK / FK** | PK `id` = `auth.users.id` · FK `id → auth.users(id) ON DELETE RESTRICT` |
| **Unique / indexes** | UNIQUE `handle` (format and reserved-word CHECK); index `status` |
| **Public / private** | **Public columns:** `id`, `handle`, `display_name`, `bio` (column-level grant to `anon` + policy `status='active'`). **Private:** `status*`, timestamps. **No email column.** |
| **CRUD by role** | anon: R public columns of active rows · publisher: R own row (all columns), U own `display_name`, `bio` · admin: R all via `set_publisher_status` effects; U status via fn · AI: none |
| **RLS** | `anon` SELECT where `status='active'`; `authenticated` SELECT own row; UPDATE own row with column grant limited to `display_name`, `bio`; admin SELECT policy `is_admin()` (needed for the invite/suspend screens; no draft content here); no INSERT/DELETE grants |
| **Personal data** | Display name, bio, handle: chosen by the publisher for public display. The `id` is the Auth user id and is publicly visible through `published_experiences.publisher_id`; it is not a credential (alternative: a separate public id, rejected as extra complexity). |
| **Retention** | Kept while any publication exists. Erasure/export is an admin-run process under Q-36; removal is blocked while publications exist unless they are taken down first. Retention periods need counsel (plan §6). |

### 5.3 `invites` — private

| | |
|---|---|
| **Purpose** | Authorises one email to become a publisher. **No token.** |
| **Columns** | `id` · `email citext` · `status text` (`pending` \| `redeemed` \| `revoked`) · `created_by uuid` · `created_at` · `expires_at` · `redeemed_by uuid` · `redeemed_at` · `revoked_by uuid` · `revoked_at` |
| **PK / FK** | PK `id` · FKs `created_by → admins(user_id)`, `redeemed_by → auth.users(id)` |
| **Unique / indexes** | **Partial UNIQUE (`email`) WHERE `status='pending'`**; index `(status, expires_at)`; CHECK `expires_at ≤ created_at + 30 days` |
| **Public / private** | Private |
| **CRUD by role** | anon: none · publisher: none (not even their own, to avoid leaking state) · admin (aal2): R, C and revoke via fn · AI: none |
| **RLS** | SELECT where `private.is_admin()`; writes only through `create_invite`, `revoke_invite`, `redeem_invite` |
| **Personal data** | **An email address** of a not-yet-registered person |
| **Retention** | Pending: until expiry. Redeemed/revoked/expired: delete or anonymise the email after a short period (proposal: 90 days; Q-36, needs counsel) keeping the row's counts for audit |

### 5.4 `audit_events` — private, append-only

| | |
|---|---|
| **Purpose** | Accountability for identity, invitation, approval, publication and admin actions. |
| **Columns** | `id` · `at` · `actor_kind text` (`publisher` \| `admin` \| `ai` \| `system` \| `anonymous`) · `actor_id uuid` · `action text` · `subject_type text` · `subject_id uuid` · `details jsonb` (codes and ids only) · `request_id text` · `aal text` |
| **PK / FK** | PK `id` · no FK on `actor_id` (survives account removal) |
| **Unique / indexes** | indexes `(at desc)`, `(subject_type, subject_id, at desc)`, `(actor_id, at desc)` |
| **Public / private** | Private |
| **CRUD by role** | anon, publisher, AI: none · admin (aal2): R · writes: only by database functions (and the server for auth events); **no UPDATE or DELETE for anyone**, enforced by trigger and revoked grants |
| **RLS** | SELECT where `private.is_admin()`; no write policies |
| **Personal data** | Actor ids; never email, never document content. `details` is validated against an allow-list of keys. |
| **Retention** | Proposal: 24 months online, then archive or delete; counsel to confirm |

### 5.4a Auth-level events

Sign-in successes and failures are logged by Supabase Auth itself and by the application server. Whether Supabase's Auth logs are retained long enough and exportable on the plan chosen was **not verified** [U-9]; the application's `audit_events` is the authoritative record for *authorisation* events.

### 5.5 `topics` — public

| | |
|---|---|
| **Purpose** | A small curated taxonomy. |
| **Columns** | `id` · `slug citext` · `title` · `description` · `position int` · `created_at` · `updated_at` |
| **PK / FK / unique** | PK `id`; UNIQUE `slug` |
| **Public / private** | Public |
| **CRUD by role** | anon, publisher: R · admin (aal2): C/R/U/D · AI: none |
| **RLS** | SELECT `TO anon, authenticated` `USING (true)`; write policies `is_admin()` |
| **Personal data** | None |
| **Retention** | Indefinite |

### 5.6 `experiences` — private

| | |
|---|---|
| **Purpose** | One experience: owner, reserved slug, pointer to the working head. **The unit of ownership.** |
| **Columns** | `id` · `publisher_id` · `slug citext` · `kind text` (`explainer` \| `data-story`) · `language text` · `title text` (derived from the head document by `save_revision`; never client-supplied) · `head_revision_id uuid` · `slug_locked_at` · `held_at` · `held_reason` · `archived_at` · `created_at` · `updated_at` |
| **PK / FK** | PK `id` · FK `publisher_id → publishers(id) ON DELETE RESTRICT` · FK `head_revision_id → revisions(id)` (nullable, `DEFERRABLE INITIALLY DEFERRED` to break the creation cycle) |
| **Unique / indexes** | UNIQUE `slug` (reserved forever, including after unpublish; seeded with the existing file-based slugs and a reserved-word list); index `(publisher_id, updated_at desc)` |
| **Public / private** | **Private.** The public never reads this table. |
| **CRUD by role** | anon: none · publisher: R own, **C via `create_experience`**, U own limited columns (`archived_at`; topics via `experience_topics`) · admin: none on content (holds via fn) · AI: none now |
| **RLS** | SELECT/UPDATE `TO authenticated` `USING (private.owns_experience(id))`; UPDATE column grant excludes `publisher_id`, `slug`, `kind`, `title`, `head_revision_id`, `held_*`, `slug_locked_at`; no INSERT/DELETE grant. Hard delete is not offered; never-published drafts are archived. |
| **Personal data** | None directly (the title and slug are content) |
| **Retention** | Kept while any publication or revision exists. Archived drafts: proposal delete after 12 months (Q-36) |

**No stored lifecycle status** (`draft/in_review/published/unpublished` in `backend-architecture.md`). A denormalised status can drift from the publication rows. Status is *derived*: `published` = a live `publications` row exists; `unpublished` = had publications, none live; `draft` = never published. `in_review` is dropped for the alpha because the owner reviews and approves their own work (Q-39 asks whether a second reviewer is wanted). This **amends** the Phase 0 conceptual list and is a recommendation (D-048), not an accepted change.

### 5.7 `experience_topics` — private (owner), copied to the public projection at publish

| | |
|---|---|
| **Columns** | `experience_id` · `topic_id` |
| **PK / FK** | PK `(experience_id, topic_id)` · FKs to `experiences`, `topics` |
| **Indexes** | `(topic_id)` |
| **CRUD** | publisher: C/R/D own · admin none · anon none |
| **RLS** | all operations `USING/WITH CHECK (private.owns_experience(experience_id))` |
| **Personal data / retention** | None; follows the experience |

### 5.8 `revisions` — private, **append-only**

| | |
|---|---|
| **Purpose** | An immutable saved state of an experience's document. [Proposed D-005, content-model] |
| **Columns** | `id` · `experience_id` · `seq int` · `parent_id` · `author_kind text` (`human` \| `ai`) · `created_by uuid` (the publisher; for AI, the requester) · `schema_version int` · `document jsonb` · `content_hash text` (sha-256 of the stored document, computed in the database) · `note text` (≤ 280) · `restored_from uuid` · `created_at` |
| **PK / FK** | PK `id` · FKs `experience_id → experiences(id) ON DELETE RESTRICT`, `parent_id → revisions(id)`, `created_by → publishers(id)`, `restored_from → revisions(id)` |
| **Unique / indexes** | UNIQUE `(experience_id, seq)`; UNIQUE `(id, experience_id)` (for composite FKs); index `(experience_id, seq desc)`; index `(content_hash)` |
| **Constraints** | `document` is a JSON object; `octet_length(document::text) ≤ 1 MiB` (proposal; the largest current document is far below this, to be measured); **shape gate** = `schemaVersion` present and equal to `schema_version`, top-level keys within the known set, every block `type` within the 15 known types. The shape gate is **not** the full Zod validation (see 5.9). |
| **Immutability** | `BEFORE UPDATE OR DELETE` trigger raises for every role; no UPDATE/DELETE grants. |
| **Public / private** | **Private**; `anon` has no grant |
| **CRUD by role** | publisher: R own, C via `save_revision` · admin: **none** · AI: C via `ai_api.create_revision` later; none now |
| **RLS** | SELECT `USING (private.owns_experience(experience_id))`; no write policies |
| **Personal data** | May contain whatever the publisher writes, including personal data of third parties; treated as publisher content (plan §6 questions) |
| **Retention** | Kept while the experience exists. **Volume:** every explicit save creates a row; autosave granularity is open (Q-35). Free-tier database size is 500 MB [V-8]; revision sizes and counts must be measured before real use. |

### 5.9 `revision_validations` — private, **append-only**

| | |
|---|---|
| **Purpose** | Attests that the stored document passed the full Zod validation (and which validator version), so approval does not rely on the publisher's own claim. |
| **Columns** | `id` · `revision_id` · `content_hash` · `validator_version text` · `passed boolean` · `errors jsonb` (paths and codes, no content) · `checked_at` |
| **PK / FK / unique** | PK `id` · FK `revision_id → revisions(id)` · UNIQUE `(revision_id, validator_version)` |
| **Public / private** | Private |
| **CRUD by role** | C: **`validator_service` only** via `record_validation` · publisher: R own (to show errors) · admin none · AI none |
| **RLS** | SELECT via the owning experience; no write policy |
| **Personal data / retention** | None; follows the revision |

A revision that fails validation **is stored** (so work is not lost mid-edit) with `passed = false`; it can be previewed by its owner, cannot be approved, and cannot be published (T-L02).

### 5.10 `approvals` — private, **append-only**

| | |
|---|---|
| **Purpose** | The record that a human owner explicitly approved **this** revision. [Proposed D-018] |
| **Columns** | `revision_id` · `experience_id` · `approved_by uuid` · `approved_at` · `content_hash` · `approved_via text CHECK = 'human_session'` · `note` |
| **PK / FK** | PK `revision_id` (one approval per revision) · FKs `(revision_id, experience_id) → revisions(id, experience_id)`, `approved_by → publishers(id)` |
| **Indexes** | `(experience_id, approved_at desc)` |
| **CRUD** | publisher: R own · C **only** via `approve_revision` · admin: none · AI: **none** (no grant, no EXECUTE) · `service_role`: none (privileges revoked) |
| **RLS** | SELECT via the owning experience; no write policies; INSERT/UPDATE/DELETE revoked from every API role |
| **Personal data / retention** | Actor id; kept for the life of the publication history |

### 5.11 `publications` — private, append-only except unpublish

| | |
|---|---|
| **Purpose** | The explicit, durable history of what became public, when, by whom, and why it stopped. |
| **Columns** | `id` · `experience_id` · `revision_id` · `slug_at_publish citext` · `published_at` · `published_by uuid` · `unpublished_at` · `unpublished_by_kind text` (`publisher` \| `admin` \| `system`) · `unpublished_by uuid` · `unpublish_reason text` (`publisher_request` \| `superseded` \| `policy` \| `legal` \| `safety` \| `error`) · `unpublish_note text` |
| **PK / FK** | PK `id` · FK `revision_id → approvals(revision_id)` (**a publication cannot exist without an approval**) · FKs `experience_id → experiences`, `published_by → publishers(id)` |
| **Unique / indexes** | **Partial UNIQUE (`experience_id`) WHERE `unpublished_at IS NULL`** (at most one live publication per experience); index `(experience_id, published_at desc)` |
| **Mutability** | Only the `unpublished_*` columns may change, and only once (trigger); never deleted |
| **CRUD** | publisher: R own · C/U only via `publish_revision`, `unpublish_experience` · admin: R **metadata** (for takedown screens), U only via `admin_takedown`; no document is stored here · AI: none |
| **RLS** | SELECT via the owning experience, plus admin SELECT `is_admin()` (no content); no write policies |
| **Personal data / retention** | Actor ids; kept indefinitely as the publication record (counsel to confirm) |

### 5.12 `published_experiences` — **public**, derived

| | |
|---|---|
| **Purpose** | The one thing the public can read. A snapshot copied at publish time, so **published content is physically separate from draft state**; a new draft cannot leak, and unpublishing deletes the row. |
| **Columns** | `experience_id` · `publication_id` · `slug citext` · `kind` · `title` · `summary` · `language` · `schema_version` · `document jsonb` · `publisher_id` · `topic_slugs text[]` · `published_at` |
| **PK / FK / unique** | PK `experience_id` · UNIQUE `publication_id` · UNIQUE `slug` · FKs `experience_id`, `publication_id`, `publisher_id` |
| **Indexes** | `(published_at desc)`; GIN on `topic_slugs` if topic pages need it |
| **Public / private** | **Public read** |
| **CRUD by role** | anon, publisher: R · **no one** writes directly; `publish_revision` upserts, `unpublish_experience`/`admin_takedown` delete · AI: none |
| **RLS** | SELECT `TO anon, authenticated` `USING (true)` — safe because the table only ever contains live content; INSERT/UPDATE/DELETE revoked from all API roles |
| **Personal data** | Publisher handle/display name reachable via `publisher_id`; whatever the publisher put in content |
| **Retention** | Row exists only while published |

**Cache note.** If public pages are later served from this table with incremental regeneration, unpublish and takedown must trigger revalidation; the acceptable delay is open (Q-42, R-4).

### 5.13 `feedback` — private, anonymous write — **provisional (Q-17, legal gate)**

| | |
|---|---|
| **Purpose** | Reader feedback on a published experience, replacing today's `localStorage` + clipboard approach. |
| **Columns** | `id` · `experience_id` · `publication_id` · `message text` (1–2000) · `answers jsonb` (bounded; the current form's questions) · `status text` (`new` \| `read` \| `handled` \| `spam`) · `created_at` |
| **PK / FK** | PK `id` · FKs `experience_id`, `publication_id` |
| **Indexes** | `(experience_id, created_at desc)` |
| **Public / private** | **Private**; anonymous *insert only* |
| **CRUD by role** | anon: C (restricted) · publisher: R and U `status` on own experiences · admin: **none by default** · AI: none |
| **RLS** | INSERT `TO anon, authenticated` with column grant `(experience_id, publication_id, message, answers)` and `WITH CHECK` that the pair matches a row in `published_experiences`; SELECT/UPDATE via `owns_experience`; no anon SELECT |
| **Personal data** | Free text may contain personal data. **No email, no IP, no user agent stored.** Optional contact detail is *not* collected in the alpha (Q-37). |
| **Retention** | Proposal: 12 months, then delete; counsel to confirm (Q-36, Q-37) |

Writes arrive through a route handler with rate limiting and an anti-automation challenge (not through the browser directly), so the abuse controls sit in front of an `anon` insert.

### 5.14 `events_daily` — aggregate-only

| | |
|---|---|
| **Purpose** | Anonymous first-party counts per experience per day. [Proposed D-022] No per-reader row exists. |
| **Columns** | `experience_id` · `day date` · `event text` (allow-list, e.g. `view`, `complete`, `feedback_opened`) · `n bigint` |
| **PK / FK** | PK `(experience_id, day, event)` · FK `experience_id` |
| **Public / private** | Private |
| **CRUD by role** | anon: **no direct access**; may EXECUTE `record_event` · publisher: R own · admin: R all (aggregates) · AI: none |
| **RLS** | SELECT via `owns_experience` or `is_admin()`; no write policies; writes only inside `record_event` |
| **Personal data** | None (no identifiers). Counts are approximate by design; they can be inflated by automation. |
| **Retention** | Indefinite (aggregates) |

### 5.15 Deferred tables (design intent only)

- **`ai_operations`** (one table replacing `jobs` + `ai_calls`): `id, kind, experience_id, requested_by, status, provider, model, prompt_version, input_tokens, output_tokens, result_revision_id, error_code, created_at`. Prompts and outputs are not stored beyond what the revision already holds (data minimisation), unless evaluation requires it and counsel agrees. Justified only when AI authoring exists.
- **`media`**: `id, publisher_id, experience_id, storage_path, mime, bytes, width, height, alt_text NOT NULL, created_at`; a private bucket for drafts and a public copy at publish; Storage policies verified at that increment [U-10]; daily database backups **exclude Storage objects** [V-8].
- **`sources` / `knowledge_items`**: only if uploaded source materials are accepted; blocked by the legal gate.

## 6. Lifecycle

### 6.1 States (derived, not stored)

```
create_experience ─► revision seq 1 (head)
        │
   edit  ▼  save_revision (parent = head, conflict-checked)
   ┌─► revision seq n  ──► record_validation (server-attested, passed / failed)
   │        │
   │   preview (owner only)
   │        │  passed only
   │        ▼
   │   approve_revision (human session) ──► approvals row (bound to content_hash)
   │        │
   │        ▼
   │   publish_revision ─► publications row + published_experiences row (live)
   │        │
   │   [new drafts continue on the head; the live row does not change]
   │        │
   └── unpublish_experience / admin_takedown ─► publication closed, public row deleted
```

| Question | Answer |
|---|---|
| Draft → revision | Every explicit save creates an immutable `revisions` row; the experience's `head_revision_id` advances. |
| Validate | After each save the server runs the full Zod validation against the *stored* document and records an attestation via `record_validation`. A failed revision is kept but cannot be approved. A document that fails the database shape gate is **rejected at save** (the shape gate is a cheap structural check, so this is a malformed request, not an editing state). |
| Preview | Owner-only, dynamic, `noindex`, `private, no-store`. Previews are reading the same renderer. |
| Review → approval | Review is the owner looking at the preview. Approval is an explicit action naming **one revision** and is bound to its content hash. There is no "approve latest". |
| Approved → published | `publish_revision(revision_id)` requires an approval row (database-enforced by FK). |
| A new draft while an older revision is live | Saving continues on the head. `published_experiences` is untouched, so the public still sees the published revision. To change what is live, approve and publish a newer revision; the old publication is closed as `superseded` in the same transaction. |
| Unpublish | Closes the publication, deletes the public row, keeps all history, reserves the slug. The experience can be republished later (a new publication) unless held. |
| Restore | Restoring an older revision **creates a new revision** (parent = current head, `restored_from` set); old revisions are never changed. It is then validated, approved and published like any other. |
| Concurrency | `save_revision` takes a row lock on the experience and requires `p_expected_parent = head_revision_id`. A mismatch returns a **conflict** (never a silent overwrite); the editor then offers to restore the divergent text as a new revision. Two tabs or a human and an AI revision cannot both advance the same head. |
| Publisher loses access mid-operation | Each function re-evaluates `private.is_active_publisher()` after taking the row lock. A suspension committed before that statement refuses the call; work already committed stays and is not rolled back; an admin may take it down. The editor shows a neutral access message and keeps unsaved text in the browser. |
| Takedown | `admin_takedown` deletes the public row, closes the publication with reason code and note, sets `experiences.held_at` so the owner cannot immediately republish (a hold must be lifted by an admin), notifies the owner, and writes the audit event. |
| Publication-history audit | `publications` (what, when, who, why it ended) and `audit_events` (every approval, publication, unpublish, takedown, hold) together; both written in the function's transaction. |
| "Published stays separate from draft" | The public reads only `published_experiences`, a copy made at publish time. No public policy or grant touches `experiences` or `revisions`. |

### 6.2 Schema evolution

Content `schemaVersion` changes follow `content-architecture.md`: additive changes do not bump the version; breaking changes need a pure migrate function and documents are migrated forward on read. Stored revisions are never rewritten (they are immutable); `revisions.schema_version` records which version a document was written at, and the renderer migrates it on read. Re-validation of an old revision at approval time uses the validator version current at that time (recorded in `revision_validations`).

## 7. RLS summary

| Table | anon | authenticated (publisher) | admin (aal2) | AI | service_role (secret key) |
|---|---|---|---|---|---|
| `admins` | — | — | R | — | no table privileges needed |
| `publishers` | R public cols, active only | R/U own row (limited cols) | R | — | — |
| `invites` | — | — | R, C/revoke via fn | — | — |
| `audit_events` | — | — | R | — | insert only via fns |
| `topics` | R | R | CRUD | — | — |
| `experiences` | — | R/U own (limited cols); C via fn | — (holds via fn) | — | — |
| `experience_topics` | — | CRUD own | — | — | — |
| `revisions` | — | R own; C via fn | — | C via `ai_api` (later) | UPDATE/DELETE revoked |
| `revision_validations` | — | R own | — | — | C via `validator_service` only |
| `approvals` | — | R own; C via fn | — | **none** | **INSERT revoked** |
| `publications` | — | R own | R metadata | **none** | **INSERT/UPDATE revoked** |
| `published_experiences` | **R** | R | — | — | **writes revoked** |
| `feedback` | C (restricted) | R/U own | — | — | — |
| `events_daily` | via `record_event` | R own | R all | — | — |

## 8. Migration plan

Plain SQL migrations in `supabase/migrations/`, forward-only, using the CLI workflow [V-13]: `supabase migration new`, `db reset` locally, CI applies to staging then production [V-13]. Each migration contains the DDL, the `REVOKE`/`GRANT`, `ENABLE`+`FORCE` RLS, the policies **and** its pgTAP test file; a migration without its negative tests is not merged. Expand → migrate → contract for any later change (architecture-overview, development-workflow).

| # | Migration | Increment |
|---|---|---|
| 0001 | `private` schema, helper functions (stubs), baseline grants hygiene, audit table, trigger to make a table append-only | 3.1 |
| 0002 | `admins`, `publishers`, `invites` + `redeem_invite`, `create_invite`, `revoke_invite`, `set_publisher_status` | 3.1 |
| 0003 | `topics`, `experiences`, `experience_topics`, `revisions`, `revision_validations`, `approvals`, `publications`, `published_experiences` + lifecycle functions | 3.2 |
| 0004 | `feedback`, `events_daily`, `record_event` | 3.6 |
| later | `media`, `ai_operations`, `ai_api` schema | own increments |

**Seed data** is synthetic only (two publishers, one admin, fixture experiences). No production data and no real email addresses in `seed.sql`. **Rollback** is a forward fix; a destructive migration is never auto-run in production, and production needs a backup option that the free plan lacks [V-8]. Checkpoints are in the implementation plan.

## 9. Open items specific to the data model

Slug rules and reserved words; autosave and revision granularity (Q-35); retention periods (Q-36, needs counsel); feedback shape (Q-37); whether a second reviewer is wanted (Q-39); import of the two existing file-based experiences into the database (they would belong to an editorial publisher record; not in Stage 3 scope).
