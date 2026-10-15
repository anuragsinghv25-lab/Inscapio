-- pgTAP test file (Stage 3.2). Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(30);
create schema t;
grant usage on schema t to public;
create function t.as_user(p_uid uuid, p_aal text default 'aal1', p_extra jsonb default '{}'::jsonb)
returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_uid, 'role', 'authenticated', 'aal', p_aal) || p_extra)::text, true);
  execute 'set local role authenticated';
end $f$;
create function t.as_authenticated_nosub() returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', '{"role":"authenticated"}', true);
  execute 'set local role authenticated';
end $f$;
create function t.as_anon() returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  execute 'set local role anon';
end $f$;
create function t.as_service() returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  execute 'set local role service_role';
end $f$;
create function t.as_validator() returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'set local role validator_service';
end $f$;
create function t.as_ai() returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'set local role ai_service';
end $f$;
create function t.as_owner() returns void language plpgsql as $f$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $f$;
create table t.ids (k text primary key, v uuid);
grant all on t.ids to public;
create function t.id(p_k text) returns uuid language sql stable as $f$ select v from t.ids where k = p_k $f$;
-- a structurally valid document (shape gate only; the full Zod validation is attested separately)
create function t.doc(p_slug text, p_title text default 'Synthetic title',
                      p_para text default 'Synthetic paragraph.', p_kind text default 'explainer')
returns jsonb language sql immutable as $f$
  select jsonb_build_object('schemaVersion', 1, 'id', p_slug, 'slug', p_slug, 'kind', p_kind, 'title', p_title,
    'shortTitle', 'Short', 'language', 'en', 'summary', 'Synthetic summary.', 'theme', '{}'::jsonb,
    'reading', '[]'::jsonb,
    'hero', jsonb_build_object('title', p_title, 'intro', jsonb_build_array('Intro.'), 'actions', '[]'::jsonb),
    'sections', jsonb_build_array(jsonb_build_object('id', 'one', 'title', 'One',
       'blocks', jsonb_build_array(jsonb_build_object('type', 'paragraph', 'text', p_para)))),
    'sources', '[]'::jsonb, 'endnotes', '[]'::jsonb)
$f$;
grant execute on all functions in schema t to public;
grant validator_service to postgres;
grant ai_service to postgres;

