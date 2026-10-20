# Stage 3.0 decision brief (owner decisions before Stage 3.3)

> **Status:** for owner review · **Proposed** · written 15 Oct 2026. Nothing here is decided. No hosted Supabase project, hosting dashboard, DNS record, SMTP account or domain registrar was inspected; **the repository records none of their current state, and this brief does not guess it.** No secret was requested or written.
> **Companions:** [`stage-3-implementation-plan.md`](./stage-3-implementation-plan.md) (§2 increments, §3 environments, §4 decisions), [`identity-and-access-control.md`](./identity-and-access-control.md), [`../DECISIONS.md`](../DECISIONS.md), [`../OPEN-QUESTIONS.md`](../OPEN-QUESTIONS.md). Labels V-n, U-n, Rec D-nnn are defined in the identity document §0.

## 0. Owner responses (20 Oct 2026)

The owner has answered part of this brief. See `DECISIONS.md` D-057 to D-061, `OPEN-QUESTIONS.md` and plan §4.3 for the authoritative record. In short: new staging project and no production project now (Q-31 answered); sole administrator with MFA (Q-34 partly); Vercel account and preview deployments in principle, no DNS or production change without approval (Q-32 partly); both Supabase libraries approved for 3.3; publisher MFA optional and manual invitations recorded as recommendations awaiting confirmation (Q-38, Q-40); Q-33 deliberately unresolved. A new question, Q-44, arose from manual invitations. The step-by-step guide for the owner is [`../runbooks/supabase-staging-setup.md`](../runbooks/supabase-staging-setup.md). The tables below are the original brief and were not rewritten.

## 1. Where things stand

Stage 3.1 (identity core) and 3.2 (experience core) are merged and tested against a **local** Supabase stack only. Stage 3.3 (sign-in, sessions, proxy, first server-side Supabase clients in the Next.js app) is the first increment that needs a **hosted staging project**, real email, a decided host and two new dependencies. Those need the answers below. Two further gates are not questions: owner approval of `@supabase/ssr` and `@supabase/supabase-js` (D-053), and the validator-identity requirement already accepted as D-056.

## 2. The decision table

"Blocks 3.3" is my assessment from the documents, not a recorded rule. "Record" says what must be written once you answer.

