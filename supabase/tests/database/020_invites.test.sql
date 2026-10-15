-- pgTAP test file. Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(54);
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


insert into auth.users (id, email, email_confirmed_at, aud, role) values
  ('00000000-0000-4000-8000-0000000000d1', 'Invitee1@Example.TEST', now(),  'authenticated', 'authenticated'), -- mixed case on purpose
  ('00000000-0000-4000-8000-0000000000d2', 'invitee2@example.test', null,   'authenticated', 'authenticated'), -- email NOT verified
  ('00000000-0000-4000-8000-0000000000d3', 'invitee3@example.test', now(),  'authenticated', 'authenticated'), -- only an invitation for another address exists
  ('00000000-0000-4000-8000-0000000000d4', 'invitee4@example.test', now(),  'authenticated', 'authenticated'), -- invitation expired
  ('00000000-0000-4000-8000-0000000000d5', 'invitee5@example.test', now(),  'authenticated', 'authenticated'); -- invitation revoked

-- ============ create_invite: denials, then the valid operation
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2');
select throws_ok($q$select public.create_invite('invitee1@example.test')$q$, '42501'::char(5), null::text, $d$T-I01 denied: an ordinary publisher cannot create invitations (even at aal2)$d$);
select t.as_user('00000000-0000-4000-8000-0000000000c1', 'aal2');
select throws_ok($q$select public.create_invite('invitee1@example.test')$q$, '42501'::char(5), null::text, $d$T-I01 denied: a user with no capability cannot create invitations$d$);
select t.as_anon();
select throws_ok($q$select public.create_invite('invitee1@example.test')$q$, '42501'::char(5), null::text, $d$T-I01 denied: anon cannot create invitations$d$);
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal1');
select throws_ok($q$select public.create_invite('invitee1@example.test')$q$, '42501'::char(5), null::text, $d$T-I02 denied: an administrator at aal1 cannot create invitations$d$);
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select lives_ok($q$select public.create_invite('  Invitee1@Example.TEST  ')$q$, 'T-I03 valid: an administrator at aal2 can create an invitation (email normalised)');
select is((select email from public.invites where email like 'invitee1@%'), 'invitee1@example.test', 'the stored email is trimmed and lower-cased');
select is((select count(*) from public.audit_events where action = 'invite.created'), 1::bigint, 'creating an invitation writes exactly one audit event');
select is((select count(*) from public.audit_events where action = 'invite.created' and details ? 'email'), 0::bigint, 'the audit event carries no email address');
select ok((select expires_at between now() + interval '6 days 23 hours' and now() + interval '7 days 1 hour' from public.invites where email = 'invitee1@example.test'), 'default lifetime is 7 days');
select throws_ok($q$select public.create_invite('invitee1@example.test')$q$, '23505'::char(5), null::text, $d$T-I06 denied: a second pending invitation for the same email is refused$d$);
select throws_ok($q$select public.create_invite('x@example.test', 0)$q$, '22023'::char(5), null::text, $d$a lifetime below 1 day is refused$d$);
select throws_ok($q$select public.create_invite('x@example.test', 31)$q$, '22023'::char(5), null::text, $d$a lifetime above 30 days is refused$d$);
select throws_ok($q$select public.create_invite('not-an-email')$q$, '22023'::char(5), null::text, $d$an invalid email is refused$d$);
select throws_ok($q$select public.create_invite('pub1@example.test')$q$, '23505'::char(5), null::text, $d$an email that already belongs to a publisher is refused$d$);

-- invitations for the remaining scenarios (the owner inserts them to control timestamps)
select t.as_owner();
insert into public.invites (email, created_by, created_at, expires_at, status) values
  ('invitee2@example.test',   '00000000-0000-4000-8000-0000000000a1', now(),                     now() + interval '7 days', 'pending'),
  ('someone-else@example.test', '00000000-0000-4000-8000-0000000000a1', now(),                   now() + interval '7 days', 'pending'),
  ('invitee4@example.test',   '00000000-0000-4000-8000-0000000000a1', now() - interval '3 days', now() - interval '1 day',  'pending'),
  ('lapsed@example.test',     '00000000-0000-4000-8000-0000000000a1', now() - interval '3 days', now() - interval '1 day',  'pending'),
  ('suspended@example.test',  '00000000-0000-4000-8000-0000000000a1', now(),                     now() + interval '7 days', 'pending'),
  ('revoke-me@example.test',  '00000000-0000-4000-8000-0000000000a1', now(),                     now() + interval '7 days', 'pending');
