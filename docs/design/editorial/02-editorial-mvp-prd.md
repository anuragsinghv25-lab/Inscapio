# 02 · Product requirements: Editorial MVP

**Status:** Proposed for owner review. Nothing here is approved or built. New proposed questions are Q-45 to Q-54 (see `06-decisions-assumptions-risks.md` and `docs/OPEN-QUESTIONS.md`).

## 1. Goal

One editor publishes **5–10 curated world-affairs stories a day** as structured, interactive explainers, without editing source code or redeploying, and readers can follow each story's evidence, dates and corrections without signing in.

**Not a goal:** automated news ingestion, auto-publication, an AI API inside the app, multiple outside publishers, comments, accounts for readers.

## 2. Users

| User | Needs | Notes |
|---|---|---|
| Reader (anonymous) | Understand a development fast; see what is established vs claimed; check sources; trust corrections | No account, ever (MVP). |
| Administrator (the owner; sole, MFA required, D-058) | Pick stories, import AI-drafted JSON, fix errors, preview, approve, publish, update, correct, unpublish | Must also hold a publisher record to publish (verify in 3.3). |
| Publisher (optional later; invited manually; MFA optional, D-061) | Same as administrator minus people management | Not needed for the MVP launch; owner is the only author. |

## 3. Workflow (the owner's daily loop, mapped to screens)

1. Choose stories externally and collect sources (no screen).
2. Use ChatGPT or Claude outside InScapio to produce **structured JSON** that follows a published schema (the owner needs a copy-able *prompt pack + schema reference*, see §6 R-12).
3. **S-02 Import**: paste, validate, see plain-English errors, save as draft.
4. **S-03 Editor**: fix text, sources, labels, block order.
5. **S-04 Preview**: desktop and phone, identical components to the public site.
6. **S-05 Review and publish**: checklist → explicit approval → public URL.
7. Story appears on **P-02** and its topic page.
8. **S-06**: update, correct or unpublish with a public note.

## 4. Requirements

### 4.1 Public (must)

| ID | Requirement | Acceptance (testable) |
|---|---|---|
| R-P1 | Edition front page shows a lead story, a daily briefing grid and topic chips | With 0, 1, 2, 8 and 16 stories the page renders without layout breakage; empty, loading and error states exist |
| R-P2 | Cards show topic, headline, summary, time (IST), status chip (New / Updated / Corrected), epistemic label | Every card has all five; headline is the only link target |
| R-P3 | Headline rail is **manual** (scroll, snap, arrow keys, buttons) | Operable with keyboard and touch; identical under reduced motion; no auto movement |
| R-P4 | Story page supports blocks in `03-content-schema-mapping.md`; not every block is required | A story with only prose + sources validates and renders |
| R-P5 | Every claim in the briefing carries an epistemic label; every non-Analysis claim cites a source | Validator rejects an unlabeled briefing claim |
| R-P6 | Visible published time, updated time, source list with dates; illustrative data flagged | Axe has no violations; flag text appears next to illustrative charts |
| R-P7 | Updates and corrections: top banner + public change log; unpublished story leaves a tombstone | Corrected story shows the banner after correction; unpublished URL returns 410 or a tombstone page, never silently 404 |
| R-P8 | Chart has a table alternative; timeline is keyboard-operable; nothing requires hover | Keyboard-only walkthrough passes; 375px has no horizontal page scroll |
| R-P9 | Public pages work with JavaScript failing to hydrate for reading (progressive enhancement) | Text, sources and tables render in server HTML |
| R-P10 | No sign-in prompts, trackers or cookie walls | None present; analytics (if any) is a separate decision |

### 4.2 Private workspace (must)

