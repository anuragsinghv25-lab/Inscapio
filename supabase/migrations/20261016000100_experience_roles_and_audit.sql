-- Stage 3.2 / migration 1: service roles with no privileges, safer function defaults, and the
-- widened audit-detail allow-list. Forward-only; the 3.1 migrations are untouched.

-- validator_service attests that a stored document passed the full validation (Q-43, R-1).
-- ai_service is created now so its (absent) privileges can be tested (T-X01..T-X07); it receives
-- nothing in Stage 3. Neither role can log in here: a later increment creates a login role that is
-- a member of the one it needs, with the password supplied outside the repository.
-- Neither is BYPASSRLS, superuser, or a member of any Supabase API role.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'validator_service') then
    create role validator_service nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'ai_service') then
    create role ai_service nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;
  end if;
end $$;

-- Defense in depth: a function created later in these schemas is not executable by PUBLIC until
-- a migration grants it to a named role. (3.1 already revokes explicitly per function.)
alter default privileges for role postgres in schema public revoke execute on functions from public;
alter default privileges for role postgres in schema private revoke execute on functions from public;

-- Audit details stay a closed allow-list of ids and codes: never content, never email.
create or replace function private.audit_details_ok(d jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(d) = 'object'
     and not exists (
       select 1 from jsonb_object_keys(d) as k
       where k not in ('invite_id', 'ttl_days', 'from', 'to',
                       'experience_id', 'revision_id', 'publication_id', 'topic_id',
                       'seq', 'reason_code', 'validator_version', 'passed', 'held'));
$$;
