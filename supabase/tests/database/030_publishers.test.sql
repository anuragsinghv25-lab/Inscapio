-- pgTAP test file. Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(56);
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


-- ============ reading publisher rows
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select is((select count(*) from public.publishers), 1::bigint, 'valid: a publisher can read their own publisher row');
select is((select count(*) from public.publishers where id = '00000000-0000-4000-8000-0000000000b2'), 0::bigint, 'denied: a publisher cannot read another publisher''s row');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select is((select count(*) from public.publishers), 4::bigint, 'valid: an administrator at aal2 can read all publisher rows');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal1');
select is((select count(*) from public.publishers), 0::bigint, 'denied: an administrator at aal1 cannot read publisher rows');
select t.as_user('00000000-0000-4000-8000-0000000000c1', 'aal1');
select is((select count(*) from public.publishers), 0::bigint, 'denied: a user with no capability sees no publisher rows');
select t.as_anon();
select throws_ok($q$select * from public.publishers$q$, '42501'::char(5), null::text, $d$T-A05 denied: anon cannot read publishers (no public profile exists before 3.2)$d$);

-- ============ a publisher editing their own profile
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$update public.publishers set display_name = 'Synthetic One', bio = 'A synthetic bio.', handle = 'synthetic-one' where id = '00000000-0000-4000-8000-0000000000b1'$q$, 'T-P11 valid: a publisher can set their own display name, bio and handle');
select is((select handle from public.publishers where id = '00000000-0000-4000-8000-0000000000b1'), 'synthetic-one', 'the handle was stored');
select throws_ok($q$update public.publishers set handle = 'another-handle' where id = '00000000-0000-4000-8000-0000000000b1'$q$, '55000'::char(5), null::text, $d$a handle is set once and then fixed$d$);
with u as (update public.publishers set bio = 'hijack' where id = '00000000-0000-4000-8000-0000000000b2' returning 1) select is((select count(*) from u), 0::bigint, 'T-P11 denied: a publisher cannot change another publisher''s profile (zero rows affected)');
select t.as_owner();
select is((select bio from public.publishers where id = '00000000-0000-4000-8000-0000000000b2'), null, 'the other publisher''s profile is unchanged');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$update public.publishers set status = 'active' where id = '00000000-0000-4000-8000-0000000000b1'$q$, '42501'::char(5), null::text, $d$T-P11 denied: a publisher cannot write their own status$d$);
select throws_ok($q$update public.publishers set status_reason = 'x' where id = '00000000-0000-4000-8000-0000000000b1'$q$, '42501'::char(5), null::text, $d$denied: a publisher cannot write status_reason$d$);
select throws_ok($q$update public.publishers set id = gen_random_uuid() where id = '00000000-0000-4000-8000-0000000000b1'$q$, '42501'::char(5), null::text, $d$denied: a publisher cannot change their id$d$);
select throws_ok($q$insert into public.publishers (id) values ('00000000-0000-4000-8000-0000000000c1')$q$, '42501'::char(5), null::text, $d$denied: a publisher row cannot be inserted through the API$d$);
select throws_ok($q$delete from public.publishers where id = '00000000-0000-4000-8000-0000000000b1'$q$, '42501'::char(5), null::text, $d$denied: a publisher cannot delete their row$d$);
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select throws_ok($q$update public.publishers set handle = 'Bad Handle!' where id = '00000000-0000-4000-8000-0000000000b2'$q$, '23514'::char(5), null::text, $d$a malformed handle is refused$d$);
select throws_ok($q$update public.publishers set handle = 'admin' where id = '00000000-0000-4000-8000-0000000000b2'$q$, '23514'::char(5), null::text, $d$a reserved handle is refused$d$);
select throws_ok($q$update public.publishers set handle = 'synthetic-one' where id = '00000000-0000-4000-8000-0000000000b2'$q$, '23505'::char(5), null::text, $d$a duplicate handle is refused$d$);
select lives_ok($q$update public.publishers set handle = 'synthetic-two' where id = '00000000-0000-4000-8000-0000000000b2'$q$, 'valid: a unique, well-formed handle is accepted');

-- ============ suspended and revoked publishers cannot act
select t.as_user('00000000-0000-4000-8000-0000000000b3', 'aal1');
select is((select private.is_active_publisher()), false, 'T-S02 denied: a suspended publisher is not an active publisher');
select is((select private.current_publisher_id()), null, 'denied: a suspended publisher has no current publisher id');
with u as (update public.publishers set bio = 'still here' where id = '00000000-0000-4000-8000-0000000000b3' returning 1) select is((select count(*) from u), 0::bigint, 'T-S02 denied: a suspended publisher cannot edit their own profile');
select is((select count(*) from public.publishers where id = '00000000-0000-4000-8000-0000000000b3'), 0::bigint, 'T-S02 denied: a suspended publisher can no longer read their own row');
select throws_ok($q$update public.publishers set status = 'active' where id = '00000000-0000-4000-8000-0000000000b3'$q$, '42501'::char(5), null::text, $d$T-S02 denied: a suspended publisher cannot self-reactivate$d$);
select t.as_user('00000000-0000-4000-8000-0000000000b4', 'aal1');
select is((select private.is_active_publisher()), false, 'T-S03 denied: a revoked publisher is not an active publisher');
with u as (update public.publishers set bio = 'still here' where id = '00000000-0000-4000-8000-0000000000b4' returning 1) select is((select count(*) from u), 0::bigint, 'T-S03 denied: a revoked publisher cannot edit their own profile');
select is((select count(*) from public.publishers where id = '00000000-0000-4000-8000-0000000000b4'), 0::bigint, 'T-S03 denied: a revoked publisher can no longer read their own row');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select is((select count(*) from public.publishers where id in ('00000000-0000-4000-8000-0000000000b3','00000000-0000-4000-8000-0000000000b4')), 2::bigint, 'valid: an administrator at aal2 can still inspect suspended and revoked publisher rows');

