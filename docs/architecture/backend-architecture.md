# Backend architecture

> **Status:** Phase 0 · Recommended. Nothing is built. Vendor-specific claims are marked *(verify)*.

## Shape

**One deployable app and one database.** The "backend" is: server code inside the Next.js app (server components, server actions, route handlers), a managed Postgres, managed auth and storage, and a small job runner. There is no separate API service in the MVP. A service is split out only when a concrete need (a long-running worker, an independent scaling profile, a second client) justifies the cost.

## Data layer

### Principles

1. **Relational for entities, JSONB for documents.** Publishers, topics, publications, feedback and follows are rows. An experience's *content* is a validated JSON document stored per revision.
2. **Immutability where it matters.** Revisions and publications are append-only.
3. **Authorisation in the database.** Row-Level Security on every table; the application layer is a second line of defence, not the only one.
4. **Portable.** Plain SQL migrations in the repo; no reliance on proprietary data features without an exit path.
5. **A repository layer** hides storage from features. Features call `experiences.getPublished(slug)`, not raw queries.

### Conceptual tables

Physical design is a Phase 2 task. This maps the conceptual model in [`../ux/content-model.md`](../ux/content-model.md) to storage.

| Table | Key columns (indicative) | Notes |
|---|---|---|
| `publishers` | id, user_id, handle, display_name, bio, status | One per publisher account (organisations Later) |
| `topics` | id, slug, title, description | Curated |
| `experiences` | id, publisher_id, kind, slug, status, head_revision_id, schema_version | `status`: draft / in_review / published / unpublished |
| `experience_topics` | experience_id, topic_id | Many-to-many |
| `revisions` | id, experience_id, number, content (JSONB), schema_version, author (`human`/`ai`), created_at, parent_id | **Immutable** |
| `approvals` | revision_id, approved_by, approved_at | Written only by an authenticated human publisher action |
| `publications` | id, experience_id, revision_id, published_at, unpublished_at, slug_at_publish | Points at one revision |
| `interview_sessions` | id, experience_id, state, created_at | |
| `interview_turns` | id, session_id, role, content, created_at | |
| `knowledge_items` | id, session_id, kind, text, source_turn_id, confirmed_by_publisher | Provenance for AI-generated content |
| `sources` | id, experience_id, citation fields, accessed_at | Also embedded in revision content by id |
| `media` | id, experience_id, storage_path, alt_text, credit, licence | Alt text required |
| `feedback` | id, publication_id, answers (JSONB), created_at | Anonymous |
| `events_daily` | publication_id, day, metric, block_id, count | **Aggregated** analytics, not raw per-person events |
| `invites` | id, email, issued_by, accepted_at | Invite-only access |
| `jobs` | id, type, payload, status, attempts, run_at, result | Simple queue |
| `ai_calls` | id, experience_id, capability, model, tokens_in/out, latency, cost, outcome | Cost and quality observability |

**Later:** `readers`, `follows`, `subscriptions`, `saved`, `notifications`, `entitlements`, `organisations`, `members`.

### Revisions and content storage

- `revisions.content` holds the complete Experience document (see [`content-architecture.md`](./content-architecture.md)), validated against the schema **on every write**. Invalid documents never reach the table.
- Whole-document snapshots, not per-block rows, for the MVP: simple, easy to diff and restore. If collaborative editing arrives, revisit (a CRDT or per-block storage is a later concern).
- Block and section **IDs are stable across revisions**, so analytics and diffs can follow a block as it changes.
- Add a lightweight search or index structure only when needed.

## Authentication and authorisation

### Direction

- **Managed auth** (Supabase Auth) with **email magic links** for publishers and admins; social login can be added later. Never roll our own.
- **Invite-only** for the MVP: a sign-in succeeds only if an invite exists.
- **Sessions in secure, httpOnly cookies** for server rendering.
- **No reader accounts in the MVP.** Readers are anonymous.

### Roles

| Role | Can |
|---|---|
| Anonymous reader | Read published experiences, submit feedback |
| Publisher | CRUD their own drafts; run the interview; approve and publish their own experiences; read their analytics |
| Admin (InScapio) | Issue invites; curate home and topics; unpublish (takedown); see operational data |
| AI service | **Write draft content and revisions marked `ai`**; **no** approve/publish, **no** reading other publishers' data |

### Rules

