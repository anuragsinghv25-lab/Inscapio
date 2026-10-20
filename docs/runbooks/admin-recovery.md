# Runbook: sole-administrator lockout and recovery

> **Status:** Proposed · written 20 Oct 2026 for D-058 (one initial administrator, MFA required). **This is documentation of a risk and a plan. No recovery feature exists in the application.** Every Auth-level step below is marked *verified* or *unverified*; unverified steps must be tested on the local stack (spike U-11, Stage 3.3) before they are relied on. Nothing here has been run against a hosted project, and no hosted project is connected.

## 1. The risk

There is one administrator, and every administrator operation needs an aal2 session (a verified TOTP factor). Administration means inviting publishers, suspending or reinstating them, and taking content down. If that one person cannot reach aal2, **nobody can do any of it**. Two things can cause it:

| Cause | Effect |
|---|---|
| Lost or reset authenticator device (TOTP factor unusable) | Sign-in still works at aal1; every admin function refuses (verified by the 3.1 tests: aal1 is refused) |
| Lost access to the account email or the Supabase / GitHub / Vercel accounts | Cannot sign in at all; cannot reach the project to repair it |

Compromise is the other side of the same risk: a stolen authenticator or session on the only administrator account means one person can invite, suspend and take down. Administrators still cannot read private drafts (D-050), which limits the harm.

## 2. What exists today

| Fact | State |
|---|---|
| An administrator is a row in `public.admins`; roles are read live, so removal takes effect on the next query | Verified (3.1, local) |
| `private.bootstrap_admin(uuid)` adds or reactivates an administrator; `private.remove_admin(uuid)` removes one; both are owner-only and unreachable through the API | Verified (3.1, local) |
| Procedure for them: [`bootstrap-first-admin.md`](./bootstrap-first-admin.md) | Verified locally; **not run on any hosted project** |
| Break-glass access: the Supabase project owner connects directly as the database owner (`postgres`) with the database password | Documented; **unverified on a hosted project** |

## 3. Prevention (do these before the first real administrator action)

1. Turn on two-factor authentication on the Supabase, GitHub and Vercel accounts, and on the email account that receives their recovery mail.
2. Store each account's recovery codes **offline** (printed, or in a password manager that is itself recoverable). Never in the repository, never in chat.
3. When enrolling the InScapio administrator's TOTP factor, add the same secret to **two** authenticator apps or devices at enrolment time (the QR code is only shown once). *Enrolling a second, separate factor is possible only if Supabase allows several factors per user: unverified.*
4. Does Supabase TOTP provide recovery/backup codes for end users? **Not found in the documentation read (20 Oct 2026); treat as unavailable until verified.**
5. Before any outside publisher joins (Stage 3.7), revisit D-058: a second administrator, or a second Supabase organisation owner, removes the single point of failure.

## 4. Recovery procedures

### A. Lost authenticator, can still sign in

Goal: remove the dead factor, then enrol a new one.

| Step | State |
|---|---|
| The Supabase Auth admin API has a call that deletes a user's MFA factor (`auth.admin.mfa.deleteFactor`); the reference page says that deleting a verified factor logs the user out of all active sessions | Exists per documentation (read 20 Oct 2026); **the page does not state which credential it needs; not tested** |
| That call would need server-side privileged credentials (the Supabase secret key). **Per D-060 no AI session may request or handle that key**; the owner runs it himself, from a local script he keeps private | Procedure **unverified**; no script exists in the repository |
| Whether the Supabase dashboard offers a button to remove a user's factor | **Unverified** |
| Whether a user signed in at aal1 may remove their own *verified* factor without aal2 | **Unverified** (and expected to be refused) |

### B. Lost authenticator and step A does not work: create a replacement administrator

This uses only steps already verified locally.

1. As project owner, create a **new** Auth user in the dashboard with a confirmed email you control (a different address from the locked-out account).
2. Connect as `postgres` (database password from your own dashboard; never shared).
3. Run `select private.bootstrap_admin('<NEW-USER-UUID>');` (see the bootstrap runbook), then enrol a TOTP factor for the new user on first sign-in.
4. Once the new administrator works at aal2, run `select private.remove_admin('<OLD-USER-UUID>');`.
5. Record who, when and why in your private records.

Editing the `auth.mfa_factors` table directly is **not** a supported step: unverified and not to be done without testing on the local stack first.

### C. Lost access to the Supabase account itself

Use Supabase's own account recovery with the recovery codes from section 3. This is outside the repository and not verifiable here. Until it succeeds, the project cannot be reached and no database break-glass is possible.

### D. Suspected compromise

1. Run `select private.remove_admin('<USER-UUID>');` as `postgres` (effective on the next query).
2. Rotate the Supabase database password and the publishable/secret keys through the dashboard (rotation steps: V-5), and revoke the Vercel and GitHub sessions.
3. Review `audit_events` for `admin.*`, `invite.*` and `publisher.status_*` actions in the period.
4. Re-bootstrap an administrator as in B.

## 5. What is not implemented or verified (flagged)

- No in-app recovery, no second-administrator flow, no recovery codes for InScapio administrators.
- U-11: factor reset behaviour, factors per user, aal requirement to unenrol: all unverified.
- The bootstrap and removal functions were verified on a local stack only; hosted behaviour (including the `postgres` role's attributes, U-4) is unverified.
- Account-level recovery of Supabase, GitHub, Vercel and email is the owner's responsibility and unverifiable here.

## 6. Tests to add in the 3.3 spike (not written yet)

On the local stack: an aal1 session is refused by every admin function (exists); deleting a verified factor with the Auth admin API ends the sessions and the user can re-enrol (to verify); `bootstrap_admin` followed by `remove_admin` swaps administrators with no gap in the audit trail (partly covered in 3.1).
