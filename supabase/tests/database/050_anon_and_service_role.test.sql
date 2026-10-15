-- pgTAP test file. Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(46);
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


-- ============ anon and the secret key (service_role) hold no privileges on identity data (T-A05, T-X07 family).
-- The positive counterparts (what the right principals CAN do) are in 010..040; in 3.1 anon and service_role
-- have no legitimate operation on these objects by design.
select ok(not has_schema_privilege('anon', 'private', 'USAGE'), 'anon cannot resolve names in the private schema');
select ok(not has_schema_privilege('service_role', 'private', 'USAGE'), 'service_role cannot resolve names in the private schema');
select ok(has_schema_privilege('authenticated', 'private', 'USAGE'), 'valid: authenticated can resolve helper functions used by policies');
select t.as_anon();
select throws_ok(format('select * from public.%I', x), '42501'::char(5), null::text, 'T-A05 anon cannot select from ' || x) from unnest(array['admins','audit_events','invites','publishers']) x;
select throws_ok(format('insert into public.%I default values', x), '42501'::char(5), null::text, 'T-A05 anon cannot insert into ' || x) from unnest(array['admins','audit_events','invites','publishers']) x;
select throws_ok(format('update public.%I set status = status', x), '42501'::char(5), null::text, 'T-A05 anon cannot update ' || x) from unnest(array['admins','invites','publishers']) x;
select throws_ok(format('delete from public.%I', x), '42501'::char(5), null::text, 'T-A05 anon cannot delete from ' || x) from unnest(array['admins','audit_events','invites','publishers']) x;
select throws_ok('select ' || f, '42501'::char(5), null::text, 'T-A09 anon cannot execute ' || f)
  from unnest(array['public.create_invite(''x@example.test'')', 'public.revoke_invite(gen_random_uuid())', 'public.redeem_invite()',
                    'public.set_publisher_status(gen_random_uuid(),''active'',''x'')', 'private.is_admin()',
                    'private.is_active_publisher()', 'private.current_publisher_id()']) f;
select t.as_service();
select throws_ok(format('select * from public.%I', x), '42501'::char(5), null::text, 'T-X07 the secret key cannot select from ' || x) from unnest(array['admins','audit_events','invites','publishers']) x;
select throws_ok(format('insert into public.%I default values', x), '42501'::char(5), null::text, 'T-X07 the secret key cannot insert into ' || x) from unnest(array['admins','audit_events','invites','publishers']) x;
select throws_ok(format('update public.%I set status = status', x), '42501'::char(5), null::text, 'T-X07 the secret key cannot update ' || x) from unnest(array['admins','invites','publishers']) x;
select throws_ok(format('delete from public.%I', x), '42501'::char(5), null::text, 'T-X07 the secret key cannot delete from ' || x) from unnest(array['admins','audit_events','invites','publishers']) x;
select throws_ok('select ' || f, '42501'::char(5), null::text, 'T-X07 the secret key cannot execute ' || f)
  from unnest(array['public.create_invite(''x@example.test'')', 'public.revoke_invite(gen_random_uuid())', 'public.redeem_invite()',
                    'public.set_publisher_status(gen_random_uuid(),''active'',''x'')', 'private.bootstrap_admin(gen_random_uuid())',
                    'private.remove_admin(gen_random_uuid())']) f;

select * from finish();
rollback;