insert into public.invites (email, created_by, created_at, expires_at, status, revoked_by, revoked_at) values
  ('invitee5@example.test',   '00000000-0000-4000-8000-0000000000a1', now() - interval '1 day',  now() + interval '6 days', 'revoked', '00000000-0000-4000-8000-0000000000a1', now());

select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select lives_ok($q$select public.create_invite('lapsed@example.test')$q$, 'valid: a lapsed pending invitation does not block a fresh one');
select is((select count(*) from public.invites where email = 'lapsed@example.test' and status = 'expired'), 1::bigint, 'the lapsed invitation is marked expired');
select is((select count(*) from public.invites where email = 'lapsed@example.test' and status = 'pending'), 1::bigint, 'exactly one pending invitation remains for that email');

-- ============ reading and direct writes
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2');
select is((select count(*) from public.invites), 0::bigint, 'T-I01 denied: a publisher cannot read invitations');
select throws_ok($q$insert into public.invites (email, created_by, expires_at) values ('z@example.test', '00000000-0000-4000-8000-0000000000b1', now() + interval '1 day')$q$, '42501'::char(5), null::text, $d$T-I01 denied: no direct INSERT on invites$d$);
select throws_ok($q$update public.invites set status = 'pending'$q$, '42501'::char(5), null::text, $d$T-I01 denied: no direct UPDATE on invites$d$);
select throws_ok($q$delete from public.invites$q$, '42501'::char(5), null::text, $d$T-I01 denied: no direct DELETE on invites$d$);
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal1');
select is((select count(*) from public.invites), 0::bigint, 'T-I02 denied: an administrator at aal1 cannot read invitations');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select ok((select count(*) from public.invites) >= 8, 'valid: an administrator at aal2 can read invitations');
select t.as_anon();
select throws_ok($q$select * from public.invites$q$, '42501'::char(5), null::text, $d$T-A05 denied: anon cannot read invitations$d$);

-- ============ revoke_invite
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal2');
select throws_ok($q$select public.revoke_invite(gen_random_uuid())$q$, '42501'::char(5), null::text, $d$denied: a publisher cannot revoke invitations$d$);
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal1');
select throws_ok($q$select public.revoke_invite(gen_random_uuid())$q$, '42501'::char(5), null::text, $d$denied: an administrator at aal1 cannot revoke invitations$d$);
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select lives_ok($q$select public.revoke_invite((select id from public.invites where email = 'revoke-me@example.test'))$q$, 'valid: an administrator at aal2 can revoke a pending invitation');
select is((select count(*) from public.audit_events where action = 'invite.revoked'), 1::bigint, 'revoking writes one audit event');
select throws_ok($q$select public.revoke_invite((select id from public.invites where email = 'revoke-me@example.test'))$q$, '55000'::char(5), null::text, $d$an already-revoked invitation cannot be revoked again$d$);
select throws_ok($q$select public.revoke_invite(gen_random_uuid())$q$, '55000'::char(5), null::text, $d$an unknown invitation cannot be revoked$d$);

-- ============ redeem_invite: every refusal leaves NO partial record
select t.as_owner();
create temp table before_counts as select
  (select count(*) from public.publishers) as pubs,
  (select count(*) from public.audit_events where action = 'invite.redeemed') as redeemed_events,
  (select count(*) from public.invites where status = 'pending') as pending;
