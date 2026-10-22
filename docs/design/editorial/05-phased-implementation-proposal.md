# 05 · Phased implementation proposal

**Status:** Proposed. Nothing here is approved. **No phase is started by this PR.** Existing increments (3.3 to 3.7) come from `docs/architecture/stage-3-implementation-plan.md`; "Stage 4" below is a **new proposal** and is not in any approved plan.

## 0. Key fact that shapes the phasing

The Stage 3 plan says *the workspace editor, AI authoring, media, reader accounts and organisations are not part of Stage 3*. The owner's goal (publish daily without redeploying) therefore needs **three things that do not yet exist in any plan**: a news content type, a studio (import, edit, preview, publish), and corrections/tombstones. It also needs two things that *are* planned: authentication (3.3) and the database-backed public read path (3.5).

## 1. Phase map

| Phase | Name | Status | Delivers | Needs |
|---|---|---|---|---|
| **3.3** | Auth integration (staging) | Planned, **not started**, gated on the owner confirming a staging Supabase project (D-057) | Sign-in (emailed link, D-061), session handling, MFA enrol/verify for admin, access-denied, sign-out; validator identity (D-056); invitation redemption | Owner creates staging project; `supabase-js`/`ssr` (approved, D-060); email provider/sender (Q-33); Q-44 |
| **3.4** | Admin operations | Planned | Suspend/reinstate, takedown with reason, audit-log view, hold | 3.3 |
| **3.5** | DB-backed public read path (behind a flag) | Planned | Public pages read `published_experiences`; revalidation on publish/unpublish/takedown; parity tests | 3.2, 3.3, Q-42 |
| **3.6** | Feedback and events | Planned; **not required for the owner-only editorial pilot** | | 3.5 |
| **3.7** | Pre-outside-publisher review | Planned; **required before any outside publisher**, owner to decide whether an owner-only pilot may precede it | | 3.1–3.6, legal gate |
| **4.0** | Editorial schema and prerequisites | **New, proposed** | `story` kind, six blocks, source extension, epistemic labels (schema v2); forward-only migration (kind CHECK, first-published/updated times, featured rank, `public_changes`, tombstone fields); full Zod **validator service** wired to `record_validation`; fixtures and tests | Owner approval of `03-content-schema-mapping.md`; 3.3 (validator identity) |
| **4.1** | Public Edition | New, proposed | Edition front page, story page, topic/archive page, explore index, method/corrections/AI-use pages, tombstone; rendering from **files first** so design and accessibility can be validated before the database path is ready | 4.0 schema; design sign-off |
| **4.2** | Studio MVP | New, proposed | Dashboard/queue, import and validation, form editor, preview, review-and-publish, update/correct/unpublish, invitations and security pages | 3.3, 3.5 (read path), 4.0, 4.1 components |
| **4.3** | Pilot and hardening | New, proposed | 2–3 stories/day for two weeks, usability and accessibility audit, security review of studio routes, load-time budget, runbook, prompt pack for the owner | 4.2 |
| **Later** | Enhancements | Not proposed now | See §4 | |

## 2. Sequencing rationale

1. **3.3 before everything private.** Studio screens need real sign-in and role checks (authentication ≠ authorisation).
2. **4.0 can start in parallel with 3.3** (schema work is local, but it changes the block vocabulary and a migration, so it needs approval first).
3. **4.1 before 4.2.** Reader components are reused by Preview, so the public experience is built and reviewed first, from files.
4. **3.5 before real "no redeploy" publishing.** Until the public site reads the database, a published story would not appear.
5. **An interim "files-first" option** (owner choice): between 4.1 and 3.5, stories could be added as JSON files in the repository and deployed. That keeps every rule in `CLAUDE.md` but **does not meet the "no redeploy per story" requirement**; it is only a pilot of the reading experience.

## 3. Subsequent security and content-delivery prerequisites (explicit list)

| Prerequisite | Why | Where |
|---|---|---|
| Staging project confirmed by owner | Hard gate (D-057) | before 3.3 |
| Validator service with minimal identity | Shape gate is structural only (D-056) | 3.3 identity + 4.0 code |
| Admin must also be a publisher to author | Admins have no draft access (D-050) | verify in 3.3 |
| Studio routes behind role + aal2, `noindex`, `no-store` | Private content | 3.3/4.2 |
| Public read path, cache and revalidation | Freshness and takedown lag (Q-42) | 3.5 |
| Public change log and tombstone migration | Corrections must be visible | 4.0 |
| Prompt pack + schema reference for the owner | Valid imports | 4.0/4.3 |
| Email provider and sender domain | Sign-in links | Q-33, before 3.3 end-to-end |
| Backups and recovery drill | Single admin (D-058) | before outside publishers; recommended before public pilot |
| Legal review: corrections, AI disclosure, quotation, defamation, applicable rules | Publishing news | before public launch |

## 4. Later enhancements (not in the Editorial MVP)

Scheduled publishing; analytics; AI assist (needs its own approval, D-049: `ai_service` has no privileges today); feedback inbox (3.6); multiple admins; outside publishers; media library; search; newsletter; push alerts; translations; reader accounts; comments; automated ingestion.

## 5. Estimates

No effort estimates are given: none can be supported by evidence yet. Suggested next step is for the owner to review, then each phase to get its own plan with acceptance criteria and tests as in earlier increments.

## 6. Stop points

After this design phase: **stop and wait for owner review.** Do not start 3.3, 4.0 or any later phase without explicit approval.
