# 01 · Screen inventory (repository-backed)

**Status of this document:** audit of the repository at `main` commit `2ddda50` (22 Oct 2026). Everything marked *Proposed* is a design only: it is **not implemented, not merged and not deployed**.

## How to read the statuses

| Word | Meaning here |
|---|---|
| **Implemented** | A route or component exists in `src/` on `main` and renders. |
| **Partially implemented** | Something runs, but it is incomplete (named below). |
| **Placeholder** | A stub exists only to hold a place. (None found.) |
| **Not yet implemented** | No screen exists. Backend support may exist (stated), but a database table or function is not a screen. |
| **Proposed new screen** | Designed in this phase (`prototype/index.html`). |

Four different things are kept apart on purpose:

- *Proposed*: drawn in this prototype only.
- *Implemented*: code exists on `main`.
- *Merged*: the code is in `main` (all current `src/` and `supabase/` work is merged; this branch is not).
- *Deployed*: running at inscapio.in. **Not verified here**: production deployment is separate from this repository's workflow, and no check against the live site was made.

## Evidence summary

- Routes in `src/app`: `/` (page.tsx), `/about`, `/experiences/[slug]` (static, `dynamicParams=false`, file-based), `not-found.tsx`, `layout.tsx`. **No** `/sign-in`, `/studio`, `/admin`, `/explore`, API routes or middleware.
- The "Explore" nav item is a link to `/#rooms` (`src/components/SiteChrome.tsx`), a section of the home page, not a page.
- No database client, sign-in or studio exists in the application (`CLAUDE.md`, confirmed by `src/` listing). The public site reads **files** under `src/content/`.
- `supabase/` holds local-only migrations and tests for identity (3.1) and experience core (3.2): drafts, revisions, approval, publish, takedown, a public projection. **No screen uses any of it.** No hosted project is connected (D-057).
- Stage 3.3 (auth integration) has not started; it waits for the owner to confirm a staging project (D-057 hard gate).

## A · Public reader screens

| ID | Screen | Target user | Status | Evidence / notes | Dependencies | In this design phase? | Editorial MVP? |
|---|---|---|---|---|---|---|---|
| P-01 | Home `/` (hero, ReadExploreStrip wipe, rooms, CityWall, closing) | Reader | **Implemented** | `src/app/page.tsx`, `components/home/*` | none | Yes: **replaced** by P-02 | n/a |
| P-02 | Edition front page (lead, daily briefing, rail, topics, method) | Reader | **Proposed** | Prototype page 2 | Content type for news (03), DB-backed read path (Stage 3.5) | Yes | Yes |
| P-03 | Headline rail (manual; auto-scroll variant) | Reader | **Proposed** | Phase 1.5 spec bans auto-playing elements (Q-46) | none | Yes | Yes (manual only) |
| P-04 | Story page, `kind: news` (briefing, timeline, stakeholders, cause chain, charts, India, scenarios, updates, sources, related) | Reader | **Proposed** | Prototype page 3 (2 illustrative stories) | New blocks (03) | Yes | Yes |
| P-05 | Topic / archive page | Reader | **Proposed** | Prototype page 2 | `topics` tables exist in DB (local) | Yes | Yes (basic) |
| P-06 | Explore index (list of existing experiences) | Reader | **Proposed** | Today only an anchor `/#rooms` | none | Yes (stub) | Yes (small) |
| P-07 | About `/about` | Reader | **Implemented** | `src/app/about/page.tsx` | none | Copy change only | Yes |
| P-08 | Method, corrections, AI-use pages | Reader | **Proposed** (copy) | Needs owner and counsel input (Q-49) | Policy decisions | Draft shown | Yes |
| P-09 | Experience page `/experiences/[slug]` ×2 | Reader | **Implemented** | `src/app/experiences/[slug]/page.tsx` | none | Not redesigned | Unchanged |
| P-10 | Unpublished / unavailable story (tombstone) | Reader | **Proposed** | Prototype page 6 | Public takedown reason/date (new) | Yes | Yes |
| P-11 | Not found | Reader | **Implemented** | `src/app/not-found.tsx` | none | Reused | Unchanged |
| P-12 | Feedback form | Reader | **Partially implemented** | `FeedbackForm.tsx` stores to localStorage and copies to clipboard only; no backend | Stage 3.6 | No | Later |
| P-13 | Site search | Reader | **Not yet implemented**; not designed | Out of scope | none | No | Later |

