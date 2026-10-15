-- pgTAP test file. Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
select plan(27);
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


-- ============ admins: authorisation requires an admins record AND aal2 (T-D01, T-D02, T-S04, T-S05)
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select is((select count(*) from public.admins), 1::bigint, 'T-D01 valid: an active admin at aal2 can read the admins table');
select is((select private.is_admin()), true, 'valid: is_admin() is true for an active admin at aal2');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal1');
select is((select count(*) from public.admins), 0::bigint, 'T-D02 denied: the same admin at aal1 sees no admin rows');
select is((select private.is_admin()), false, 'T-D02 denied: is_admin() is false at aal1');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2');
select is((select count(*) from public.admins), 0::bigint, 'T-D01 denied: a publisher (even at aal2) sees no admin rows');
select is((select private.is_admin()), false, 'T-D01 denied: a publisher is not an admin');
select t.as_user('00000000-0000-4000-8000-0000000000c1', 'aal2');
select is((select private.is_admin()), false, 'denied: an authenticated user with no capability is not an admin');
-- client-supplied role values are never authoritative
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2', '{"user_role":"admin","app_metadata":{"role":"admin","roles":["admin"]},"user_metadata":{"role":"admin"}}'::jsonb);
select is((select private.is_admin()), false, 'T-S04 denied: role/app_metadata/user_metadata claims saying admin do not make anyone an admin');
select throws_ok($q$select public.create_invite('x@example.test')$q$, '42501'::char(5), null::text,
  'T-S04 denied: a publisher with forged admin claims cannot create invitations');
-- direct writes: no grants (self-promotion, T-I01 family)
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2');
select throws_ok($q$insert into public.admins (user_id) values ('00000000-0000-4000-8000-0000000000b1')$q$, '42501'::char(5), null::text, 'denied: a publisher cannot promote themselves to administrator');
select throws_ok($q$update public.admins set status = 'active'$q$, '42501'::char(5), null::text, 'denied: a publisher cannot update admins');
select throws_ok($q$delete from public.admins$q$, '42501'::char(5), null::text, 'denied: a publisher cannot delete admins');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select throws_ok($q$insert into public.admins (user_id) values ('00000000-0000-4000-8000-0000000000b1')$q$, '42501'::char(5), null::text, 'denied: even an admin cannot add admins through the API');
select throws_ok($q$delete from public.admins$q$, '42501'::char(5), null::text, 'denied: even an admin cannot delete admins through the API');
select t.as_anon();
select throws_ok($q$select * from public.admins$q$, '42501'::char(5), null::text, 'T-A05 denied: anon cannot read admins');
select t.as_service();
select throws_ok($q$select * from public.admins$q$, '42501'::char(5), null::text, 'denied: the secret key (service_role) has no privilege on admins');
select throws_ok($q$insert into public.admins (user_id) values ('00000000-0000-4000-8000-0000000000b1')$q$, '42501'::char(5), null::text, 'denied: the secret key cannot create admins');
-- bootstrap procedure is owner-only
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select throws_ok($q$select private.bootstrap_admin('00000000-0000-4000-8000-0000000000b1')$q$, '42501'::char(5), null::text, 'denied: an admin cannot run the bootstrap procedure');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2');
select throws_ok($q$select private.remove_admin('00000000-0000-4000-8000-0000000000a1')$q$, '42501'::char(5), null::text, 'denied: a publisher cannot remove admins');
select t.as_anon();
select throws_ok($q$select private.bootstrap_admin('00000000-0000-4000-8000-0000000000b1')$q$, '42501'::char(5), null::text, 'denied: anon cannot run the bootstrap procedure');
select t.as_service();
select throws_ok($q$select private.bootstrap_admin('00000000-0000-4000-8000-0000000000b1')$q$, '42501'::char(5), null::text, 'denied: the secret key cannot run the bootstrap procedure');
select t.as_owner();
select lives_ok($q$select private.bootstrap_admin('00000000-0000-4000-8000-0000000000b1')$q$, 'valid: the owner can bootstrap an administrator');
select is((select count(*) from public.audit_events where action = 'admin.bootstrapped' and subject_id = '00000000-0000-4000-8000-0000000000b1'::uuid), 1::bigint, 'bootstrap writes one audit event');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2');
select is((select private.is_admin()), true, 'valid: a bootstrapped user is an admin at aal2');
select t.as_owner();
select lives_ok($q$select private.remove_admin('00000000-0000-4000-8000-0000000000b1')$q$, 'valid: the owner can remove an administrator');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2');
select is((select private.is_admin()), false, 'denied: a removed administrator is no longer an admin, even with a valid aal2 token');
select t.as_owner();
select throws_ok($q$select private.remove_admin('00000000-0000-4000-8000-0000000000b1')$q$, '55000'::char(5), null::text, 'removing an already-removed administrator is refused');

select * from finish();
rollback;