| Q | Decision required | Recorded recommendation | Blocks 3.3? | You must obtain yourself | Record |
|---|---|---|---|---|---|
| **Q-30** | Supabase ownership, region, plan; when privacy/legal advice starts | Production on a plan with backups before any outside publisher (D-051); Phase 0 leaning Mumbai `ap-south-1`, marked *verify*; DPDP residency is a legal question for counsel (plan §3.1, §6) | **Region and plan of the *staging* project: yes.** Production plan: no (needed before outside publishers, 3.7). Legal advice start: no, but before outside publishers | Current plan names and prices (re-check at purchase); the region list shown when creating a project; whether you will engage privacy counsel and when | New decision (region, staging plan, production plan intent); Q-30 answered; legal-advice start recorded in plan §6 |
| **Q-31** | Keep the existing Supabase project, or create new staging and production projects | New projects; the existing one is *scratch* until you record its facts (D-051, Proposed) | **Yes** | For the existing project: organisation and its owner, region, plan, Postgres version, "Allow new users to sign up" setting, API key model, whether any tables or data exist, whether RLS is on. **Do not paste keys or passwords.** | D-051 Accepted or amended; Q-31 answered; U-1 closed; fate of the existing project (keep as scratch, pause, delete) |
| **Q-32** | Next.js hosting target and region; whether a Postgres job queue is acceptable later | D-012 says Vercel (Proposed); production is "deployed elsewhere today" and `inscapio.in` shows "Page not found" after a project configuration change (Q-23, Q-32). No recommendation on region | **Partly.** The host decides where server secrets live and which region sits next to the database. Staging on preview URLs does not need production DNS. The job-queue question does not block 3.3 | What currently serves `inscapio.in`, in which region, on which plan and who owns it (hosting dashboard); where the domain's DNS is managed and the login/recovery for it; whether you have a Vercel account/team | D-012 confirmed or superseded; Q-32 answered; Q-23 remains separate; queue question deferred explicitly |
| **Q-33** | Custom SMTP provider and sender domain | Custom SMTP is required: the built-in sender allows 2 emails per hour [V-6, V-7]. Sender domain touches `inscapio.in` DNS, which this work must not change (Q-33) | **Staging: yes, some SMTP is needed to test sign-in end to end** (a provider sandbox is enough). Production sender domain: no, before outside publishers | Whether any email already uses `inscapio.in` (MX records); who controls DNS; provider account, current pricing and sending limits; whether the provider's data handling suits your privacy plan | New decision (provider, sender address, domain or subdomain, who may change DNS and how); Q-33 answered |
| **Q-34** | Number of administrators; Supabase organisation ownership; recovery | Settle organisation ownership before data exists, because a project move between organisations is a transfer, not a migration [V-12]; admins need MFA (D-050 accepted for 3.1). Organisation owners can read all data (Q-34) | **Yes** | Your Supabase organisation: members and roles; whether two-factor is on for the owning account; where its recovery codes live; who a second administrator would be (a person, not recorded in the repository) | New decision (admin count, organisation structure, recovery method); Q-34 answered. Names, emails and ids go in your private records, never the repository (bootstrap runbook) |
| **Q-38** | Must publishers use MFA before publishing | Backend doc says MFA is *offered* to publishers, not required; admins require aal2 (D-050) | **Yes, as a design input** (decides whether 3.3 builds enrolment and an aal2 gate for publishers). With the recorded default, 3.3 builds admin MFA only | Whether MFA is included on the plan you will use (U-8, unverified) | New decision; Q-38 answered; U-8 closed. If required, record that a later migration must add an aal2 condition to approval and publication |
| **Q-40** | How invites are delivered; invite lifetime | Only a default is recorded: 7 days, bounded 1 to 30 days, as the `create_invite` parameter (D-046). No delivery recommendation | **Yes** (decides which flow 3.3 builds). The 7-day default alone does not block | Nothing from a dashboard, except the email rate limits you accept [V-7] | D-046 remaining parts Accepted or amended; Q-40 answered; U-3 recorded as the spike that follows |

## 3. Per-question detail

### Q-31 · New projects or the existing one

| Option | Trade-offs |
|---|---|
| **A. New staging now; new production later, when real data is near** | Cheapest while there is only synthetic data. Staging must be a *new* project, not one already modified to look like production [V-13]. Production is created once region, ownership and plan are fixed, so nothing has to be moved. |
| **B. New staging and new production now** | Environments exist early. Costs a second project (and, once real data exists, a plan with backups). Free plan allows two active projects and pauses a project after a week of inactivity [V-8]; a paused production project is not acceptable. |
| **C. Reuse the existing project as staging** | No creation step. Its region, organisation, plan, Postgres version, sign-up setting, key model and contents are all unverified [U-1]; region is per project and the documented route to another region is a backup-and-restore into a new project [V-12]. Not recommended by D-051. |

**Recommendation recorded:** A or B (new projects, existing one is scratch). **I cannot create or inspect hosted projects**, so you create the project (or ask me to write the exact click-by-click and CLI steps for you to run) and record the facts.

### Q-30 · Region, plan, legal advice

- **Region.** One primary region per project [V-12]. Mumbai (`ap-south-1`) and Singapore (`ap-southeast-1`) exist. The audience and publishers are expected to be in India, so Mumbai is the recorded leaning (marked *verify*). Whether residency matters under the DPDP Act 2023 is a **legal** question, not a technical one.
- **Plan.** Free: no backups, no downloadable backups, pauses after a week of inactivity, two active projects. Pro: 7 days of daily backups; point-in-time recovery is a paid add-on [V-8]. Prices change; re-check when buying. Staging with synthetic data can start on the free plan; **production must not hold real data without backups** (D-051).
- **Choose jointly with Q-32.** The database region and the application's function region should be near each other.