## B · Authentication and session screens (Stage 3.3 plan)

None exist. All are **Not yet implemented** (UI) and **Proposed** (design). Stage 3.3 has not started.

| ID | Screen | Target user | Status | Notes / dependencies |
|---|---|---|---|---|
| A-01 | Sign-in (email) | Admin, publisher | Proposed | Emailed link per **D-061 (Proposed, awaiting confirmation)**; no password, social or self-registration screens designed |
| A-02 | Sign-in failed | same | Proposed | Same message whether or not an account exists |
| A-03 | Check your email | same | Proposed | Link lifetime about an hour (D-061); sender domain open (Q-33) |
| A-04 | Invitation found / accept | Publisher | Proposed | Manual invitations (D-061); Q-44 open |
| A-05 | Invitation expired / none found | Publisher | Proposed | 7-day default, 1–30 allowed (D-061) |
| A-06 | Account ready | Publisher | Proposed | |
| A-07 | MFA enrol | Admin (required, D-058); publisher optional (D-061) | Proposed | MFA plan availability unverified (U-8) |
| A-08 | MFA verify / wrong code | same | Proposed | |
| A-09 | Access denied | any signed-in user without a role | Proposed | Signing in does not by itself grant access |
| A-10 | Session expired / signed out | any | Proposed | Stale-session window open (Q-41) |
| A-11 | Recovery | Admin | **Not designed**: only the owner-side runbook exists (`docs/runbooks/admin-recovery.md`, D-058, U-11) | Shown as an explanatory stub |

## C · Publisher and administrator workspace

**Important:** `docs/architecture/stage-3-implementation-plan.md` §2 states that *the workspace editor, AI authoring, media, reader accounts and organisations are not part of Stage 3*. Stage 3.4 is admin *operations* (suspend, takedown, audit log, hold). So S-01 to S-06 belong to a **new, proposed stage after Stage 3** (see `05-phased-implementation-proposal.md`), not to any existing increment.

None exist (UI). Database support is **local-only and not connected to anything**.

| ID | Screen | Target user | UI status | Backend support today (local, tested, not deployed) | Dependencies | Designed here | MVP |
|---|---|---|---|---|---|---|---|
| S-01 | Dashboard and daily queue | Admin, publisher | Not yet implemented → Proposed | `experiences`, revisions, statuses | 3.3 auth + new Studio stage | Yes | Yes |
| S-02 | Create / import story | Admin, publisher | Proposed | revision create; shape gate; **validator service not built (D-056)** | validator service (identity in 3.3, D-056; code is new) + Studio stage | Yes | Yes |
| S-03 | Story editor | Admin, publisher | Proposed | append-only revisions | Studio stage | Yes | Yes (form-based) |
| S-04 | Reader preview | Admin, publisher | Proposed | none (needs authenticated draft read path) | Studio stage; draft-read path | Yes | Yes |
| S-05 | Review and publish | Admin, publisher | Proposed | human-session-only approve/publish functions | Studio stage | Yes | Yes |
| S-06 | Update / correct / unpublish | Admin, publisher | Proposed | revisions; `admin_takedown`; `set_experience_hold`; **no public change log or tombstone text** | new migration | Yes | Yes |
| S-07 | People and invitations | Admin | Proposed | `create_invite` and related functions | 3.3/3.4 (placement to confirm) | Yes | Yes |
| S-08 | Security and account | Admin | Proposed | none in UI | 3.3 | Yes | Yes |
| S-09 | Feedback inbox | Admin | Not designed | tables not built (3.6) | 3.6 | No | Later |
| S-10 | Analytics | Admin | Not designed | none | none | Placeholder in nav only | Later |
| S-11 | AI assist inside the studio | Admin | Not designed | **no AI API in v1** (owner) | none | Placeholder in nav only | Later |
| S-12 | Scheduling, media library, multi-admin, outside publishers | | Not designed | Stage 3.7 review required first | | No | Later |

## D · System states

Designed on prototype page 6: empty, loading, validation summary, permission (403), unsaved changes, publish failure, session expired, unavailable story, responsive navigation, mobile editing limits, toast, drawer. Only **not-found** exists today.

## What must not be presented as built

Everything in sections A (P-02 to P-06, P-08, P-10), B, C and D except P-11. In particular: publishing without redeploying needs Stage 3.5 (DB-backed public read path), which does not exist; the public site today cannot show a story that is not in the repository.
