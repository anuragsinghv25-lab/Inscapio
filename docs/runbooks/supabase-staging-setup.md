# Runbook: create the Supabase staging project and configure environment variables

> **Status:** Proposed · written 20 Oct 2026 for D-057, D-059, D-060. **You do all of this yourself, in your own browser.** No AI session creates, connects or inspects a hosted project, and none needs any secret. Menu names in Supabase and Vercel change; where this guide names a screen it is a pointer, not a verified click path. If something differs or is missing (a region, a feature on your plan), **stop and tell me what you see, without pasting any key or password.**
>
> **Do not apply migrations or create tables.** Nothing from this repository is applied to a hosted project until you say "staging is ready" (D-057) and we have reviewed a deployment step together.

## What you will end up with

- A new Supabase project called `inscapio-staging`, separate from your existing scratch project, holding **synthetic data only**.
- A Vercel project linked to the GitHub repository, producing **preview** deployments only. `inscapio.in` is not touched.
- The Supabase project URL and publishable key stored in Vercel (Preview scope) and in a local `.env.local` that git ignores.

## Part 0. Protect your accounts first (about 20 minutes)

1. Turn on two-factor authentication for Supabase, GitHub, Vercel and the email account behind them.
2. Save each service's recovery codes **offline**. Never in the repository or in chat.
3. Use a password manager. You will generate one database password in it in Part 1.

Why: you are the only administrator (D-058). See [`admin-recovery.md`](./admin-recovery.md).

## Part 1. Supabase staging project

1. Sign in to the Supabase dashboard. Look at your organisation list. If you want a dedicated organisation for InScapio, create it now: moving a project between organisations later is a project transfer, not a migration (V-12). This is Q-34's open part; either choice is fine, but make it deliberately.
2. Choose **New project** in that organisation and enter:
   - **Name:** `inscapio-staging`.
   - **Database password:** generate a long random one in your password manager and save it there. **Do not paste it anywhere else, including to me.**
   - **Region:** pick **South Asia (Mumbai)** (`ap-south-1`) if it is offered to you. It cannot be assumed that the region can be changed later, so if it is not offered or the plan restricts it, stop and tell me.
   - **Plan:** read the price and the limits shown for your organisation's plan before confirming. At the time of the earlier review, the free plan had no backups, paused projects after a week of inactivity and allowed two active projects (V-8). That is acceptable for **staging with synthetic data only**, not for real data. Prices change: you verify.
3. Wait until the project shows as healthy.
4. Open the project's API / connection settings and note two **non-secret** values: the **Project URL** and the **publishable key** (it starts with `sb_publishable_`). If the page only shows older keys named `anon` / `service_role`, tell me; do not copy anything. **Never copy the secret key or the `service_role` key anywhere for this project.**
5. Open the Authentication settings and set:
   - Email sign-in **enabled**.
   - **Allow new users to sign up: OFF** (the design assumes invited users only; the consequence is Q-44).
   - **Confirm email: ON.**
   - Link / one-time-code expiry: leave the default (one hour). Do not raise it above 24 hours.
   - Multi-factor authentication: make sure **TOTP** is enabled. If it is not available on your plan, tell me (U-8).
6. **URL configuration:** leave the Site URL as `http://localhost:3000` for now. I will give you the exact redirect list in the 3.3 PR, once the Vercel preview address exists.
7. **Email (SMTP):** leave the built-in sender as it is; it allows about two emails per hour and is only for trying things. Custom SMTP is Q-33 and is deliberately undecided. Do not touch any DNS record.
8. Do not create tables, run SQL, enable extra services, or invite anyone.

## Part 2. Vercel preview deployments

1. Create a Vercel account using **Continue with GitHub**.
2. **Check the plan before relying on it.** Vercel's pages (read 20 Oct 2026) say the Hobby plan "restricts users to non-commercial, personal use only." If InScapio staging counts as commercial use for you, you need a paid plan (a developer seat was about $20 per month then). You decide from Vercel's current terms.
3. When Vercel asks which GitHub repositories it may access, choose **only `Inscapio`** (select repositories), not all repositories.
4. Import the repository. Framework: Next.js (detected automatically). Node 22 if it asks.
5. **Do not add any domain.** Do not touch `inscapio.in` or its DNS. Without a domain added, deployments live only on Vercel's own addresses.
6. Before the first deployment, add the two environment variables from Part 3 with the scope **Preview** only.
7. In the project's deployment-protection settings, keep **Vercel Authentication** on so preview URLs are not public.
8. Note: pushing the `main` branch will create a "Production" deployment on a Vercel address, not on `inscapio.in`. It does not replace your current production hosting. If you would rather avoid even that, tell me and I will look for a setting to confirm before you change anything.

## Part 3. Environment variables (where each value goes)

The repository's [`.env.example`](../../.env.example) lists the **names only**.

| Name | What it is | Where you set it |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | the staging Project URL (not secret) | Vercel > Project Settings > Environment Variables, **Preview**; and `.env.local` |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | the staging publishable key (not secret by design) | same two places |
| `NEXT_PUBLIC_SITE_URL` | optional | leave unset for now |
| `SUPABASE_SECRET_KEY` | secret, server-only | **leave empty** in Stage 3.3 staging; set only if we later decide it is needed (Stage 3.4 or Q-44), by you, never sent to me |
| `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_ID` | for a later CI migration job | **GitHub** > repository Settings > Secrets and variables > Actions, **only after** you say staging is ready |

Local file: copy `.env.example` to `.env.local`, fill the two public values, and run `git status`; `.env.local` must **not** appear (it is ignored).

## Part 4. Tell me it is ready (no secrets)

Send me a message saying **"staging is ready"** and answer, in your own words:

- Region shown on the project, and plan and price shown.
- Postgres version (shown in the project's settings).
- Whether "Allow new users to sign up" is off, and whether TOTP MFA is enabled.
- Which key type the project shows (publishable or legacy).
- Whether the Vercel account is created, which plan, and whether the preview deployment worked.
- The status of your existing scratch project if you looked at it (organisation, region, plan; no keys).

Then I will prepare, as a reviewed PR, the redirect list and the staging migration job. **Migrations are applied only after you approve that PR and set the GitHub secrets yourself.**

## Never

- Never send me or paste anywhere: your account passwords, the database password, the secret key, the `service_role` key, or an access token.
- Never put real people's data into staging.
- Never change DNS, add `inscapio.in` to Vercel, or turn off your current production hosting without telling me first.
