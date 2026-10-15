# Runbook: bootstrap the first administrator

> **Scope:** increment 3.1 (D-050, 3.1 portion). Admin bootstrap is a documented SQL procedure run by the project owner. It is not an application feature, and there is no sign-up path to administrator.

## Preconditions

- The person already has an Auth user whose email is confirmed (created by the owner in the Auth dashboard, or by an earlier sign-in). Their `auth.users.id` is known.
- You are connected as the database owner (`postgres`) with direct database access. Do not use a Supabase secret/service-role key for this; it has no privilege on `private`.
- Use a **local** database first (`pnpm run db:start`, then the `DB_URL` from `pnpm exec supabase status -o env`). Do not run this against a hosted project until the owner has recorded that project's facts (Q-31, D-051).

## Procedure

```sql
-- 1. Confirm the target is a real, confirmed user (replace the placeholder).
select id, email_confirmed_at is not null as confirmed
from auth.users
where id = '<USER-UUID>';

-- 2. Grant the admin record. Idempotent; raises if the user does not exist.
select private.bootstrap_admin('<USER-UUID>');

-- 3. Verify.
select user_id, status, created_at from public.admins where user_id = '<USER-UUID>';
```

An administrator can use admin functions only in a session at **aal2** (TOTP enrolled and verified). Enrol a factor before the first admin action; at aal1 every admin operation is refused.

## Removing an administrator

```sql
select private.remove_admin('<USER-UUID>');
```

Access ends on the next query (roles are read live, not from the token).

## Recording

Do not commit user ids, emails or keys to the repository. Record who was bootstrapped, when and why in the owner's private records.