### Q-32 · Hosting, region, and the relationship to production and staging

The repository does not say what serves `inscapio.in` today. It records that production is deployed elsewhere than the Vercel choice in D-012, that the site showed "Page not found" after a project configuration change, and that the repository contains no deployment or DNS configuration. **I do not know what the current host is.**

| Option | Trade-offs |
|---|---|
| **A. Vercel for previews/staging now; production moves to Vercel when you decide to deploy (Q-23)** | Matches D-012: previews per pull request, shared staging database. Two hosts exist until production moves. Preview URLs differ from `inscapio.in`, so Supabase redirect allow-lists must list them [V-1]. No production DNS change is needed for staging. |
| **B. Keep the current production host and use it for staging too** | One host. Only possible if that host runs Next.js 16's `proxy.ts` (Node.js runtime) and keeps server-only secrets safely [V-3, V-11]; this is unverified for an unknown host. |
| **C. Another host (Netlify, Cloudflare, AWS, self-host)** | Reverses D-012. Needs the same Node runtime and secret-store checks, plus a region choice. |

**Relationship to keep:** staging database region and production database region should be the same, so staging behaves like production; both should sit near the function region of the chosen host. Staging is *new*; production deployment, DNS and hosting remain a **separate, later decision** (Q-23) that this work does not make or prepare. A Postgres job queue (instead of a separate queue service) concerns the AI authoring stages, not 3.3; I suggest recording it as "acceptable for now, revisit at AI authoring" rather than leaving it open.

### Q-33 · SMTP and the risk of changing production DNS

Sign-in is by email link, so some real email delivery is needed from 3.3 onward. The built-in sender (2 emails per hour) is for trying things only [V-6, V-7].

| Option | Trade-offs |
|---|---|
| **A. Staging: provider sandbox or test mode, no domain change** | Zero DNS risk. Proves the flow and rate limits. Mail may only go to verified test addresses, depending on the provider. |
| **B. Production sender on a subdomain of `inscapio.in`** | Authentication records (SPF, DKIM, DMARC) are added only under the subdomain, so the existing website and any existing mailbox records are not edited. Still a DNS change, needing separate explicit approval. |
| **C. Production sender on the apex domain** | Simplest address, but edits records that may already carry mail or web behaviour; a wrong SPF or DMARC record can break existing mail or cause legitimate mail to be rejected. Highest risk. |
| **D. A separate domain used only for mail** | No `inscapio.in` change at all. Cost of a second domain; less brand consistency. |

**Risks of changing production DNS, specifically:** the site is currently not serving, and the repository does not say where its DNS is managed or what depends on it; a record added or edited in the wrong zone can take down the website or existing email; DNS changes propagate slowly and are hard to roll back precisely; SMTP authentication records must be right for deliverability. **Rule for this work:** no DNS change is made or prepared without your separate, explicit approval after the DNS host and current records are known. Provider examples to evaluate (none verified, none recommended here): Resend, Postmark, Amazon SES, Brevo.

### Q-34 · Administrators, ownership, MFA and account recovery

- **Two layers of authority.** Application administrators (rows in `admins`, aal2 required, no access to private drafts by design, D-050) and the Supabase **organisation owner**, who can reach all data. The owner is therefore the break-glass role and the highest-value account.
- **Recovery gap to know about.** The documented admin bootstrap is a SQL procedure run by the project owner (runbook). If the only administrator loses their authenticator, that procedure creates *another* administrator row, but **how to reset an Auth MFA factor is unverified**; I propose a spike in 3.3 and a new unverified item, U-11. Recovery codes and a second administrator reduce this risk.

| Option | Trade-offs |
|---|---|
| **A. One administrator (you), one organisation owner (you)** | Smallest attack surface and simplest. A lost authenticator or account locks out administration and ownership; recovery depends on a single email and device. |
| **B. One administrator, two organisation owners** | Protects against losing the owning account. Widens who can read all data. |
| **C. Two administrators, two organisation owners** | Best resilience and a second pair of eyes for takedowns. Largest circle with data access (owners) and authority to invite and suspend (admins). |