select t.as_anon();
select throws_ok($q$select public.redeem_invite()$q$, '42501'::char(5), null::text, $d$denied: anon cannot redeem$d$);
select t.as_user('00000000-0000-4000-8000-0000000000c1', 'aal1');
select throws_ok($q$select public.redeem_invite()$q$, '55000'::char(5), null::text, $d$denied: a verified user with no invitation cannot redeem$d$);
select t.as_user('00000000-0000-4000-8000-0000000000d2', 'aal1');
select throws_ok($q$select public.redeem_invite()$q$, '55000'::char(5), null::text, $d$denied: a user whose email is NOT verified cannot redeem even though a pending invitation matches$d$);
select t.as_user('00000000-0000-4000-8000-0000000000d3', 'aal1');
select throws_ok($q$select public.redeem_invite()$q$, '55000'::char(5), null::text, $d$denied: a verified user cannot redeem an invitation issued to a different email$d$);
select t.as_user('00000000-0000-4000-8000-0000000000d4', 'aal1');
select throws_ok($q$select public.redeem_invite()$q$, '55000'::char(5), null::text, $d$denied: an expired invitation cannot be redeemed$d$);
select t.as_user('00000000-0000-4000-8000-0000000000d5', 'aal1');
select throws_ok($q$select public.redeem_invite()$q$, '55000'::char(5), null::text, $d$denied: a revoked invitation cannot be redeemed$d$);
select t.as_user('00000000-0000-4000-8000-0000000000b3', 'aal1');
select throws_ok($q$select public.redeem_invite()$q$, '55000'::char(5), null::text, $d$T-I09 denied: a suspended publisher cannot use an invitation to reactivate$d$);
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.redeem_invite()$q$, '55000'::char(5), null::text, $d$denied: an existing publisher cannot redeem again$d$);
select throws_ok($q$select public.redeem_invite('admin')$q$, '42883'::char(5), null::text, $d$T-I08 denied: redeem_invite accepts no role or email argument$d$);
select t.as_owner();
select is((select count(*) from public.publishers), (select pubs from before_counts), 'no publisher row was created by any refused redemption');
select is((select count(*) from public.audit_events where action = 'invite.redeemed'), (select redeemed_events from before_counts), 'no audit event was written by any refused redemption');
select is((select count(*) from public.invites where status = 'pending'), (select pending from before_counts), 'no invitation changed state during refused redemptions');
select is((select status from public.publishers where id = '00000000-0000-4000-8000-0000000000b3'), 'suspended', 'the suspended publisher was not reactivated');
select is((select status from public.invites where email = 'invitee4@example.test'), 'pending', 'the expired invitation was left untouched');

-- ============ redeem_invite: the valid path
select t.as_user('00000000-0000-4000-8000-0000000000d1', 'aal1');
select lives_ok($q$select public.redeem_invite()$q$, 'T-I04 valid: a verified user with a matching pending unexpired invitation can redeem (mixed-case email matches)');
select is((select status from public.publishers where id = '00000000-0000-4000-8000-0000000000d1'), 'active', 'the new publisher is active');
select is((select handle from public.publishers where id = '00000000-0000-4000-8000-0000000000d1'), null, 'no handle is assigned at redemption (chosen later, once)');
select t.as_owner();
select is((select status from public.invites where email = 'invitee1@example.test'), 'redeemed', 'the invitation is marked redeemed');
select is((select redeemed_by from public.invites where email = 'invitee1@example.test'), '00000000-0000-4000-8000-0000000000d1'::uuid, 'the invitation records who redeemed it');
select is((select count(*) from public.audit_events where action = 'invite.redeemed' and actor_id = '00000000-0000-4000-8000-0000000000d1'::uuid and actor_kind = 'publisher'), 1::bigint, 'redemption writes exactly one audit event attributed to the new publisher');
select t.as_user('00000000-0000-4000-8000-0000000000d1', 'aal1');
select throws_ok($q$select public.redeem_invite()$q$, '55000'::char(5), null::text, $d$denied: an already-redeemed invitation cannot be redeemed again$d$);
select is((select private.is_active_publisher()), true, 'valid: the new publisher is an active publisher');
select is((select private.is_admin()), false, 'denied: redemption grants publisher access only, never administrator access');
select t.as_owner();
select is((select count(*) from public.publishers where id = '00000000-0000-4000-8000-0000000000d1'), 1::bigint, 'exactly one publisher row exists after the repeat attempt');

select * from finish();
rollback;
