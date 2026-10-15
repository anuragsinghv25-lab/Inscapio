-- pgTAP test file. Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);
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


-- ============ audit_events: administrators read, nobody writes through the API, nobody alters history
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select ok((select count(*) from public.audit_events) >= 1, 'valid: an administrator at aal2 can read the audit log');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal1');
select is((select count(*) from public.audit_events), 0::bigint, 'T-D06 denied: an administrator at aal1 cannot read the audit log');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2');
select is((select count(*) from public.audit_events), 0::bigint, 'T-D06 denied: a publisher cannot read the audit log');
select throws_ok($q$insert into public.audit_events (actor_kind, action, subject_type) values ('admin','x.y','z')$q$, '42501'::char(5), null::text, $d$T-P15 denied: no direct INSERT into audit_events$d$);
select throws_ok($q$update public.audit_events set action = 'x.y'$q$, '42501'::char(5), null::text, $d$denied: no direct UPDATE of audit_events$d$);
select throws_ok($q$delete from public.audit_events$q$, '42501'::char(5), null::text, $d$denied: no direct DELETE from audit_events$d$);
select throws_ok($q$truncate public.audit_events$q$, '42501'::char(5), null::text, $d$denied: no TRUNCATE of audit_events$d$);
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select throws_ok($q$delete from public.audit_events$q$, '42501'::char(5), null::text, $d$denied: not even an administrator can delete audit events$d$);
select t.as_anon();
select throws_ok($q$select * from public.audit_events$q$, '42501'::char(5), null::text, $d$T-A05 denied: anon cannot read the audit log$d$);
select t.as_service();
select throws_ok($q$select * from public.audit_events$q$, '42501'::char(5), null::text, $d$denied: the secret key has no privilege on audit_events$d$);
select throws_ok($q$insert into public.audit_events (actor_kind, action, subject_type) values ('admin','x.y','z')$q$, '42501'::char(5), null::text, $d$denied: the secret key cannot insert audit events$d$);
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select private.write_audit('admin', null, 'x.y', 'z', null, '{}')$q$, '42501'::char(5), null::text, $d$denied: an authenticated user cannot call the audit writer$d$);
select t.as_anon();
select throws_ok($q$select private.write_audit('admin', null, 'x.y', 'z', null, '{}')$q$, '42501'::char(5), null::text, $d$denied: anon cannot call the audit writer$d$);
-- history cannot be altered by anyone, including the table owner (trigger)
select t.as_owner();
select throws_ok($q$update public.audit_events set action = 'x.y'$q$, '55000'::char(5), null::text, $d$T-M05 the owner cannot UPDATE audit events (append-only trigger)$d$);
select throws_ok($q$delete from public.audit_events$q$, '55000'::char(5), null::text, $d$T-M05 the owner cannot DELETE audit events (append-only trigger)$d$);
select throws_ok($q$truncate public.audit_events$q$, '55000'::char(5), null::text, $d$T-M05 the owner cannot TRUNCATE audit events (append-only trigger)$d$);
-- content rules
select throws_ok($q$insert into public.audit_events (actor_kind, action, subject_type, details) values ('system','x.y','z','{"email":"a@example.test"}')$q$, '23514'::char(5), null::text, $d$audit details are restricted to an allow-list of keys: an email key is refused$d$);
select throws_ok($q$insert into public.audit_events (actor_kind, action, subject_type) values ('system','BAD ACTION','z')$q$, '23514'::char(5), null::text, $d$audit action names must match the naming rule$d$);
select throws_ok($q$insert into public.audit_events (actor_kind, action, subject_type) values ('robot','x.y','z')$q$, '23514'::char(5), null::text, $d$audit actor kinds are restricted$d$);
select lives_ok($q$select private.write_audit('system', null, 'test.noop', 'test', null, '{"from":"a","to":"b"}')$q$, 'valid: the owner-side writer accepts allow-listed details');

select * from finish();
rollback;
