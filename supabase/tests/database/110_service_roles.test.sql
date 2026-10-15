-- pgTAP test file (Stage 3.2). Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(73);
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

-- setup: publisher A has an experience with one revision
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'expA', public.create_experience('alpha-one', 'explainer', t.doc('alpha-one'));
insert into t.ids select 'revA1', head_revision_id from public.experiences where id = t.id('expA');
select t.as_owner();
-- T-X03/T-X04/T-X06: ai_service holds no table privilege at all in Stage 3
select t.as_ai();
select throws_ok($q$select * from public.admins$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from admins');
select throws_ok($q$select * from public.publishers$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from publishers');
select throws_ok($q$select * from public.invites$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from invites');
select throws_ok($q$select * from public.audit_events$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from audit_events');
select throws_ok($q$select * from public.topics$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from topics');
select throws_ok($q$select * from public.experiences$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from experiences');
select throws_ok($q$select * from public.experience_topics$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from experience_topics');
select throws_ok($q$select * from public.revisions$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from revisions');
select throws_ok($q$select * from public.revision_validations$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from revision_validations');
select throws_ok($q$select * from public.approvals$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from approvals');
select throws_ok($q$select * from public.publications$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from publications');
select throws_ok($q$select * from public.published_experiences$q$, '42501'::char(5), null::text, 'T-X06 denied: ai_service cannot select from published_experiences');
select throws_ok($q$insert into public.experiences (publisher_id, slug, kind, language, title) values (gen_random_uuid(), 'zzz-ai', 'explainer', 'en', 'x')$q$, '42501'::char(5), null::text, 'T-X03 denied: ai_service cannot insert into experiences');
select throws_ok($q$insert into public.revisions (experience_id, seq, created_by, schema_version, document) values (gen_random_uuid(), 1, gen_random_uuid(), 1, '{}')$q$, '42501'::char(5), null::text, 'T-X04 denied: ai_service cannot insert into revisions');
select throws_ok($q$insert into public.approvals (revision_id, experience_id, approved_by, content_hash) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'x')$q$, '42501'::char(5), null::text, 'T-X01 denied: ai_service has no INSERT on approvals');
select throws_ok($q$insert into public.publications (experience_id, revision_id, slug_at_publish, published_by) values (gen_random_uuid(), gen_random_uuid(), 'x', gen_random_uuid())$q$, '42501'::char(5), null::text, 'T-X02 denied: ai_service has no INSERT on publications');
select throws_ok($q$insert into public.published_experiences (experience_id, publication_id, slug, kind, title, summary, language, schema_version, document, publisher_id) values (gen_random_uuid(), gen_random_uuid(), 'x', 'explainer', 'x', 'x', 'en', 1, '{}', gen_random_uuid())$q$, '42501'::char(5), null::text, 'T-X02 denied: ai_service has no INSERT on the public projection');
select throws_ok($q$select public.approve_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X01 approve_revision');
select throws_ok($q$select public.publish_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X02 publish_revision');
select throws_ok($q$select public.unpublish_experience(t.id('expA'))$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X02 unpublish_experience');
select throws_ok($q$select public.create_experience('zzz-ai', 'explainer', t.doc('zzz-ai'))$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X03 create_experience');
select throws_ok($q$select public.save_revision(t.id('expA'), t.id('revA1'), t.doc('alpha-one'))$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X04 save_revision');
select throws_ok($q$select public.admin_takedown(t.id('expA'), 'policy', 'x')$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X05 admin_takedown');
select throws_ok($q$select public.set_experience_hold(t.id('expA'), true, 'x')$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X05 set_experience_hold');
select throws_ok($q$select public.create_invite('x@example.test')$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X05 create_invite');
select throws_ok($q$select public.redeem_invite()$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X05 redeem_invite');
select throws_ok($q$select public.set_publisher_status(gen_random_uuid(), 'suspended', 'x')$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X05 set_publisher_status');
select throws_ok($q$select public.record_validation(t.id('revA1'), true, 'v1')$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X05 record_validation (the validator function)');
select throws_ok($q$select public.get_revision_for_validation(t.id('revA1'))$q$, '42501'::char(5), null::text, 'denied: ai_service cannot execute T-X05 get_revision_for_validation');
-- validator_service: exactly two functions and no table privilege
select t.as_validator();
select throws_ok($q$select * from public.admins$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from admins');
select throws_ok($q$select * from public.publishers$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from publishers');
select throws_ok($q$select * from public.invites$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from invites');
select throws_ok($q$select * from public.audit_events$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from audit_events');
select throws_ok($q$select * from public.topics$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from topics');
select throws_ok($q$select * from public.experiences$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from experiences');
select throws_ok($q$select * from public.experience_topics$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from experience_topics');
select throws_ok($q$select * from public.revisions$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from revisions');
select throws_ok($q$select * from public.revision_validations$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from revision_validations');
select throws_ok($q$select * from public.approvals$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from approvals');
select throws_ok($q$select * from public.publications$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from publications');
select throws_ok($q$select * from public.published_experiences$q$, '42501'::char(5), null::text, 'denied: validator_service cannot select from published_experiences');
select throws_ok($q$insert into public.revision_validations (revision_id, content_hash, validator_version, passed) values (gen_random_uuid(), 'x', 'v1', true)$q$, '42501'::char(5), null::text, 'denied: validator_service cannot write attestations directly (only through record_validation)');
select throws_ok($q$select public.approve_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'T-X05 denied: validator_service cannot execute T-X01 approve_revision');
select throws_ok($q$select public.publish_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'T-X05 denied: validator_service cannot execute T-X02 publish_revision');
select throws_ok($q$select public.unpublish_experience(t.id('expA'))$q$, '42501'::char(5), null::text, 'T-X05 denied: validator_service cannot execute T-X02 unpublish_experience');
select throws_ok($q$select public.create_experience('zzz-ai', 'explainer', t.doc('zzz-ai'))$q$, '42501'::char(5), null::text, 'T-X05 denied: validator_service cannot execute T-X03 create_experience');
select throws_ok($q$select public.save_revision(t.id('expA'), t.id('revA1'), t.doc('alpha-one'))$q$, '42501'::char(5), null::text, 'T-X05 denied: validator_service cannot execute T-X04 save_revision');
select throws_ok($q$select public.admin_takedown(t.id('expA'), 'policy', 'x')$q$, '42501'::char(5), null::text, 'T-X05 denied: validator_service cannot execute T-X05 admin_takedown');
select throws_ok($q$select public.set_experience_hold(t.id('expA'), true, 'x')$q$, '42501'::char(5), null::text, 'T-X05 denied: validator_service cannot execute T-X05 set_experience_hold');
select throws_ok($q$select public.create_invite('x@example.test')$q$, '42501'::char(5), null::text, 'T-X05 denied: validator_service cannot execute T-X05 create_invite');
select throws_ok($q$select public.redeem_invite()$q$, '42501'::char(5), null::text, 'T-X05 denied: validator_service cannot execute T-X05 redeem_invite');
select throws_ok($q$select public.set_publisher_status(gen_random_uuid(), 'suspended', 'x')$q$, '42501'::char(5), null::text, 'T-X05 denied: validator_service cannot execute T-X05 set_publisher_status');
select is((select count(*) from public.get_revision_for_validation(t.id('revA1'))), 1::bigint, 'valid: validator_service can read a revision for validation through the narrow function');
select is((select content_hash from public.get_revision_for_validation(t.id('revA1'))), (select pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(document::text, 'UTF8')), 'hex') from (select document from public.get_revision_for_validation(t.id('revA1'))) d), 'the hash the validator sees is the sha-256 of the stored document');
select lives_ok($q$select public.record_validation(t.id('revA1'), true, 'zod-1')$q$, 'valid: validator_service can record an attestation');
select t.as_owner();
select is((select count(*) from public.revision_validations where revision_id = t.id('revA1')), 1::bigint, 'exactly one attestation was recorded');
-- defense in depth: even if EXECUTE were wrongly granted, the function re-checks its caller
grant execute on function public.record_validation(uuid, boolean, text, jsonb) to authenticated, anon, service_role, ai_service;
grant execute on function public.approve_revision(uuid), public.publish_revision(uuid) to ai_service, validator_service, service_role, anon;
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.record_validation(t.id('revA1'), true, 'zod-forged')$q$, '42501'::char(5), null::text, 'a publisher with a (wrongly) granted EXECUTE still cannot self-attest: the function re-checks that the caller is validator_service');
select t.as_anon();
select throws_ok($q$select public.record_validation(t.id('revA1'), true, 'zod-forged')$q$, '42501'::char(5), null::text, 'anon with a (wrongly) granted EXECUTE still cannot attest');
select t.as_service();
select throws_ok($q$select public.record_validation(t.id('revA1'), true, 'zod-forged')$q$, '42501'::char(5), null::text, 'service_role (the secret key) with a (wrongly) granted EXECUTE still cannot attest');
select t.as_ai();
select throws_ok($q$select public.record_validation(t.id('revA1'), true, 'zod-forged')$q$, '42501'::char(5), null::text, 'ai_service with a (wrongly) granted EXECUTE still cannot attest');
do $d$ begin perform set_config('request.jwt.claims', jsonb_build_object('sub', '00000000-0000-4000-8000-0000000000b1', 'role', 'authenticated', 'aal', 'aal1')::text, true); end $d$;
select throws_ok($q$select public.approve_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'ai_service forging a publisher''s claims, with a (wrongly) granted EXECUTE, still cannot approve: it is not a human session');
select throws_ok($q$select public.publish_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'ai_service forging claims still cannot publish');
select t.as_validator();
do $d$ begin perform set_config('request.jwt.claims', jsonb_build_object('sub', '00000000-0000-4000-8000-0000000000b1', 'role', 'authenticated', 'aal', 'aal1')::text, true); end $d$;
select throws_ok($q$select public.approve_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'validator_service forging claims still cannot approve: it is not a human session');
select t.as_service();
do $d$ begin perform set_config('request.jwt.claims', jsonb_build_object('sub', '00000000-0000-4000-8000-0000000000b1', 'role', 'authenticated', 'aal', 'aal1')::text, true); end $d$;
select throws_ok($q$select public.approve_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'service_role forging claims still cannot approve: it is not a human session');
select t.as_owner();
revoke execute on function public.record_validation(uuid, boolean, text, jsonb) from authenticated, anon, service_role, ai_service;
revoke execute on function public.approve_revision(uuid), public.publish_revision(uuid) from ai_service, validator_service, service_role, anon;
select is_empty($$select 1 from information_schema.routine_privileges where routine_schema='public' and grantee in ('anon','ai_service','service_role') $$, 'the temporary grants were removed again: anon, ai_service and service_role hold no EXECUTE');
-- T-X07: even the secret key (service_role, BYPASSRLS) cannot forge lifecycle records
select t.as_service();
select throws_ok($q$insert into public.approvals (revision_id, experience_id, approved_by, content_hash) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'x')$q$, '42501'::char(5), null::text, 'T-X07 denied: service_role cannot insert into approvals');
select throws_ok($q$insert into public.publications (experience_id, revision_id, slug_at_publish, published_by) values (gen_random_uuid(), gen_random_uuid(), 'x', gen_random_uuid())$q$, '42501'::char(5), null::text, 'T-X07 denied: service_role cannot insert into publications');
select throws_ok($q$insert into public.published_experiences (experience_id, publication_id, slug, kind, title, summary, language, schema_version, document, publisher_id) values (gen_random_uuid(), gen_random_uuid(), 'x', 'explainer', 'x', 'x', 'en', 1, '{}', gen_random_uuid())$q$, '42501'::char(5), null::text, 'T-X07 denied: service_role cannot insert into the public projection');
select throws_ok($q$update public.revisions set note = 'forged'$q$, '42501'::char(5), null::text, 'T-X07 denied: service_role cannot update revisions');
select throws_ok($q$delete from public.revisions$q$, '42501'::char(5), null::text, 'T-X07 denied: service_role cannot delete revisions');
select throws_ok($q$insert into public.revision_validations (revision_id, content_hash, validator_version, passed) values (gen_random_uuid(), 'x', 'v1', true)$q$, '42501'::char(5), null::text, 'T-X07 denied: service_role cannot write attestations');
select throws_ok($q$select public.approve_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'T-X07 denied: service_role has no EXECUTE on approve_revision');
select t.as_owner();
select is_empty($$select c.relname || ':' || p from pg_class c join pg_namespace n on n.oid = c.relnamespace
  cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
  where n.nspname = 'public' and c.relkind = 'r' and c.relname in ('approvals','publications','published_experiences','revisions','revision_validations')
  and has_table_privilege('service_role', c.oid, p)$$,
  'sentinel: service_role holds no privilege of any kind on approvals, publications, published_experiences, revisions or revision_validations (fails if a migration re-grants one)');

select * from finish();
rollback;
