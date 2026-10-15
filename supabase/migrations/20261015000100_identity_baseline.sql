-- Stage 3.1 / migration 1: baseline hygiene (deny by default).
-- Design: docs/architecture/supabase-data-model.md section 2 (conventions).

-- A schema that is NOT exposed through the API. It holds helper and trigger
-- functions. Only `authenticated` may resolve names in it, because RLS policies
-- call helpers as the requesting role.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated, service_role;
grant usage on schema private to authenticated;

-- Objects created by migrations (owner: postgres) receive NO implicit grants.
-- Every table and function below states its grants explicitly.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke all on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema private
  revoke all on functions from anon, authenticated, service_role;

-- Append-only guard used by audit_events (and later by revisions, approvals).
create function private.forbid_modification()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'table % is append-only', tg_table_name using errcode = '55000';
end;
$$;
revoke all on function private.forbid_modification() from public, anon, authenticated, service_role;
