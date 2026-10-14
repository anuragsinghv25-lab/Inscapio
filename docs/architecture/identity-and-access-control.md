# Identity and access control

> **Status:** Stage 3 design · **Proposed** (nothing here is built, connected or tested) · written 13 Oct 2026.
> **Scope:** who the principals are, what each may do, how identity and ownership are established and enforced, and what is deliberately left out. Companion documents: [`supabase-data-model.md`](./supabase-data-model.md) (tables, RLS), [`authentication-and-rls-test-plan.md`](./authentication-and-rls-test-plan.md) (tests), [`stage-3-implementation-plan.md`](./stage-3-implementation-plan.md) (order of work, environments, gates).

## 0. How to read the labels

Every material statement carries one of these provenance labels. This document never silently replaces an existing decision.

| Label | Meaning |
|---|---|
| **[Accepted D-xxx]** | Already in [`DECISIONS.md`](../DECISIONS.md) as Accepted. Not changed here. |
| **[Proposed D-xxx]** | In `DECISIONS.md` as Proposed in Phase 0 (pending owner review). Kept, sometimes refined; refinements are called out. |
| **[Open Q-xx]** | An open question in [`OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md). |
| **[Rec D-045…D-053]** | A **new recommendation** made in this milestone. Appended to `DECISIONS.md` as *Proposed*. Not approved. |
| **[V-n]** | A **vendor fact verified** against the vendor's current documentation on 13 Oct 2026 (Appendix A). |
| **[Unverified U-n]** | A vendor behaviour that was **not** confirmed and must be checked in a spike before it is relied on (Appendix B). |

Nothing in this milestone was executed against Supabase. No security property described here has been tested; the test plan describes tests that **will** be written.

## 1. Sources of truth read

Read in full or in the relevant parts: `CLAUDE.md`, `DECISIONS.md`, `OPEN-QUESTIONS.md`, `architecture/{phase-2-readiness,backend-architecture,frontend-architecture,content-architecture,architecture-overview,ai-architecture}.md`, `product/{mvp-scope,users}.md`, `ux/{information-architecture,publisher-journey,content-model}.md`, `engineering/development-workflow.md`. The app was inspected as it stands: there is **no backend**; `src/content/load.ts` reads `experience.json` files from disk and validates them with Zod; routes are statically generated; feedback and reading preferences live only in the reader's `localStorage`.

### 1.1 Existing decisions this design builds on

| Existing | Status | How it is used |
|---|---|---|
| D-005 Experiences are JSON documents validated by Zod | Proposed | Revisions store the document as JSONB; the 15 block types are **not** tables. |
| D-008 Closed-alpha MVP (few invited publishers, public anonymous readers) | Proposed | Sets the user population; invite-only access. |
| D-010 Supabase behind a repository layer | Proposed | Supabase Auth + Postgres; all data access through one server-side layer. |
| D-012 Three environments (local / preview / production) | Proposed | Refined in the implementation plan §3. |
| D-018 Human approval enforced in the data layer; AI cannot write approvals/publications | Proposed | Made concrete in §7 (AI) and `supabase-data-model.md` §5. |
| D-019 One app | Proposed | `/studio`, `/admin` stay in this Next.js app. |
| D-022 First-party aggregate-only analytics | Proposed | `events_daily`; no per-reader rows. |
| D-041 (on `main`); D-043, D-044 (Stage 2 PRs #5/#6, which were merged into stacked branches and were **not on `main`** when this was written, so they are not in this branch's `DECISIONS.md`) | Accepted | Unchanged. The public reader shell stays free of any auth state. |
| Q-16 "Whose Body Is It?" review | Open | **Release blocker** (implementation plan §6.2). |
| Q-17, Q-23, Q-24…Q-30 | Open | Referenced where they bind this design. |

### 1.2 What existing docs leave open and this milestone proposes

The conceptual table list in `backend-architecture.md` is a good skeleton, but it does not say: where roles live, how ownership is enforced, how a stale session is neutralised, how invitations prove email ownership, how the public read path is separated from draft data, or how the AI credential is made unable to approve. Those are the new recommendations (D-045…D-053), each labelled below.

## 2. Principles

1. **Ownership is a row fact, roles are a table fact; neither lives in the client.** [Rec D-045]
2. **Three layers, none sufficient alone:** route/UI guard (convenience) → server-side authorisation in a data-access layer → Postgres policies and functions (the last line). Hidden navigation is not access control. [Rec D-047]
3. **Deny by default.** A new table has RLS enabled and no grants until a policy and test exist. [V-6] [Proposed D-010 / backend-architecture]
4. **Approvals and publications have exactly one write path**, a database function that requires a human session and ownership. [Proposed D-018; Rec D-048]
5. **Admin is operational, not omniscient.** Administering the platform does not grant reading anyone's drafts. [Rec D-050]
6. **The public reads a separate projection**, never the tables that hold drafts. [Rec D-048]
7. **Secrets stay on the server; the browser holds only the publishable key.** [V-5]
8. **Minimise personal data.** The platform stores no reader accounts, no reader identifiers, and no email address outside Supabase Auth and the invitation row. [Proposed D-022; Rec]

## 3. Principals

### 3.1 Anonymous reader (Phase: MVP)

The default and by far the most common principal. No account, no sign-in, no cookie.

- May read **published** experiences, the home page, topics and public publisher profiles.
- May interact (all interaction is client-side state today; nothing is stored server-side).
- May submit **permitted feedback** and trigger **aggregate event counts**, only for a live published experience, only through narrow, rate-limited paths (P-05, P-06).
- Is a real Postgres role (`anon`), not "no role". Everything in the public schema is denied to `anon` unless explicitly granted.
- **Public pages set no cookies and do not read the session**, so they stay statically cacheable and a refreshed auth cookie can never be cached and served to someone else [V-3]. The public header shows no signed-in state. [Rec D-047]

### 3.2 Registered reader (Phase: Future — not built)

Out of scope for Stage 3 and for the MVP (`mvp-scope.md`; backend-architecture "later" tables). The model is prepared, not built:

- A future reader signs in with the **same Supabase Auth** identity layer. A new `readers` table keyed by `auth.users.id` (like `publishers`) would hold reader-specific data, and `follows`, `saved`, `notifications` would reference it.
- **Capabilities are never inferred from "has an auth user".** Because every authorisation helper checks a *specific table* (`publishers`, `admins`), a reader account gives no publisher or admin access by construction. This is the main reason roles are table facts, not JWT facts (D-045).
- **Reader → publisher** (Future): an admin creates an invite for the reader's email (the same `invites` flow). Redeeming it inserts a `publishers` row for the *existing* `auth.users.id`. One person, one auth identity, two capability rows. No data migration.
- Anonymous reading never requires or is degraded by this; the public site stays account-free by default.
- Not decided: whether readers may self-register, billing, subscriptions (explicitly out of scope).

### 3.3 Publisher (Phase: MVP, invited)

An invited, authenticated person with a `publishers` row whose `status = 'active'`.

May: manage **their own** profile; create experiences; edit **their own** drafts; save revisions; preview; **approve** and **publish** experiences they own; **unpublish** their own; read **their own** feedback and analytics.

May not, and the database refuses: read or edit another publisher's drafts, revisions, feedback, analytics or ownership; invite anyone; change their own status; write approvals or publications by any path other than the human-session functions; touch the public projection directly.

**Ownership model: one publisher per experience** (`experiences.publisher_id`). To avoid blocking future organisations:

- Every policy and function asks `private.can_edit_experience(experience_id)` / `private.owns_experience(experience_id)`, never `publisher_id = auth.uid()` inline. Adding `experience_members(experience_id, publisher_id, role)` later changes the **body of two helper functions**, not every policy. [Rec D-045]
- `publishers.id` equals `auth.users.id`. An `organisations` table would be added beside it later, not instead of it.
- No `team`, `role` enum or permission-set tables now (explicitly out of scope).

### 3.4 Administrator (Phase: MVP; one or two people)

An administrator is a row in `admins` (`status = 'active'`). It is **separate** from being a publisher; one person may hold both rows and the two are independent.

Minimum capabilities, and nothing more:

| Capability | Notes |
|---|---|
| Create and revoke invitations | P-21, P-22 |
| Suspend / reinstate / revoke a publisher's access | P-23 |
| Curate topics (and later the home page) | P-24 |
| Unpublish content under policy (takedown) | P-25; reason code and note mandatory |
| Read aggregate operational information and the audit log | P-26, P-27 |

**Admin does not imply access to private content.** There is no policy giving `admins` select on `experiences`, `revisions`, `approvals`, `feedback` or any draft. A takedown works on the public projection and the publication record only. Reading a private draft is **not an application capability**; if ever legally required it is an out-of-band, owner-level, logged procedure (§8.3). [Rec D-050]

Control matrix for admin operations:

| Operation | MFA (aal2) | Recent re-auth | Typed confirmation | Reason required | Audit event |
|---|---|---|---|---|---|
| Create invite | Yes | — | — | — | `invite.created` |
| Revoke invite | Yes | — | — | — | `invite.revoked` |
| Suspend / revoke publisher | Yes | Yes (≤ 15 min, Rec) | Yes | Yes | `publisher.suspended` / `publisher.revoked` |
| Reinstate publisher | Yes | Yes | Yes | Yes | `publisher.reinstated` |
| Takedown (admin unpublish) | Yes | Yes | Yes | Yes (code + note) | `publication.taken_down` |
| Curate topics | Yes | — | — | — | `topic.changed` |
| Read audit log / aggregates | Yes | — | — | — | (reading the audit log is itself logged: `audit.read`) |
| Grant / remove admin | **Not an app operation** (§8.2) | — | — | — | manual audit row |

MFA for admins from day one is already in `backend-architecture.md` [Proposed]. TOTP is a supported Supabase factor and policies can require the `aal2` claim [V-9]. **Whether MFA is available on the plan in use is unverified** [Unverified U-8]. The 15-minute re-auth window is a recommendation, not a Supabase feature.

### 3.5 AI service (Phase: later; the invariant is locked in Stage 3)

A restricted **service identity**, never a human session and never the Supabase secret key.

- May: read the context for an experience a publisher has asked it to work on; **create drafts and revisions** (`author_kind = 'ai'`) on that publisher's behalf.
- May not: approve, publish, unpublish, read other publishers' private data, invite, read feedback or analytics, or call any function outside its own narrow schema.
- **Credential:** a dedicated Postgres login role (`ai_service`) with `USAGE` only on a narrow `ai_api` schema and `EXECUTE` only on the functions there. It has **no grant** on `approvals` or `publications`. A Supabase *secret* key cannot be used for this: it maps to `service_role`, which has `BYPASSRLS` [V-5], so a second secret key limits nothing at the database. The AI role is therefore a custom role reached over a direct or pooled connection. Whether custom roles and that connection path work on the chosen Supabase plan and from the chosen host is **unverified** [Unverified U-6]; if it fails, the fallback is a separate AI worker using a *dedicated database*-level function boundary, and the design is revisited before any AI code is written.
- **Credentials are distinct from human sessions:** different secret, different role, different environment variable, never present in the browser or the Next.js request path for a human action. [Proposed D-018; Rec D-049]
- The AI path adds an `ai_operations` record per request (who asked, for which experience, what was produced). It is **justified only when AI authoring is built** and is **not** part of Stage 3.

## 4. Role, ownership and where each lives

| Concept | Lives in | Never lives in |
|---|---|---|
| "Is this person an admin?" | `admins` row, `status='active'`, checked inside the database by `private.is_admin()` | JWT claims, `user_metadata`, `app_metadata`, a cookie, the client |
| "Is this person an approved publisher?" | `publishers` row, `status='active'`, checked on **every** query by `private.is_active_publisher()` | the same |
| "Does this person own experience X?" | `experiences.publisher_id` via `private.owns_experience(X)` | request parameters |
| "Is this a human session?" | `auth.uid() IS NOT NULL` in the database (the caller holds a Supabase Auth JWT) | a flag in the request body |
| "Has MFA been completed?" | the `aal` claim in the verified JWT (`aal2`) [V-9] | the client |

**Why not JWT role claims?** A custom access-token hook can add claims [V-10], but a claim is a copy that stays valid until the token expires, so a suspended publisher would keep access until expiry. `user_metadata` is editable by the signed-in user and must never be used for authorisation [V-4]. Reading the status from the table on each query makes revocation immediate for data access even while the JWT is still valid. The cost is one indexed lookup per request, which is acceptable at alpha scale and cached per statement with `(select …)` [V-4]. [Rec D-045]

## 5. Permission matrix

**Columns.** *Principal*: who may. *Ownership*: the row condition (role is not ownership). *AuthN*: authentication required. *App check*: the application-layer check (data-access layer / server action). *RLS / DB*: the database enforcement that holds even if the app is bypassed. *Audit*: event written, in the same transaction as the action where it is a database function. *Tests*: IDs from [`authentication-and-rls-test-plan.md`](./authentication-and-rls-test-plan.md).

Common to every row: **a client-supplied role, publisher id or status is ignored**; the server derives identity from the verified session and the database from `auth.uid()` (T-S08, T-S04). "Active publisher" always means `publishers.status = 'active'`, checked per query. Routes under `/studio` and `/admin` are never the only guard.

### 5.1 Public and anonymous

| ID | Operation | Principal | Ownership | AuthN | App check | RLS / DB | Audit | Tests |
|---|---|---|---|---|---|---|---|---|
| P-01 | Read a published experience | anon, anyone | none | No | Read only `published_experiences` by slug; fail closed if Zod validation fails | `anon` SELECT on `published_experiences` only; row exists only while published | none | T-A01, T-A04, T-L01 |
| P-02 | Read home / topics / public profile | anon, anyone | none | No | public projection and public columns only | column-level grants + `status='active'` policy on `publishers`; `topics` public | none | T-A01, T-A05 |
| P-03 | Read a draft or unpublished experience | owner publisher only | `publisher_id` = caller | Yes | `requireActivePublisher()` + owner lookup | policy `owns_experience`; **no** `anon` policy or grant on `experiences` | none | T-A02, T-P02, T-S01 |
| P-04 | Read revisions | owner publisher only | via parent experience | Yes | as P-03 | policy via `owns_experience`; **no** `anon` grant on `revisions`; admins have no policy | none | T-A03, T-P04, T-D03 |
| P-05 | Submit feedback | anon, anyone | n/a | No | route handler: Zod, size cap, rate limit, anti-automation challenge | `anon` INSERT limited to listed columns; `WITH CHECK` the target is a live publication; no `anon` SELECT/UPDATE/DELETE | none (volume); abuse events logged | T-A06, T-A07 |
| P-06 | Record an aggregate event | anon, anyone | n/a | No | route handler: allow-list of event names, rate limit | `anon` EXECUTE only on `record_event()`; no direct write to `events_daily` | none | T-A08, T-A09 |

### 5.2 Publisher

| ID | Operation | Principal | Ownership | AuthN | App check | RLS / DB | Audit | Tests |
|---|---|---|---|---|---|---|---|---|
| P-07 | First sign-in and invite redemption | invited person | email on the pending invite equals the **verified** auth email | Yes (magic link) | `redeem_invite()` called with **no arguments** | function derives uid and email from the database; creates the `publishers` row atomically | `invite.redeemed` | T-I04…T-I09 |
| P-08 | Update own profile | active publisher | `publishers.id = auth.uid()` | Yes | Zod on display name and bio | UPDATE policy on own row; column grant excludes `status`, `handle` (immutable in alpha), `id` | `publisher.profile_updated` | T-P11 |
| P-09 | Create an experience | active publisher | creator becomes owner | Yes | Zod; slug format and reserved list | `create_experience()` sets `publisher_id = auth.uid()`; client value ignored; direct INSERT revoked | `experience.created` | T-P01, T-P13 |
| P-10 | Update experience metadata (topics, archive) | owner | owner | Yes | Zod | UPDATE policy via `owns_experience`; `publisher_id`, `slug` after first publish, `head_revision_id` not writable by clients | `experience.updated` | T-P03, T-P13, T-L08 |
| P-11 | Save a revision (edit, restore) | owner | owner | Yes | Zod validation; send `expected_parent_revision_id` | `save_revision()` locks the experience row, checks owner, status and parent equals head, inserts append-only | `revision.saved` is **not** audited per save (the row is the record); `revision.restored` is | T-P05, T-P14, T-L06, T-L07 |
| P-12 | Read own drafts and revisions | owner | owner | Yes | DAL | policy `owns_experience` | none | T-P12 |
| P-13 | Preview | owner | owner | Yes | route is dynamic, `noindex`, `Cache-Control: private, no-store`; fetch by owned id | same policies as P-12 | none | T-P16 |
| P-14 | Approve a revision | owner | owner **and** a validated revision | Yes (human session; `getUser()` re-check) | server action: explicit user action, shows the exact revision | `approve_revision()`: `auth.uid()` not null, owner, valid-for-this-hash, not already approved; **only** write path; direct INSERT revoked | `revision.approved` | T-P06, T-P15, T-L02, T-L04, T-X01 |
| P-15 | Publish an approved revision | owner | owner | Yes (human) | server action; then revalidate the public cache | `publish_revision()`; FK `publications.revision_id → approvals`; single live publication per experience; writes the public projection | `experience.published` | T-P07, T-L03, T-L05, T-L09, T-X02 |
| P-16 | Unpublish own | owner | owner | Yes | server action; then revalidate | `unpublish_experience()` (owner or admin path); sets `unpublished_at`, deletes the public row | `experience.unpublished` | T-P08, T-L01, T-L11 |
| P-17 | Read own feedback; mark handled | owner of the experience | owner | Yes | DAL | SELECT/UPDATE (status only) via `owns_experience`; no INSERT/DELETE | none | T-P09, T-P17 |
| P-18 | Read own analytics | owner | owner | Yes | DAL | SELECT on `events_daily` via `owns_experience` | none | T-P10, T-P17 |
| P-19 | Request export / deletion of own data | publisher | self | Yes | handled by an admin as a documented process (Q-36) | no self-service delete; account removal blocked while publications exist | `publisher.erasure_requested` | T-P18 |

### 5.3 Administrator

| ID | Operation | Principal | Ownership | AuthN | App check | RLS / DB | Audit | Tests |
|---|---|---|---|---|---|---|---|---|
| P-20 | Sign in as admin | admin | `admins.user_id = auth.uid()` | Yes + MFA | `requireAdmin()`: `getUser()`, row check, `aal2` | `private.is_admin()` requires `aal2` | `admin.signed_in` | T-D01, T-D02 |
| P-21 | Create an invitation | admin | none | Yes + aal2 | server action; normalise email; then send the Supabase invite (privileged module) | INSERT only via `create_invite()`; `is_admin()`; ordinary publishers have no grant | `invite.created` | T-I01, T-I02, T-I03, T-I06 |
| P-22 | List / revoke invitations | admin | none | Yes + aal2 | server action | SELECT and revoke via admin policy/function only | `invite.revoked` | T-I01, T-I02, T-I05 |
| P-23 | Suspend, reinstate or revoke a publisher | admin | none | Yes + aal2 + re-auth | typed confirmation + reason; then ban the auth user and end sessions (privileged module) | `set_publisher_status()`; status read by every policy so effect is immediate | `publisher.suspended` etc. | T-S02, T-S03, T-D04 |
| P-24 | Curate topics | admin | none | Yes + aal2 | server action | admin write policy on `topics` | `topic.changed` | T-D05 |
| P-25 | Take down (admin unpublish) | admin | none (works on public projection and publication record only) | Yes + aal2 + re-auth | reason code, note, confirmation; notify the publisher; revalidate | `admin_takedown()`; no draft access; sets a hold so the owner cannot republish until an admin lifts it | `publication.taken_down` | T-L12, T-D03 |
| P-26 | Read audit log | admin | none | Yes + aal2 | server action | SELECT policy `is_admin()`; the log contains ids and codes, never document content | `audit.read` | T-D06 |
| P-27 | Read aggregate analytics (all) | admin | none | Yes + aal2 | server action | SELECT on `events_daily` for admins (aggregates only) | none | T-D06 |
| P-28 | Read private draft content | **no one in the app** | n/a | n/a | not implemented | no policy exists for admins | n/a | T-D03 |

### 5.4 AI service

| ID | Operation | Principal | Ownership | AuthN | App check | RLS / DB | Audit | Tests |
|---|---|---|---|---|---|---|---|---|
| P-29 | Create a draft experience for a publisher | `ai_service` | on behalf of the requesting publisher, who must have an open request | Service credential (not a human session) | job runner passes the requesting publisher | `ai_api.create_draft()` only; sets `author_kind='ai'`; owner is the requester | `experience.created_by_ai` | T-X03, T-X06 |
| P-30 | Create a revision | `ai_service` | the experience belongs to the requester | service credential | as above | `ai_api.create_revision()`; parent must equal head; never marks a revision approved or validated | `revision.saved_by_ai` | T-X04, T-X06 |
| P-31 | Approve or publish | **never `ai_service`** | n/a | n/a | n/a | no `EXECUTE` on `approve_revision`/`publish_revision`; no grant on `approvals`/`publications`; the functions also require `auth.uid()` | n/a | T-X01, T-X02, T-X05, T-X07 |
| P-32 | Read another publisher's private data | **never** | n/a | n/a | n/a | `ai_api` functions take a request id and scope to it; no table grants | n/a | T-X06 |

Rows P-29…P-32 describe the **invariant**. The tests that can run in Stage 3 (T-X01, T-X02, T-X05) assert that a role with no AI code behind it already cannot approve or publish. The functions themselves are built with AI authoring, not now.

## 6. Authentication approach

**Method:** Supabase Auth with **email magic links**, **invite-only**, no passwords. [Rec D-046] Evaluated against the requirement "invited publishers only":

| Fact | Source |
|---|---|
| `signInWithOtp` creates unknown users by default; `shouldCreateUser: false` prevents that | [V-1] |
| Magic links are one-time use, expire after 1 hour by default (same setting governs OTP, invitation, recovery links), expiry over 24 h is discouraged | [V-1] |
| The dashboard has "Allow new users to sign up"; when disabled only existing users can sign in | [V-2] |
| `auth.admin.inviteUserByEmail()` needs the **secret key**, creates an *unconfirmed* user, sends the "Invite user" template, returns an error if the email already belongs to a confirmed user; `redirectTo` is silently ignored unless on the allow-list | [V-2] |
| Per-user 60 s between requests; per-IP 30 requests / 5 min on sign-in endpoints; configurable; built-in email provider is limited to **2 emails per hour** and can be changed only with custom SMTP | [V-7] |
| Production checklist: custom SMTP, disable link tracking (it can break links), CAPTCHA supported on sign-up/sign-in/reset | [V-7] |

### 6.1 The two layers of an invitation

Supabase's own link expiry is short (default 1 h), but an invitation should live for days. So there are two separate things:

1. **The invitation is an authorisation record** in our `invites` table: normalised email, created by which admin, `expires_at` (default 7 days, maximum 30, Rec), status. It authorises "this email may become a publisher".
2. **The magic link proves ownership of the email.** It is only ever sent to the address on a valid invitation, and it can be re-requested any number of times while the invitation is valid.

The invitation carries **no bearer token**. Redemption is bound to the *verified email on the authenticated session*, so a leaked invite cannot be redeemed by someone else. [Rec D-046]

### 6.2 Flows

**Admin creates an invitation (P-21).** Admin session (aal2) → server action calls `create_invite(email)` → row inserted (`pending`, `expires_at`) → server (privileged module, secret key, server-only) triggers the Supabase invite email for that address → audit `invite.created`. The admin may also hand the sign-in URL to the person by another route; the sign-in page works for any invited email.

**First-time publisher.** Invitee opens the link → lands on `/auth/confirm` → presses a **Continue** button (a POST, not an automatic GET, so an email security scanner that fetches the URL cannot consume a one-time link; this is a mitigation for a *plausible* problem the docs do not address [Unverified U-2]) → server verifies the token hash (`verifyOtp`) → session cookie set → server calls `redeem_invite()` → the database finds the pending, unexpired invite whose email equals the session's verified email, inserts `publishers (id = auth.uid(), status = 'active')`, marks the invite redeemed, writes the audit row, all in one transaction → redirect to `/studio` to complete the profile.

**Returning publisher.** `/sign-in` form takes an email. The server action returns the **same neutral message** whatever happens ("If this email is invited, a sign-in link is on its way"), preventing account and invitation enumeration. It sends a link only when the email belongs to an active publisher or admin, or to a pending unexpired invite (`signInWithOtp` with `shouldCreateUser: false` for existing users). Rate limits: per-email and per-IP at Supabase [V-7] plus an application limit and a challenge on the form.

**Edge cases.**

| Case | Behaviour |
|---|---|
| Invite expired | Redemption fails; no `publishers` row; admin issues a new invite. The auth user, if created, has **no capability**. |
| Invite already used | `redeem_invite()` finds no pending row: no-op error. Single use under concurrency: row lock + unique partial index (T-I07). |
| Invite revoked | Status `revoked`; redemption fails; if a link was already sent it is useless without a pending invite. |
| Duplicate invite to the same email | Partial unique index allows one *pending* invite per email. |
| Invitee uses a different email than invited | They cannot: the invite is matched by the *verified* email, not typed text. |
| Suspended or revoked publisher | `publishers.status` ≠ `active`: every policy returns nothing and every function refuses. `redeem_invite()` does not re-activate; only `set_publisher_status()` by an admin does. |
| Authenticated but not invited | Has an `auth.users` row and a session, **no capability**. Workspace denied (T-S01). |
| Sign-out | Server action calls `signOut`, clears the cookies. For a suspended user the server also uses the privileged module to end remaining sessions (ban) [Unverified U-7 for exact API behaviour]. |
| Expired session | The proxy refreshes tokens when possible [V-3]; otherwise redirect to `/sign-in?next=…` with a neutral message. |
| Auth errors | A generic message to the user; the specific cause is logged server-side without the email or token. |
| Magic link opened on another device | Works or fails per Supabase's PKCE behaviour, which the docs read did not state [Unverified U-2]; the UI must offer "request a new link" in either case. |

### 6.3 Passwordless abuse protection

Built-in rate limits [V-7]; **custom SMTP** before any invitation is sent (the built-in sender allows 2 emails per hour) [V-7]; link tracking off [V-7]; CAPTCHA on the sign-in form [V-7]; neutral responses; invitations only for known emails (no open sign-up); an application-level counter per email and per IP; alerts on repeated failures. The sender domain and DNS (SPF/DKIM) for `inscapio.in` are an **owner decision** that touches the production domain and is therefore **not done in this milestone** (Q-33, Q-23).

### 6.4 Compatibility with Next.js App Router and hosting

- Next.js here is **16.4.0**; the Supabase guide says the session-refreshing file must be **`proxy.ts`** on Next 16 (on 15 and earlier it is `middleware.ts`, and a `proxy.ts` is never called) [V-3].
- Supabase's SSR package is `@supabase/ssr`; env vars `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` [V-3]. **Adding these dependencies requires owner approval** (CLAUDE.md "no dependencies casually"; D-053).
- Server Components cannot write cookies, so the proxy refreshes the session and writes cookies on the request and response [V-3].
- Reading cookies makes a route dynamic; refreshed `Set-Cookie` on a cached response can sign one user in as another [V-3]. Therefore the proxy matcher is restricted to `/studio`, `/admin`, `/sign-in`, `/auth` and the public site never touches it (§8.1).
- Next.js's own guidance: Server Actions and Route Handlers are public endpoints and must authorise every call; layout checks do not run on every navigation; the Proxy is for optimistic checks only [V-11].
- The hosting target for the Next.js app (Vercel in D-012; the production site is currently served elsewhere, Q-23) affects region and cold-start choices and is **not decided here**.

## 7. Server-side authorisation

### 7.1 Boundaries

| Zone | Holds | Trusted for | Never holds |
|---|---|---|---|
| **Browser** | publishable key, the user's session cookie (httpOnly, set by the server) | nothing | secret key, AI credential, any role decision |
| **Next.js server** | session verification, the data-access layer (DAL), Zod validation, rate limiting | identity from a *verified* token; validation; orchestration | long-lived secrets in client bundles (`server-only` modules) |
| **Supabase Auth** | users, sessions, MFA factors, tokens | proving who the caller is | application roles |
| **Postgres** | policies, functions, constraints, the audit log | **the final say** on ownership and state | trust in client-supplied values |
| **Privileged credentials** | secret key (server-only, one module); `validator_service` and `ai_service` roles | narrow named operations | general data access from request handlers |

### 7.2 Protected route validation

- **Proxy (optimistic only):** redirects requests without a session cookie away from `/studio`, `/admin`. It does not trust a role. It does no database call [V-11].
- **Every protected page and layout segment** calls `requireActivePublisher()` / `requireAdmin()` from the DAL; a layout check alone is not relied on because layouts do not re-run on client navigation [V-11].
- `requireActivePublisher()`: `getClaims()` to validate the token's signature (cheap, local for asymmetric keys) [V-3]; then one RLS-scoped select of the caller's own `publishers` row for `status`. `requireAdmin()` additionally requires `aal2`.
- **High-risk mutations** (approve, publish, unpublish, takedown, status change, invite) additionally call `getUser()` so a deleted or banned user is detected at the Auth server rather than trusted from a still-valid token [V-3].
- **Server actions and route handlers** each call the same functions first and derive the actor from the session; request-supplied role, status and `publisher_id` fields are never read.
- **Preview** is dynamic and `noindex`; draft URLs are never in a sitemap (IA already requires this).
- Unauthorised access to another publisher's resource returns *not found* rather than *forbidden*, so existence is not leaked.

### 7.3 Ownership-enforcing data access

The Next.js server queries as the **user** (publishable key plus the user's JWT), so RLS applies to every ordinary read and write. The secret key is *not* used for reads. A grep-able rule: the privileged module is the only file that imports the secret key, and a lint rule/test fails the build if any other file reads it.

### 7.4 Public pages read published content only

Public routes use the publishable key as `anon` and query `published_experiences` only. They never import the DAL, never call `cookies()`, and never see a draft table, so a bug in the public path cannot reach a draft. Until the DB-backed read path ships (implementation plan 3.5), public pages continue to be generated from the validated files in `src/content/experiences/`, unchanged.

### 7.5 AI cannot bypass approval

Four independent walls: (1) the AI credential has no grant on `approvals`/`publications` and no `EXECUTE` on the approval/publish functions; (2) those functions require `auth.uid()`, which an AI connection does not have; (3) `publications.revision_id` is a foreign key to `approvals`, so a publication of an unapproved revision cannot exist even if a function were buggy; (4) the approval is bound to the revision's content hash, and revisions are immutable. AI revisions are stored with `author_kind = 'ai'` and visibly labelled in the studio. [Proposed D-018; Rec D-048, D-049]

### 7.6 Secrets

Secrets live only in the host's secret store and local untracked env files; none are committed (CLAUDE.md "never commit secrets"). Only `NEXT_PUBLIC_*` values reach the browser. The environment plan is in the implementation plan §3. **This document and its companions contain no credential and none was requested.**

## 8. Admin and break-glass

### 8.1 Why the public site must not know about sessions

If a public page called `cookies()`, it would become dynamic and refreshed cookies could be cached [V-3]. Keeping the public layout session-free also makes "anonymous by default" literally true.

### 8.2 Administrator bootstrap and removal

There is no self-service path to becoming an admin. The first administrator row is created by the **Supabase project owner** by a documented SQL procedure run once per environment, with an audit row written by hand; no personal email or id is committed to the repository. Adding or removing further admins is the same procedure. Making it an app feature would let a compromised admin session mint admins. The number of admins and who owns the Supabase organisation are open (Q-34).

### 8.3 The owner is outside the model

Anyone with owner/admin access to the Supabase organisation or direct database credentials can read everything, including private drafts. That is a **trust boundary the application cannot enforce**. Mitigations to specify and verify before outside publishers join: minimum number of org owners, 2FA on those accounts, no shared logins, production database credentials not on developer machines, and a written procedure for any exceptional access with a record kept. Whether Supabase offers owner-access audit logging on the plan chosen is unverified [Unverified U-9].

## 9. Residual risks owned by this design

| ID | Risk | Mitigation | Owner decision |
|---|---|---|---|
| R-1 | A publisher bypasses the UI and calls a database function directly with a document that passes shape checks but fails the full Zod schema | Validation is *attested*: `revision_validations` is writable only by the server-only `validator_service` role, and approval requires a passing attestation for that exact content hash. The renderer also fails closed. | Whether to accept the simpler "shape gate only" in a first alpha (Q-43). |
| R-2 | Stale JWT after suspension | Policies read `publishers.status` each query; high-risk actions call `getUser()`; the server bans the auth user. Token lifetime is configurable but its default and plan limits were not verified [Unverified U-5]. | Acceptable window (Q-41). |
| R-3 | The AI credential cannot be a Supabase secret key | Custom Postgres role path; spike before AI work [Unverified U-6]. | None yet. |
| R-4 | Cache lag after unpublish or takedown | Revalidate on every unpublish; a takedown also purges; target and mechanism decided in 3.5 (Q-42). | Acceptable lag. |
| R-5 | Feedback and event endpoints are anonymous write paths | Narrow column grants, size caps, rate limits, challenge; counts are approximate by design. | Challenge vendor (Q-37). |
| R-6 | Org owners and project operators can read all data | §8.3 | Q-34 |
| R-7 | An existing Supabase project of unknown region, plan and configuration | Treated as **unverified**; a new project is advisable before real data (implementation plan §3.1). | Q-30, Q-31 |

## 10. Future compatibility checklist

Reader accounts (§3.2), organisations (§3.3), subscriptions and billing, recommendations and a configurable permission framework are **not built and not designed in detail**. The only accommodations made now are: the ownership helper functions, `publishers.id = auth.users.id`, capability-by-table, and an `author_kind` column on revisions.

---

## Appendix A — Verified vendor facts (13 Oct 2026)

Each fact was read from the vendor's current documentation page named here. Docs change; re-verify when implementing.

| ID | Fact | Source page |
|---|---|---|
| V-1 | `signInWithOtp` auto-creates users unless `shouldCreateUser: false`; magic links and OTP differ only by email template; magic links are one-time use; default request spacing 60 s; default expiry 1 h; expiry > 24 h strongly discouraged; the same expiry setting covers invitation and recovery links; redirects only to the Site URL / allow-list; the PKCE example sends `token_hash` to `/auth/confirm` and calls `verifyOtp` | supabase.com/docs/guides/auth/passwordless-login/auth-email-otp |
| V-2 | "Allow new users to sign up" can be disabled so only existing users can sign in; `auth.admin.inviteUserByEmail` requires the secret key, creates an unconfirmed user, errors for an already confirmed email, `redirectTo` silently ignored when not allow-listed, invite expiry follows the OTP expiry setting | …/guides/auth/general-configuration; …/guides/auth/users |
| V-3 | `@supabase/ssr`; `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`; **Next 16 uses `proxy.ts`** (on ≤ 15 a `proxy.ts` is never called); proxy refreshes tokens via `getClaims()`; `getClaims()` protects pages and verifies the signature (local for asymmetric keys); `getUser()` makes an Auth-server call; `getSession()` must not be trusted in server code; ISR/CDN can cache a refreshed `Set-Cookie` and sign a user in as someone else | …/guides/auth/server-side/nextjs |
| V-4 | Enable RLS on every exposed table; once on, no data via the publishable key until policies exist; existing projects may grant all four privileges to `anon`/`authenticated`/`service_role` on new tables, so revoke and regrant; one policy per operation; `auth.uid()` is null when unauthenticated and comparisons silently fail so add `IS NOT NULL`; always use `TO <role>`; index policy columns and wrap helpers in `(select …)`; views bypass RLS unless `security_invoker = true` (Postgres 15+); `user_metadata` is user-editable and must not be used for authorisation; `app_metadata` is not user-modifiable | …/guides/database/postgres/row-level-security |
| V-5 | Publishable key (`sb_publishable_…`) is safe in clients and maps to `anon`/`authenticated`; secret key (`sb_secret_…`) maps to `service_role` with `BYPASSRLS`, backend only, blocked in browsers by User-Agent check; legacy `anon`/`service_role` JWT keys are being deprecated by end of 2026 and both systems work in parallel; recommended one secret key per backend component; rotation steps; keys go in the `apikey` header | …/guides/api/api-keys |
| V-6 | Production checklist: RLS on all tables; custom SMTP (built-in = 2 emails/hour); disable link tracking; rate limits adjustable; CAPTCHA on sign-up/sign-in/reset; SSL enforcement; network restrictions; PITR for lower RPO; free-plan backups not downloadable | …/guides/platform/going-into-prod |
| V-7 | Rate limits: built-in email 2/hour; per-user 60 s for OTP/magic link; per-IP 30 per 5 min on sign-up/sign-in/`/otp`/`/magiclink`; verification 30 per 5 min; token endpoint 150 per 5 min; MFA challenge/verify 15 per minute (not configurable); token-bucket; configurable via dashboard or Management API | …/guides/auth/rate-limits |
| V-8 | Backups: Free none (export with CLI `db dump`); Pro 7 days daily; Team 14; Enterprise up to 30; PITR is an add-on needing at least Small compute and replaces daily backups; daily backups exclude Storage objects; deleting a project deletes its backups. Free plan: 2 active projects, 500 MB database, 50,000 MAU, **pauses after 1 week of inactivity**; Pro PITR ≈ $100/month per 7 days retention | …/guides/platform/backups; supabase.com/pricing |
| V-9 | MFA supports TOTP and phone factors; policies can require `aal2`; RESTRICTIVE policies recommended; MFA must also be enforced in APIs and SSR; challenge/verify limit 15 per minute | …/guides/auth/auth-mfa; …/rate-limits |
| V-10 | Custom access token hook runs before token issue, can add claims, must keep required claims (`iss`, `aud`, `exp`, `iat`, `sub`, `role`, `aal`, `session_id`, `email`, `phone`, `is_anonymous`) | …/guides/auth/auth-hooks/custom-access-token-hook |
| V-11 | Next.js 16.4.0: treat Server Actions and Route Handlers like public endpoints; Proxy for optimistic checks only (no DB checks); layouts do not re-render on navigation so check close to the data; Proxy uses the Node.js runtime; use a DAL and DTOs | nextjs.org/docs/app/guides/authentication |
| V-12 | Regions include `ap-south-1` (Mumbai) and `ap-southeast-1` (Singapore); each project has one primary region; the docs read do not say whether a region can be changed in place; migrating is via backup/restore to a new project; moving between organisations is a project transfer, not a migration | …/guides/platform/regions; …/guides/platform/migrating-within-supabase |
| V-13 | Local development with the CLI: `supabase init`, `migration new`, `db reset`, `db diff`, `db pull`, `db push`, `seed.sql`; pgTAP tests via `supabase test db` (set role and JWT claims to simulate users; wrap in a transaction); an application-level Vitest + supabase-js pattern; CI via `supabase start` + `supabase test db`; staging should be a *new* project; migrations deployed via CI using an access token, DB password and project id as encrypted secrets | …/guides/local-development/*; …/guides/deployment/managing-environments |

## Appendix B — Not verified; must be checked before relying on it

| ID | Unverified | How to resolve |
|---|---|---|
| U-1 | The state, org, region, plan, config and key model of the **existing** Supabase project. It could not be inspected and no credentials were or may be requested. | Owner reads the project settings and records them in Q-30/Q-31, or a new project is created (plan §3.1). |
| U-2 | Whether email scanners or link previews consume one-time magic links; whether a link must be opened on the requesting device | Spike on the local stack and on real mail clients in 3.3. |
| U-3 | Whether `inviteUserByEmail` works while "Allow new users to sign up" is off; whether an invited, unconfirmed user can later request a fresh magic link with `shouldCreateUser: false` | Spike in 3.3. If not, use an admin-generated link or leave sign-ups on with a database gate that denies uninvited users (the design already denies them). |
| U-4 | Postgres major version of the project (needed for `security_invoker` views, V-4) | Check in the local stack and the hosted project. |
| U-5 | Default access-token lifetime and whether session time-box or inactivity timeout is available on the plan | Dashboard session settings; plan docs. |
| U-6 | Custom Postgres roles (`ai_service`, `validator_service`), their grants, and a direct/pooled connection from the chosen host | Spike in 3.2. |
| U-7 | Exact API to end all sessions of a banned user | Spike in 3.3. |
| U-8 | MFA availability on the plan in use | Pricing/plan docs. |
| U-9 | Owner-access audit logging for the Supabase organisation | Account security docs. |
| U-10 | Storage RLS and public/private bucket behaviour for media | Verify at the media increment. |