| ID | Requirement | Acceptance |
|---|---|---|
| R-S1 | Admin routes require sign-in **and** the database role **and** MFA (aal2); signed-in-only gets Access denied | Test with a signed-in user without a role |
| R-S2 | Import accepts only the closed block list; unknown types and any raw HTML/JS are rejected with a path and plain-English fix | Pasting a block `{type:"html"}` is refused; message names `blocks[n].type` |
| R-S3 | Draft cannot be saved until server-side validation passes (validator service, D-056) | The Save button is disabled and the DB refuses an unattested draft |
| R-S4 | Editor: headline, summary, labels, sources, block reorder with buttons (drag optional) | Reorder by keyboard works and is announced |
| R-S5 | Preview renders the real public components from the draft, desktop and phone widths | Same component tree as production (no second renderer) |
| R-S6 | Publish needs a human session, passed checklist and explicit confirmation; AI or service credentials can never publish | DB function refuses non-human sessions (exists, 3.2) |
| R-S7 | Update, correct and unpublish each need a public note; correction keeps a visible banner | Public change log shows all three types distinctly |
| R-S8 | Dashboard queue with statuses Draft / Ready / Published / Updated / Corrected / Unpublished / Held and "next action" | Row counts match the database |
| R-S9 | Invitations: record, show status and expiry, revoke; no email sending (manual, D-061) | Expired and revoked invitations cannot be redeemed |
| R-S10 | Security page shows MFA state and sign-out; no recovery feature | Matches D-058 |
| R-S11 | Unsaved-changes guard and visible save state | Navigating away warns |
| R-S12 | Phone: preview and typo fix only; structured editing desktop-only | Documented limitation |

### 4.3 Should (MVP if time, else next)

Lead-story selection ("Set as lead"); topic filter on archive; copy-link button; print-friendly story; dark mode parity (tokens exist).

### 4.4 Later (not MVP)

Scheduling; analytics; AI assist inside studio; feedback inbox; multiple admins; outside publishers; media library; newsletters; search; translations; push alerts; comments.

## 5. Non-functional requirements

- **Accessibility:** WCAG 2.2 AA; 44px targets; visible focus; reduced-motion parity; status never by colour alone; chart table alternative; live regions for dynamic results.
- **Performance:** story page server-rendered; chart and timeline hydrate lazily; target budget to be set in Stage 3.5 (not measured yet).
- **Security:** no AI-supplied HTML/JS; strict schema; https-only links; no secrets in client; no `service_role` key in the app (D-060); studio `noindex`.
- **Content integrity:** append-only revisions; publish records approver and time; public log of changes.
- **Freshness:** publish-to-visible latency target (suggest ≤60s) depends on Stage 3.5 caching (Q-42).
- **Legal/editorial:** corrections policy, AI-use disclosure, quotation limits, defamation handling, applicable Indian digital-news rules: **counsel review before launch** (Q-49).

## 6. Risks specific to the workflow

| ID | Risk | Mitigation |
|---|---|---|
| R-12 | The owner cannot produce valid JSON reliably from ChatGPT/Claude | Ship a prompt pack, a schema reference page and 2 example files in the studio; validator messages written for a non-developer |
| R-13 | 5–10 reviewed stories a day is heavy | Import-to-publish target ≤15 minutes per story; track real time in the pilot; start at 2–3 a day |
| R-14 | AI errors reach readers | Human approval; every claim sourced; checklist; correction workflow; method note |
| R-15 | Copyright / quotation of third-party reporting | Summarise, link, short quotes only; counsel review |

## 7. Complete screens and flows list

**Screens:** P-02 to P-06, P-08, P-10 (public); A-01 to A-11 (auth); S-01 to S-08 (studio); system states (page 6). Existing and reused unchanged: P-07, P-09, P-11. Full table: `01-screen-inventory.md`.

**Flows (all clickable in the prototype unless noted):**

1. Reader: Edition → story → timeline/chart → source → related → topic page.
2. Reader: story that was corrected → banner → change log.
3. Reader: unpublished story URL → tombstone → Edition.
4. Reader: empty / loading / error edition.
5. Admin: sign-in → check email → (MFA enrol on first use) → MFA verify → queue.
6. Admin: queue → import → validation errors → fix → save draft → editor → preview → publish dialog → published.
7. Admin: published story → update / correct / unpublish.
8. Admin: invite a publisher; invitation expired; invitee signs in and accepts.
9. Admin: access denied; session expired; sign out.
10. Admin on phone: preview-only banner.
11. *Not prototyped (words only):* recovery from a lost authenticator (runbook).

## 8. Success measures (for the pilot, owner to confirm)

Median import-to-publish time; share of imports passing validation first time; corrections per 100 stories; reader task success in a 5-person usability check; accessibility audit pass.
