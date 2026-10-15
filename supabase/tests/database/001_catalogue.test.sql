-- pgTAP test file. Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);
create schema t;
grant usage on schema t to public;
create function t.as_user(p_uid uuid, p_aal text default 'aal1', p_extra jsonb default '{}'::jsonb)
returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', p_uid, 'role', 'authenticated', 'aal', p_aal) || p_extra)::text, true);
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
create function t.as_owner() returns void language plpgsql as $f$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $f$;
grant execute on all functions in schema t to public;

-- fixtures (owner)
insert into auth.users (id, email, email_confirmed_at, aud, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'admin@example.test',     now(), 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b1', 'pub1@example.test',      now(), 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b2', 'pub2@example.test',      now(), 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b3', 'suspended@example.test', now(), 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000b4', 'revoked@example.test',   now(), 'authenticated', 'authenticated'),
  ('00000000-0000-4000-8000-0000000000c1', 'nobody@example.test',    now(), 'authenticated', 'authenticated');
select private.bootstrap_admin('00000000-0000-4000-8000-0000000000a1');
insert into public.publishers (id, status, status_reason) values
  ('00000000-0000-4000-8000-0000000000b1', 'active', null),
  ('00000000-0000-4000-8000-0000000000b2', 'active', null),
  ('00000000-0000-4000-8000-0000000000b3', 'suspended', 'synthetic fixture'),
  ('00000000-0000-4000-8000-0000000000b4', 'revoked', 'synthetic fixture');

-- T-M01 / T-M06: structure, RLS and policy hygiene (catalogue checks)
select set_eq($$select tablename::text from pg_tables where schemaname = 'public'$$,
  $$values ('admins'), ('audit_events'), ('invites'), ('publishers')$$,
  'T-M01 public contains exactly the four 3.1 tables (a new table must be added to this test with its policy tests)');
select is_empty($$select tablename from pg_tables where schemaname = 'public' and not rowsecurity$$,
  'T-M01 RLS is enabled on every public table');
select is_empty($$select viewname from pg_views where schemaname = 'public'$$,
  'T-M04 no views in the exposed schema');

-- T-M02: table privileges, excluding the owner, exactly as designed
select set_eq($$
  select c.relname::text, case when a.grantee = 0 then 'PUBLIC' else a.grantee::regrole::text end, a.privilege_type::text
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
  where n.nspname in ('public','private') and c.relkind in ('r','v','m','S','p') and a.grantee <> c.relowner
$$, $$values ('admins','authenticated','SELECT'), ('audit_events','authenticated','SELECT'),
            ('invites','authenticated','SELECT'), ('publishers','authenticated','SELECT')$$,
  'T-M02 table grants: anon and service_role hold none; authenticated holds SELECT only (plus column UPDATE below)');
select set_eq($$
  select c.relname::text, a.attname::text, case when x.grantee = 0 then 'PUBLIC' else x.grantee::regrole::text end, x.privilege_type::text
  from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
  cross join lateral aclexplode(a.attacl) x
  where n.nspname = 'public' and a.attacl is not null and x.grantee <> c.relowner
$$, $$values ('publishers','handle','authenticated','UPDATE'), ('publishers','display_name','authenticated','UPDATE'),
            ('publishers','bio','authenticated','UPDATE')$$,
  'T-M02 column grants: authenticated may update only handle, display_name, bio on publishers');

-- T-M03: functions
select is_empty($$
  select n.nspname || '.' || p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public','private') and not coalesce(p.proconfig @> array['search_path=""'], false)
$$, 'T-M03 every function in public/private has an empty search_path');
select set_eq($$
  select n.nspname || '.' || p.proname, case when x.grantee = 0 then 'PUBLIC' else x.grantee::regrole::text end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x
  where n.nspname in ('public','private') and x.grantee <> p.proowner
$$, $$values ('private.current_publisher_id','authenticated'), ('private.is_active_publisher','authenticated'),
            ('private.is_admin','authenticated'), ('public.create_invite','authenticated'),
            ('public.revoke_invite','authenticated'), ('public.redeem_invite','authenticated'),
            ('public.set_publisher_status','authenticated')$$,
  'T-M03 EXECUTE grants: nothing to PUBLIC or anon; owner-only for audit writer, bootstrap and trigger functions');

-- T-M06: policies
select set_eq($$select tablename::text, policyname::text, cmd::text, array_to_string(roles, ',') from pg_policies where schemaname = 'public'$$,
  $$values ('admins','admins_select_admin','SELECT','authenticated'),
           ('publishers','publishers_select_own','SELECT','authenticated'),
           ('publishers','publishers_select_admin','SELECT','authenticated'),
           ('publishers','publishers_update_own_active','UPDATE','authenticated'),
           ('invites','invites_select_admin','SELECT','authenticated'),
           ('audit_events','audit_events_select_admin','SELECT','authenticated')$$,
  'T-M06 exactly the designed policies exist, each with an explicit TO authenticated');
select is_empty($$select policyname from pg_policies where schemaname = 'public' and 'public' = any(roles)$$,
  'T-M06 no policy applies to PUBLIC');
select is_empty($$select policyname from pg_policies where schemaname = 'public' and cmd in ('INSERT','DELETE','ALL')$$,
  'T-M06 no INSERT, DELETE or ALL policy: writes exist only through the definer functions');

-- structural design rules
select is_empty($$select column_name from information_schema.columns where table_schema = 'public' and column_name ilike '%token%'$$,
  'invitations carry no bearer token (D-046 invitation portion)');
select hasnt_column('public', 'publishers', 'email', 'publishers stores no email address');
select ok(exists(select 1 from pg_indexes where schemaname = 'public' and indexname = 'invites_one_pending_per_email'),
  'at most one pending invitation per email is a unique partial index');
select has_trigger('public', 'audit_events', 'audit_events_append_only', 'T-M05 audit_events row-level append-only trigger');
select has_trigger('public', 'audit_events', 'audit_events_no_truncate', 'T-M05 audit_events truncate guard');
select is_empty($$select conname from pg_constraint where conrelid = 'public.audit_events'::regclass and contype = 'f'$$,
  'audit_events has no foreign keys, so the record outlives accounts');

select * from finish();
rollback;