- **RLS policies per table, with tests.** A publisher can only touch their own rows. The public can only read published data through views or policies that expose nothing else.
- **Approval and publication are written only through a dedicated server action** that checks the human session. The AI service uses a **separate credential with no permission to write `approvals` or `publications`.** A test asserts this.
- **MFA** for admins from day one, and offered to publishers.
- **Rate limiting** on sign-in, AI endpoints, feedback and analytics ingest.

## Jobs and long-running work

The interview is request/response with streaming and fits within normal request limits. Structuring, generation and QA can take longer.

- **MVP:** a `jobs` table and a worker (a scheduled function or a small long-lived process *(verify limits of the chosen host)*). Jobs are idempotent and retried with backoff, and their status is visible in the Studio.
- **Rule:** do not introduce a message broker until a real throughput or reliability problem demands it.
- Aggregation of analytics runs as a scheduled job.

## AI integration (server side)

All model calls originate from server-only modules and are logged to `ai_calls`. The provider key never leaves the server. The design is in [`ai-architecture.md`](./ai-architecture.md). Backend obligations:

- Per-publisher and global **spend and rate limits.**
- **Timeouts, retries and graceful failure.** An AI failure never loses publisher work; state is saved before each call.
- **Input handling for untrusted material** (pasted documents, fetched pages); see the prompt-injection section of the AI architecture.

## Analytics

- **Own, minimal, aggregate.** The reader page sends a small number of **declared** events (view, completion, deeper opened, block interaction, feedback submitted) to an ingest endpoint; the server increments daily counters. No per-person profile.
- **No third-party trackers** and no advertising identifiers. Where cookies are needed they are first-party and functional (reader preferences).
- Publishers see aggregates, never individual readers.

## Email (Later)

Needed for follows and notifications. Choose a transactional provider then; keep sending behind an interface. Not in the MVP beyond invite and sign-in emails.

## Payments (Future)

Out of scope. When it arrives, use a hosted provider and **never store card data**. Choose by the market the publishers are in (see [`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md)).

## Security

| Concern | Direction |
|---|---|
| **Injection / XSS** | Content has no HTML. Rendering uses typed components. Rich text is a small AST (text + marks), not HTML strings. This is a **hard requirement** because the prototype's `innerHTML` pattern is unsafe for publisher content. |
| **CSP** | Strict Content-Security-Policy; no inline scripts except via nonces; image/font/connect sources allowlisted. |
| **URLs in content** | Links and media pass an allowlist/scheme check (`https` only; media from our storage). |
| **Uploads** | Type and size limits; scan or re-encode images; never serve user files from the app origin. |
| **Secrets** | Environment-scoped; never in the repo; server-only; rotated. |
| **Dependencies** | Automated updates and audit in CI. |
| **Abuse** | Rate limiting; invite-only publishers; takedown tooling; audit log for approvals and publications. |
| **Prompt injection** | See the AI architecture. |

## Privacy and compliance

The primary audience is likely in India. Direction, **not legal advice; obtain counsel before the first outside publisher and before accounts for readers:**

- India's **Digital Personal Data Protection Act, 2023** (and its rules) governs personal data. The MVP reduces exposure by having **no reader accounts and no tracking profile**; publisher data (email, name) is limited and consent-based. *(verify the current status of the rules and obligations)*
- **Content liability.** The platform will host publishers' claims about the world, including (as in the prototype) real, recent cases. A **publisher agreement**, a **content policy**, a **takedown process** and the **mandatory human review** are product requirements, not afterthoughts.
- Data location: choose the primary region deliberately and document it.
- Retention: define for interview transcripts (which may contain sensitive publisher material), AI call logs and feedback.

## Reliability and operations

- Managed backups with point-in-time recovery enabled in production *(verify the plan tier)*.
- Migrations are forward-only, reviewed, and applied through CI.
- Uptime and error alerts; a documented rollback procedure ([`../engineering/development-workflow.md`](../engineering/development-workflow.md)).
- Seed data and fixtures for local development; recorded AI responses for tests.

## Scale posture

Expected (an estimate, **not a measured limit**) to carry **hundreds of publishers and a reader base in the hundreds of thousands per month** on this architecture, mostly because published experiences are static and cached at the edge. The first likely pressure points are AI cost and Studio concurrency, not read traffic. Anything beyond that is a later problem.

## Intentionally undecided

Exact job runner; email provider; analytics dashboard approach; search; whether the schema warrants collaborative editing infrastructure.
