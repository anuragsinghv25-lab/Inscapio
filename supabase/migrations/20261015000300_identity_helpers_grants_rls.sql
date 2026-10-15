-- Stage 3.1 / migration 3: helper functions, explicit grants, RLS and policies.
-- Roles are DATABASE RECORDS (admins, publishers), never JWT claims or user metadata (D-045).

-- ---------------------------------------------------------------- helpers
-- The active publisher id of the caller, or null. Status is read live on every call, so a
-- suspended or revoked publisher loses access immediately even while their token is valid.
create function private.current_publisher_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.publishers p
  where p.id = (select auth.uid())
    and p.status = 'active';
$$;

create function private.is_active_publisher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select private.current_publisher_id()) is not null;
$$;

-- Administrator: an active admins row AND a verified second factor (aal2) in the token.
create function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
           select 1 from public.admins a
           where a.user_id = (select auth.uid()) and a.status = 'active')
     and coalesce((select auth.jwt()) ->> 'aal', '') = 'aal2';
$$;

revoke all on function private.current_publisher_id() from public, anon, authenticated, service_role;
revoke all on function private.is_active_publisher() from public, anon, authenticated, service_role;
revoke all on function private.is_admin() from public, anon, authenticated, service_role;
grant execute on function private.current_publisher_id() to authenticated;
grant execute on function private.is_active_publisher() to authenticated;
grant execute on function private.is_admin() to authenticated;

-- ---------------------------------------------------------------- grants
-- Nothing is granted to anon or service_role. authenticated gets the minimum below.
revoke all on public.admins, public.publishers, public.invites, public.audit_events
  from public, anon, authenticated, service_role;

grant select on public.admins to authenticated;
grant select on public.publishers to authenticated;
grant update (handle, display_name, bio) on public.publishers to authenticated;
grant select on public.invites to authenticated;
grant select on public.audit_events to authenticated;

-- ---------------------------------------------------------------- RLS
-- ENABLE and FORCE (test plan T-M01). FORCE makes the table owner subject to the policies too.
-- The SECURITY DEFINER functions are owned by the migration role (postgres), which has BYPASSRLS
-- in the Supabase stack, so they still write; 001_catalogue.test.sql asserts that dependency.
-- Direct writes by API roles are prevented by the absence of grants and of policies.
alter table public.admins       enable row level security;
alter table public.publishers   enable row level security;
alter table public.invites      enable row level security;
alter table public.audit_events enable row level security;
alter table public.admins       force row level security;
alter table public.publishers   force row level security;
alter table public.invites      force row level security;
alter table public.audit_events force row level security;

create policy admins_select_admin on public.admins
  for select to authenticated
  using ((select private.is_admin()));

create policy publishers_select_own on public.publishers
  for select to authenticated
  using (id = (select auth.uid()) and (select private.is_active_publisher()));

create policy publishers_select_admin on public.publishers
  for select to authenticated
  using ((select private.is_admin()));

create policy publishers_update_own_active on public.publishers
  for update to authenticated
  using (id = (select auth.uid()) and (select private.is_active_publisher()))
  with check (id = (select auth.uid()) and (select private.is_active_publisher()));

create policy invites_select_admin on public.invites
  for select to authenticated
  using ((select private.is_admin()));

create policy audit_events_select_admin on public.audit_events
  for select to authenticated
  using ((select private.is_admin()));
