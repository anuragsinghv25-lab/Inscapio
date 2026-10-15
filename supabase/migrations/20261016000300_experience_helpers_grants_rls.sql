-- Stage 3.2 / migration 3: helper functions, explicit grants, FORCE row level security and policies
-- for the eight experience-core tables. Deny by default: every table starts with all privileges
-- revoked from every API and service role, then receives exactly what its section lists.

-- ------------------------------------------------------------------ helpers
-- Which database role is the caller? PostgREST runs requests as `SET ROLE <jwt role>`, so the `role`
-- setting names the caller even inside SECURITY DEFINER code (where current_user is the owner).
-- A direct login connection that never ran SET ROLE is identified by session_user.
create function private.caller_role() returns name
language sql stable set search_path = '' as $$
  select case when pg_catalog.current_setting('role', true) in ('', 'none')
              then session_user::name else pg_catalog.current_setting('role')::name end
$$;

create function private.is_validator() returns boolean
language sql stable set search_path = '' as $$
  select pg_catalog.pg_has_role((select private.caller_role()), 'validator_service', 'member')
$$;

-- A human session: an authenticated end user (a verified JWT subject presented as role
-- `authenticated`). Machine roles cannot pass even if they were wrongly granted EXECUTE and forged claims.
create function private.is_human_session() returns boolean
language sql stable set search_path = '' as $$
  select (select auth.uid()) is not null
     and ((select auth.jwt()) ->> 'role') = 'authenticated'
     and pg_catalog.pg_has_role((select private.caller_role()), 'authenticated', 'member')
     and not pg_catalog.pg_has_role((select private.caller_role()), 'ai_service', 'member')
     and not pg_catalog.pg_has_role((select private.caller_role()), 'validator_service', 'member')
     and not pg_catalog.pg_has_role((select private.caller_role()), 'service_role', 'member')
$$;

create function private.owns_experience(p_experience_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select private.is_active_publisher())
     and exists (select 1 from public.experiences e
                 where e.id = p_experience_id and e.publisher_id = (select auth.uid()))
$$;

-- Today equal to owns_experience; the single place to change when organisations arrive.
create function private.can_edit_experience(p_experience_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select private.owns_experience(p_experience_id))
$$;

create function private.owns_revision(p_revision_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.revisions r
                 where r.id = p_revision_id and (select private.owns_experience(r.experience_id)))
$$;

revoke all on function private.caller_role(), private.is_validator(), private.is_human_session(),
  private.owns_experience(uuid), private.can_edit_experience(uuid), private.owns_revision(uuid)
  from public, anon, authenticated, service_role;
-- policies are evaluated as the calling role, so these three must be executable by it
grant execute on function private.owns_experience(uuid), private.can_edit_experience(uuid),
  private.owns_revision(uuid) to authenticated;

-- ------------------------------------------------------------------ grants
revoke all on public.topics, public.experiences, public.experience_topics, public.revisions,
  public.revision_validations, public.approvals, public.publications, public.published_experiences
  from public, anon, authenticated, service_role, validator_service, ai_service;

-- topics: public read; administrator writes (policies enforce is_admin)
grant select on public.topics to anon, authenticated;
grant insert (slug, title, description, position) on public.topics to authenticated;
grant update (slug, title, description, position) on public.topics to authenticated;
grant delete on public.topics to authenticated;

-- owner-visible tables: read only; every write is through a lifecycle function
grant select on public.experiences to authenticated;
grant update (archived_at) on public.experiences to authenticated;
grant select, insert, delete on public.experience_topics to authenticated;
grant select on public.revisions to authenticated;
grant select on public.revision_validations to authenticated;
grant select on public.approvals to authenticated;
grant select on public.publications to authenticated;

-- the one public table
grant select on public.published_experiences to anon, authenticated;

-- ------------------------------------------------------------------ FORCE row level security
alter table public.topics                enable row level security;
alter table public.experiences           enable row level security;
alter table public.experience_topics     enable row level security;
alter table public.revisions             enable row level security;
alter table public.revision_validations  enable row level security;
alter table public.approvals             enable row level security;
alter table public.publications          enable row level security;
alter table public.published_experiences enable row level security;
alter table public.topics                force row level security;
alter table public.experiences           force row level security;
alter table public.experience_topics     force row level security;
alter table public.revisions             force row level security;
alter table public.revision_validations  force row level security;
alter table public.approvals             force row level security;
alter table public.publications          force row level security;
alter table public.published_experiences force row level security;

-- ------------------------------------------------------------------ policies (all with explicit TO)
create policy topics_select_all on public.topics
  for select to anon, authenticated using (true);
create policy topics_insert_admin on public.topics
  for insert to authenticated with check ((select private.is_admin()));
create policy topics_update_admin on public.topics
  for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy topics_delete_admin on public.topics
  for delete to authenticated using ((select private.is_admin()));

create policy experiences_select_own on public.experiences
  for select to authenticated using ((select private.owns_experience(id)));
create policy experiences_update_own on public.experiences
  for update to authenticated
  using ((select private.owns_experience(id))) with check ((select private.owns_experience(id)));

create policy experience_topics_select_own on public.experience_topics
  for select to authenticated using ((select private.owns_experience(experience_id)));
create policy experience_topics_insert_own on public.experience_topics
  for insert to authenticated with check ((select private.can_edit_experience(experience_id)));
create policy experience_topics_delete_own on public.experience_topics
  for delete to authenticated using ((select private.can_edit_experience(experience_id)));

create policy revisions_select_own on public.revisions
  for select to authenticated using ((select private.owns_experience(experience_id)));
create policy revision_validations_select_own on public.revision_validations
  for select to authenticated using ((select private.owns_revision(revision_id)));
create policy approvals_select_own on public.approvals
  for select to authenticated using ((select private.owns_experience(experience_id)));

create policy publications_select_own on public.publications
  for select to authenticated using ((select private.owns_experience(experience_id)));
create policy publications_select_admin on public.publications
  for select to authenticated using ((select private.is_admin()));

create policy published_experiences_select_all on public.published_experiences
  for select to anon, authenticated using (true);