Whatever you choose: two-factor on the Supabase account and the GitHub account, recovery codes stored offline, and administrators' MFA enrolled before they are bootstrapped.

### Q-38 · Publisher MFA

| Option | Trade-offs |
|---|---|
| **A. Offered, not required (recorded default)** | Low friction for a small invited alpha. A stolen session could approve and publish: approval is human-session only, but a hijacked human session is still a human session. |
| **B. Required before approve/publish (aal2 on those functions)** | Strong protection exactly where harm happens. Needs a new migration (3.2 requires a human session, not aal2, for publishers), enrolment UX in 3.3, and MFA availability on the plan (U-8). MFA challenge/verify is limited to 15 per minute and is not configurable [V-7]. |
| **C. Required at every sign-in** | Strongest account protection; highest friction; same plan and UX needs as B. |

### Q-40 · Invitations: delivery and lifetime

An invitation in this design is an **email-bound database record, not a bearer token** (D-046, accepted for 3.1). Anyone can request a magic link, but only the invited verified email can redeem. So an invite does not need to carry a link.

| Option | Trade-offs |
|---|---|
| **A. Supabase `inviteUserByEmail` from a server action** | One step for the admin. Uses the secret key on the invite path (server-only, one module); creates an unconfirmed user; errors if the email is already confirmed; the emailed link follows the OTP expiry (default 1 hour, over 24 hours discouraged), which is much shorter than a 7-day invitation [V-1, V-2]. Whether it works with public sign-ups off is unverified (U-3). |
| **B. The admin tells the invitee, who then requests a normal magic link** | No invite email and no link-lifetime mismatch. The admin sends a short message by their own channel. Depends on the admin; no tracking. **Correction (20 Oct 2026): the invitee still needs an Auth account.** With public sign-ups off it must be created for them (for example by the owner in the dashboard, or by a server action using the secret key); with sign-ups on, the database gate denies the uninvited but anyone can create an account (spam, email volume). This is Q-44. |
| **C. The app sends its own invitation email pointing at the sign-in page (no token)** | Smooth for the invitee, no secret key for the link. Needs the SMTP choice (Q-33) and a template; still no bearer token. |

**Lifetime.** The function takes 1 to 30 days with a 7-day default; changing the default is a small, safe change. Shorter windows limit stale invitations; longer windows suit a slow alpha. **Recorded:** 7 days. **My view, not recorded in the repository:** B or C avoids the invite email and the link-lifetime mismatch; I would start with B for the closed alpha. (An earlier version of this sentence said B avoids the U-3 spike and the secret key; that was incomplete, see the correction in option B and Q-44.) Treat that as an opinion for you to accept or reject.

## 4. What I need from you, in order

1. **Read, from your own dashboards, and record privately** (do not paste secrets or credentials): the facts under Q-31, Q-32 and Q-34. These three are the facts that decide the rest.
2. **Answer Q-34, then Q-31 and Q-30 together**, then Q-32.
3. **Answer Q-38 and Q-40**, and say whether staging may use a provider sandbox for Q-33.
4. **Approve** `@supabase/ssr` and `@supabase/supabase-js` for 3.3 (or say not yet).

**My assessment of the minimum to start 3.3:** Q-31 and Q-34 (hard), the staging part of Q-30, Q-38 and Q-40 (so 3.3 knows what to build), plus either Q-33 as "staging sandbox" or Q-32 as "Vercel previews". Production hosting, production SMTP domain, production plan and legal advice can follow before outside publishers (3.7).

## 5. After you answer

I will record each answer in `DECISIONS.md` (new or amended decisions, status Accepted with the date) and `OPEN-QUESTIONS.md` (answered questions become a short pointer), update the plan and the environment table, and only then start 3.3 on a separate branch. Until then no hosted resource is created or connected, no dependency is added, and no DNS or hosting change is made.
