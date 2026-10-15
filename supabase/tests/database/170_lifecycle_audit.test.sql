-- pgTAP test file (Stage 3.2). Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
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
-- the pgTAP functions live in `extensions`; the two service roles need to see them to be tested (test transaction only)
grant usage on schema extensions to validator_service, ai_service;

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

-- every lifecycle operation writes exactly one audit event, with the right actor, in its own transaction
create temp table t_mark (n bigint);
grant all on t_mark to public;
insert into t_mark select count(*) from public.audit_events;
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'expA', public.create_experience('alpha-one', 'explainer', t.doc('alpha-one'));
insert into t.ids select 'r1', head_revision_id from public.experiences where id = t.id('expA');
select t.as_owner();
select is((select count(*) from public.audit_events where action = 'experience.created' and subject_id = t.id('expA') and actor_kind = 'publisher' and actor_id = '00000000-0000-4000-8000-0000000000b1'), 1::bigint, 'create_experience wrote one experience.created event for the verified caller');
select is((select details from public.audit_events where action = 'experience.created' and subject_id = t.id('expA')), jsonb_build_object('experience_id', t.id('expA'), 'revision_id', t.id('r1'), 'seq', 1), 'its details are ids and a sequence number only');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'r2', public.save_revision(t.id('expA'), t.id('r1'), t.doc('alpha-one', 'Two', 'Text two.'));
select t.as_owner();
select is((select count(*) from public.audit_events where action = 'revision.saved' and subject_id = t.id('r2') and actor_id = '00000000-0000-4000-8000-0000000000b1'), 1::bigint, 'save_revision wrote one revision.saved event');
select t.as_validator();
select public.record_validation(t.id('r2'), true, 'zod-1');
select t.as_owner();
select is((select actor_kind || ':' || coalesce(actor_id::text, 'null') from public.audit_events where action = 'revision.validated' and subject_id = t.id('r2')), 'system:null', 'record_validation wrote one system event with no actor id');
select is((select details from public.audit_events where action = 'revision.validated' and subject_id = t.id('r2')), jsonb_build_object('experience_id', t.id('expA'), 'revision_id', t.id('r2'), 'validator_version', 'zod-1', 'passed', true), 'its details name the verdict and validator version, never content');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select public.approve_revision(t.id('r2'));
insert into t.ids select 'pub', public.publish_revision(t.id('r2'));
select public.unpublish_experience(t.id('expA'));
select t.as_owner();
select is((select count(*) from public.audit_events where action = 'revision.approved' and actor_id = '00000000-0000-4000-8000-0000000000b1'), 1::bigint, 'revision.approved was written once');
select is((select count(*) from public.audit_events where action = 'publication.published' and actor_id = '00000000-0000-4000-8000-0000000000b1'), 1::bigint, 'publication.published was written once');
select is((select count(*) from public.audit_events where action = 'publication.unpublished' and actor_id = '00000000-0000-4000-8000-0000000000b1'), 1::bigint, 'publication.unpublished was written once');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select public.set_experience_hold(t.id('expA'), true, 'synthetic hold');
select public.set_experience_hold(t.id('expA'), false);
select t.as_owner();
select is((select count(*) from public.audit_events where action in ('experience.held','experience.released') and actor_kind = 'admin' and actor_id = '00000000-0000-4000-8000-0000000000a1'), 2::bigint, 'hold and release each wrote an admin event');
select is((select count(*) from public.audit_events where aal = 'aal2' and actor_kind = 'admin' and action like 'experience.%'), 2::bigint, 'admin events record the assurance level of the session');
select is((select count(*) - (select n from t_mark) from public.audit_events), 8::bigint, 'the whole scenario wrote exactly eight events: created, saved, validated, approved, published, unpublished, held, released');
-- refused calls write no audit event
select t.as_owner();
update t_mark set n = (select count(*) from public.audit_events);
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select throws_ok($q$select public.save_revision(t.id('expA'), t.id('r2'), t.doc('alpha-one'))$q$, '42501'::char(5), null::text, 'a refused save (not the owner)');
select throws_ok($q$select public.approve_revision(t.id('r2'))$q$, '42501'::char(5), null::text, 'a refused approval (not the owner)');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.save_revision(t.id('expA'), t.id('r1'), t.doc('alpha-one'))$q$, '23505'::char(5), null::text, 'a refused save (edit conflict)');
select throws_ok($q$select public.publish_revision(t.id('r1'))$q$, '55000'::char(5), null::text, 'a refused publish (not approved)');
select t.as_owner();
select is((select count(*) - (select n from t_mark) from public.audit_events), 0::bigint, 'none of the refused calls wrote an audit event');
-- who may read the audit log
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select cmp_ok((select count(*) from public.audit_events), '>', 0::bigint, 'valid: an administrator at aal2 reads the audit log');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select is((select count(*) from public.audit_events), 0::bigint, 'denied: a publisher reads no audit events, not even their own');
select t.as_validator();
select throws_ok($q$select * from public.audit_events$q$, '42501'::char(5), null::text, 'denied: validator_service cannot read the audit log');
select t.as_owner();
select throws_ok($q$update public.audit_events set action = 'topic.created' where subject_id = t.id('expA')$q$, '55000'::char(5), null::text, 'the audit log stays append-only for the owner too');

select * from finish();
rollback;