-- ============ set_publisher_status
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2');
select throws_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b2', 'suspended', 'no authority')$q$, '42501'::char(5), null::text, $d$denied: a publisher cannot change publisher status$d$);
select throws_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b1', 'active', 'self')$q$, '42501'::char(5), null::text, $d$denied: a publisher cannot touch their own status$d$);
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal1');
select throws_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b2', 'suspended', 'aal1')$q$, '42501'::char(5), null::text, $d$denied: an administrator at aal1 cannot change publisher status$d$);
select t.as_anon();
select throws_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b2', 'suspended', 'anon')$q$, '42501'::char(5), null::text, $d$denied: anon cannot change publisher status$d$);
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select throws_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b2', 'bogus', 'x')$q$, '22023'::char(5), null::text, $d$an invalid status is refused$d$);
select throws_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b2', 'suspended', '')$q$, '22023'::char(5), null::text, $d$a reason is required$d$);
select throws_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b2', 'active', 'already active')$q$, '55000'::char(5), null::text, $d$an unchanged status is refused$d$);
select throws_ok($q$select public.set_publisher_status(gen_random_uuid(), 'suspended', 'nobody')$q$, '55000'::char(5), null::text, $d$an unknown publisher is refused$d$);
-- the SAME claims (a "stale session") lose access the moment the status changes
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select is((select private.is_active_publisher()), true, 'before suspension: the publisher is active');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select lives_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b2', 'suspended', 'synthetic reason')$q$, 'T-D04 valid: an administrator at aal2 can suspend a publisher');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select is((select private.is_active_publisher()), false, 'T-S02 denied: with the very same claims the publisher is inactive immediately after suspension');
with u as (update public.publishers set bio = 'after suspension' where id = '00000000-0000-4000-8000-0000000000b2' returning 1) select is((select count(*) from u), 0::bigint, 'T-S02 denied: the stale-session publisher can no longer edit');
select is((select count(*) from public.publishers where id = '00000000-0000-4000-8000-0000000000b2'), 0::bigint, 'T-S02 denied: with the same claims the suspended publisher can no longer read their row');
select throws_ok($q$update public.publishers set status = 'active' where id = '00000000-0000-4000-8000-0000000000b2'$q$, '42501'::char(5), null::text, $d$T-S02 denied: the suspended publisher cannot self-reactivate$d$);
select t.as_owner();
select is((select status_reason from public.publishers where id = '00000000-0000-4000-8000-0000000000b2'), 'synthetic reason', 'the reason is recorded');
select is((select status_changed_by from public.publishers where id = '00000000-0000-4000-8000-0000000000b2'), '00000000-0000-4000-8000-0000000000a1'::uuid, 'the acting administrator is recorded');
select is((select details from public.audit_events where action = 'publisher.suspended' and subject_id = '00000000-0000-4000-8000-0000000000b2'::uuid), '{"from":"active","to":"suspended"}'::jsonb, 'the audit event records from/to and nothing else');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select lives_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b2', 'active', 'synthetic reinstatement')$q$, 'valid: an administrator can reinstate a publisher');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select is((select private.is_active_publisher()), true, 'valid: a reinstated publisher is active again');
select lives_ok($q$update public.publishers set bio = 'after reinstatement' where id = '00000000-0000-4000-8000-0000000000b2'$q$, 'valid: a reinstated publisher can edit again');
select is((select count(*) from public.publishers where id = '00000000-0000-4000-8000-0000000000b2'), 1::bigint, 'valid: a reinstated publisher can read their own row again');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select lives_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b2', 'revoked', 'synthetic revocation')$q$, 'T-D04 valid: an administrator can revoke a publisher');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select is((select private.is_active_publisher()), false, 'T-S03 denied: a revoked publisher is inactive');
select is((select count(*) from public.publishers where id = '00000000-0000-4000-8000-0000000000b2'), 0::bigint, 'T-S03 denied: with the same claims the revoked publisher can no longer read their row');
with u as (update public.publishers set bio = 'after revocation' where id = '00000000-0000-4000-8000-0000000000b2' returning 1) select is((select count(*) from u), 0::bigint, 'T-S03 denied: the revoked publisher can no longer edit');
select throws_ok($q$update public.publishers set status = 'active' where id = '00000000-0000-4000-8000-0000000000b2'$q$, '42501'::char(5), null::text, $d$T-S03 denied: the revoked publisher cannot self-reactivate$d$);
select t.as_owner();
select is((select count(*) from public.audit_events where action in ('publisher.suspended','publisher.reinstated','publisher.revoked') and subject_id = '00000000-0000-4000-8000-0000000000b2'::uuid), 3::bigint, 'each status change wrote exactly one audit event');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2', '{"app_metadata":{"role":"admin"},"user_metadata":{"role":"admin"}}'::jsonb);
select throws_ok($q$select public.set_publisher_status('00000000-0000-4000-8000-0000000000b2', 'active', 'forged')$q$, '42501'::char(5), null::text, $d$T-S04 denied: forged role metadata in the token does not allow status changes$d$);

select * from finish();
rollback;