-- fixtures (owner)
insert into auth.users (id, email, email_confirmed_at, aud, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'admin@example.test',     now(), 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b1',    'pub-a@example.test',     now(), 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b2',    'pub-b@example.test',     now(), 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b3',    'suspended@example.test', now(), 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b4',    'revoked@example.test',   now(), 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c1','nobody@example.test',    now(), 'authenticated', 'authenticated');
select private.bootstrap_admin('00000000-0000-4000-8000-0000000000a1');
insert into public.publishers (id, status, status_reason) values
  ('00000000-0000-4000-8000-0000000000b1', 'active', null), ('00000000-0000-4000-8000-0000000000b2', 'active', null),
  ('00000000-0000-4000-8000-0000000000b3', 'suspended', 'synthetic fixture'), ('00000000-0000-4000-8000-0000000000b4', 'revoked', 'synthetic fixture');

-- T-M01..T-M06 for the whole database after Stage 3.2: exact inventories, so any added table, grant, policy or function fails here until it is reviewed
select set_eq($$select tablename::text from pg_tables where schemaname = 'public'$$,
  $$values ('admins'),('audit_events'),('invites'),('publishers'),('topics'),('experiences'),('experience_topics'),
           ('revisions'),('revision_validations'),('approvals'),('publications'),('published_experiences')$$,
  'T-M01 public contains exactly the twelve Stage 3.1 and 3.2 tables');
select is_empty($$select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r','p') and not (c.relrowsecurity and c.relforcerowsecurity)$$,
  'T-M01 RLS is enabled AND forced on every public table, including the eight experience-core tables');
select is_empty($$select viewname from pg_views where schemaname = 'public'$$, 'T-M04 no views in the exposed schema');
select set_eq($$
  select c.relname::text, case when a.grantee = 0 then 'PUBLIC' else a.grantee::regrole::text end, a.privilege_type::text
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
  where n.nspname in ('public','private') and c.relkind in ('r','v','m','S','p') and a.grantee <> c.relowner
$$, $$values
  ('admins','authenticated','SELECT'), ('audit_events','authenticated','SELECT'), ('invites','authenticated','SELECT'),
  ('publishers','authenticated','SELECT'),
  ('topics','anon','SELECT'), ('topics','authenticated','SELECT'), ('topics','authenticated','DELETE'),
  ('experiences','authenticated','SELECT'),
  ('experience_topics','authenticated','SELECT'), ('experience_topics','authenticated','INSERT'),
  ('experience_topics','authenticated','DELETE'),
  ('revisions','authenticated','SELECT'), ('revision_validations','authenticated','SELECT'),
  ('approvals','authenticated','SELECT'), ('publications','authenticated','SELECT'),
  ('published_experiences','anon','SELECT'), ('published_experiences','authenticated','SELECT')$$,
  'T-M02 table grants are exactly the designed set; service_role, validator_service and ai_service hold none; no INSERT/UPDATE/DELETE on approvals, publications, published_experiences, revisions or validations for any API role');
select set_eq($$
  select c.relname::text, a.attname::text, case when x.grantee = 0 then 'PUBLIC' else x.grantee::regrole::text end, x.privilege_type::text
  from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
  cross join lateral aclexplode(a.attacl) x
  where n.nspname = 'public' and a.attacl is not null and x.grantee <> c.relowner
$$, $$values
  ('publishers','handle','authenticated','UPDATE'), ('publishers','display_name','authenticated','UPDATE'),
  ('publishers','bio','authenticated','UPDATE'),
  ('experiences','archived_at','authenticated','UPDATE'),
  ('topics','slug','authenticated','INSERT'), ('topics','title','authenticated','INSERT'),
  ('topics','description','authenticated','INSERT'), ('topics','position','authenticated','INSERT'),
  ('topics','slug','authenticated','UPDATE'), ('topics','title','authenticated','UPDATE'),
  ('topics','description','authenticated','UPDATE'), ('topics','position','authenticated','UPDATE')$$,
  'T-P13 column grants: authenticated may update only archived_at on experiences (never owner, slug, kind, title, head or hold columns)');
select is_empty($$
  select n.nspname || '.' || p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public','private') and not coalesce(p.proconfig @> array['search_path=""'], false)
$$, 'T-M03 every function in public/private has an empty search_path');
select is_empty($$
  select n.nspname || '.' || p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f' and not p.prosecdef
$$, 'T-M03 every function in the exposed schema is SECURITY DEFINER (re-checking authorisation itself)');
select set_eq($$
  select n.nspname || '.' || p.proname, case when x.grantee = 0 then 'PUBLIC' else x.grantee::regrole::text end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x
  where n.nspname in ('public','private') and x.grantee <> p.proowner
$$, $$values
  ('private.current_publisher_id','authenticated'), ('private.is_active_publisher','authenticated'),
  ('private.is_admin','authenticated'),
  ('private.owns_experience','authenticated'), ('private.can_edit_experience','authenticated'),
  ('private.owns_revision','authenticated'),
  ('public.create_invite','authenticated'), ('public.revoke_invite','authenticated'),
  ('public.redeem_invite','authenticated'), ('public.set_publisher_status','authenticated'),
  ('public.create_experience','authenticated'), ('public.save_revision','authenticated'),
  ('public.approve_revision','authenticated'), ('public.publish_revision','authenticated'),
  ('public.unpublish_experience','authenticated'), ('public.admin_takedown','authenticated'),
  ('public.set_experience_hold','authenticated'),
  ('public.record_validation','validator_service'), ('public.get_revision_for_validation','validator_service')$$,
  'T-M03 EXECUTE grants are exactly the designed set: nothing to PUBLIC or anon; only validator_service may run the two validator functions; ai_service and service_role may run nothing');
select set_eq($$select tablename::text, policyname::text, cmd::text, array_to_string(roles, ',') from pg_policies where schemaname = 'public'$$,
  $$values
  ('admins','admins_select_admin','SELECT','authenticated'),
  ('publishers','publishers_select_own','SELECT','authenticated'),
  ('publishers','publishers_select_admin','SELECT','authenticated'),
  ('publishers','publishers_update_own_active','UPDATE','authenticated'),
  ('invites','invites_select_admin','SELECT','authenticated'),
  ('audit_events','audit_events_select_admin','SELECT','authenticated'),
  ('topics','topics_select_all','SELECT','anon,authenticated'),
  ('topics','topics_insert_admin','INSERT','authenticated'),
  ('topics','topics_update_admin','UPDATE','authenticated'),
  ('topics','topics_delete_admin','DELETE','authenticated'),
  ('experiences','experiences_select_own','SELECT','authenticated'),
  ('experiences','experiences_update_own','UPDATE','authenticated'),
  ('experience_topics','experience_topics_select_own','SELECT','authenticated'),
  ('experience_topics','experience_topics_insert_own','INSERT','authenticated'),
  ('experience_topics','experience_topics_delete_own','DELETE','authenticated'),
  ('revisions','revisions_select_own','SELECT','authenticated'),
  ('revision_validations','revision_validations_select_own','SELECT','authenticated'),
  ('approvals','approvals_select_own','SELECT','authenticated'),
  ('publications','publications_select_own','SELECT','authenticated'),
  ('publications','publications_select_admin','SELECT','authenticated'),
  ('published_experiences','published_experiences_select_all','SELECT','anon,authenticated')$$,
  'T-M06 exactly the designed policies exist, each with an explicit TO clause');
select is_empty($$select policyname from pg_policies where schemaname = 'public' and 'public' = any(roles)$$, 'T-M06 no policy applies to PUBLIC');
select is_empty($$select policyname from pg_policies where schemaname = 'public' and cmd = 'ALL'$$, 'T-M06 no FOR ALL policy exists');
select is_empty($$select policyname from pg_policies where schemaname = 'public' and cmd in ('INSERT','UPDATE','DELETE')
  and tablename in ('revisions','revision_validations','approvals','publications','published_experiences','audit_events','admins','invites')$$,
  'T-M06 no write policy exists on revisions, validations, approvals, publications, the public projection, audit, admins or invites');
-- T-M05 and structural invariants
select has_trigger('public', 'revisions', 'revisions_append_only', 'T-M05 trigger revisions_append_only exists on revisions');
select has_trigger('public', 'revision_validations', 'revision_validations_append_only', 'T-M05 trigger revision_validations_append_only exists on revision_validations');
select has_trigger('public', 'approvals', 'approvals_append_only', 'T-M05 trigger approvals_append_only exists on approvals');
select has_trigger('public', 'publications', 'publications_no_delete', 'T-M05 trigger publications_no_delete exists on publications');
select has_trigger('public', 'publications', 'publications_update_guard', 'T-M05 trigger publications_update_guard exists on publications');
select has_trigger('public', 'experiences', 'experiences_guard', 'T-M05 trigger experiences_guard exists on experiences');
select has_trigger('public', 'revisions', 'revisions_hash', 'T-M05 trigger revisions_hash exists on revisions');
select has_trigger('public', 'revisions', 'revisions_no_truncate', 'T-M05 truncate is refused on revisions');
select has_trigger('public', 'revision_validations', 'revision_validations_no_truncate', 'T-M05 truncate is refused on revision_validations');
select has_trigger('public', 'approvals', 'approvals_no_truncate', 'T-M05 truncate is refused on approvals');
select has_trigger('public', 'publications', 'publications_no_truncate', 'T-M05 truncate is refused on publications');
select ok(exists(select 1 from pg_indexes where schemaname='public' and indexname='publications_one_live_per_experience'
  and indexdef ilike '%where%unpublished_at is null%'), 'T-L09 at most one live publication per experience is a partial unique index');
select ok((select condeferrable and condeferred from pg_constraint where conname='experiences_head_fk'),
  'the head pointer is a DEFERRABLE INITIALLY DEFERRED foreign key');
select is((select count(*) from pg_constraint where conname in ('approvals_revision_hash_fk','approvals_revision_experience_fk',
  'revision_validations_revision_fk','publications_approval_fk') and contype = 'f'), 4::bigint,
  'attestations, approvals and publications are bound to the exact revision, content hash and experience by foreign keys');
select is_empty($$select conname from pg_constraint where conrelid = 'public.audit_events'::regclass and contype='f'$$,
  'audit_events still has no foreign keys');
select is((select cardinality(private.known_block_types())), 15, 'the shape gate knows exactly the 15 block types of the content schema');
-- service roles: T-X05 structural facts
select is_empty($$select rolname from pg_roles where rolname in ('validator_service','ai_service')
  and (rolsuper or rolbypassrls or rolcanlogin or rolcreaterole or rolcreatedb or rolreplication or rolinherit)$$,
  'validator_service and ai_service cannot log in and hold no superuser, BYPASSRLS, CREATEROLE, CREATEDB or REPLICATION attribute');
select is_empty($$select r.rolname from pg_auth_members m join pg_roles r on r.oid = m.member
  where r.rolname in ('validator_service','ai_service')$$,
  'validator_service and ai_service are members of no other role (not authenticated, not service_role)');

select * from finish();
rollback;
