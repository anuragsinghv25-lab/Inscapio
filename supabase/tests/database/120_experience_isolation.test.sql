-- pgTAP test file (Stage 3.2). Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(76);
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

-- T-P01: creation, with ownership derived from the verified caller
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'expA', public.create_experience('alpha-one', 'explainer', t.doc('alpha-one'));
insert into t.ids select 'revA1', head_revision_id from public.experiences where id = t.id('expA');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
insert into t.ids select 'expB', public.create_experience('beta-one', 'data-story', t.doc('beta-one', 'Beta', 'Beta text.', 'data-story'));
insert into t.ids select 'revB1', head_revision_id from public.experiences where id = t.id('expB');
select t.as_owner();
select is((select publisher_id from public.experiences where id = t.id('expA')), '00000000-0000-4000-8000-0000000000b1'::uuid, 'T-P01 valid: the owner of A''s experience is A, derived from the verified session');
select is((select publisher_id from public.experiences where id = t.id('expB')), '00000000-0000-4000-8000-0000000000b2'::uuid, 'T-P01 valid: the owner of B''s experience is B');
select is((select count(*) from public.revisions where experience_id = t.id('expA') and seq = 1 and created_by = '00000000-0000-4000-8000-0000000000b1' and parent_id is null), 1::bigint, 'creation wrote revision 1, authored by the caller, with no parent');
select is((select head_revision_id from public.experiences where id = t.id('expA')), t.id('revA1'), 'the head pointer references the first revision');
select is((select title from public.experiences where id = t.id('expA')), 'Synthetic title', 'the title is derived from the document, never client-supplied');
select ok(not exists(select 1 from pg_proc p where p.proname = 'create_experience' and pg_catalog.pg_get_function_arguments(p.oid) ilike '%publisher%'), 'T-P01 create_experience has no publisher-id parameter, so a caller cannot name another owner');
-- creation denials (each has the positive twin above)
select t.as_user('00000000-0000-4000-8000-0000000000c1', 'aal1');
select throws_ok($q$select public.create_experience('gamma-one', 'explainer', t.doc('gamma-one'))$q$, '42501'::char(5), null::text, 'denied: a signed-in user with no publisher record cannot create an experience');
select t.as_user('00000000-0000-4000-8000-0000000000b3', 'aal1');
select throws_ok($q$select public.create_experience('gamma-one', 'explainer', t.doc('gamma-one'))$q$, '42501'::char(5), null::text, 'denied: a suspended publisher cannot create an experience');
select t.as_user('00000000-0000-4000-8000-0000000000b4', 'aal1');
select throws_ok($q$select public.create_experience('gamma-one', 'explainer', t.doc('gamma-one'))$q$, '42501'::char(5), null::text, 'denied: a revoked publisher cannot create an experience');
select t.as_anon();
select throws_ok($q$select public.create_experience('gamma-one', 'explainer', t.doc('gamma-one'))$q$, '42501'::char(5), null::text, 'denied: anon cannot create an experience');
select t.as_authenticated_nosub();
select throws_ok($q$select public.create_experience('gamma-one', 'explainer', t.doc('gamma-one'))$q$, '42501'::char(5), null::text, 'denied: an authenticated role with no subject cannot create an experience');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.create_experience('climate', 'explainer', t.doc('climate'))$q$, '22023'::char(5), null::text, 'denied: a reserved slug (an existing file-based experience) cannot be claimed');
select throws_ok($q$select public.create_experience('studio', 'explainer', t.doc('studio'))$q$, '22023'::char(5), null::text, 'denied: a reserved route word cannot be claimed');
select throws_ok($q$select public.create_experience('Bad Slug', 'explainer', t.doc('gamma-one'))$q$, '22023'::char(5), null::text, 'denied: a malformed slug is refused');
select throws_ok($q$select public.create_experience('gamma-one', 'poem', t.doc('gamma-one'))$q$, '22023'::char(5), null::text, 'denied: an unknown kind is refused');
select throws_ok($q$select public.create_experience('gamma-one', 'explainer', t.doc('other-slug'))$q$, '22023'::char(5), null::text, 'denied: the document slug must equal the experience slug');
select throws_ok($q$select public.create_experience('gamma-one', 'explainer', t.doc('gamma-one', p_kind => 'data-story'))$q$, '22023'::char(5), null::text, 'denied: the document kind must equal the experience kind');
select throws_ok($q$select public.create_experience('gamma-one', 'explainer', jsonb_set(t.doc('gamma-one'), '{sections,0,blocks,0,type}', '"script"'))$q$, '22023'::char(5), null::text, 'T-L13 denied: an unknown block type fails the shape gate');
select throws_ok($q$select public.create_experience('gamma-one', 'explainer', null)$q$, '22023'::char(5), null::text, 'denied: a missing document is refused');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select throws_ok($q$select public.create_experience('alpha-one', 'explainer', t.doc('alpha-one'))$q$, '23505'::char(5), null::text, 'T-L08 denied: B cannot take A''s slug');
-- T-P02/T-P04/T-P12: reading — own rows yes, the other publisher's never
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select is((select count(*) from public.experiences), 1::bigint, 'T-P12 valid: A reads exactly their own experience');
select is((select count(*) from public.experiences where id = t.id('expB')), 0::bigint, 'T-P02 denied: A cannot read B''s experience');
select is((select count(*) from public.revisions where experience_id = t.id('expA')), 1::bigint, 'T-P12 valid: A reads their own revision');
select is((select count(*) from public.revisions where experience_id = t.id('expB')), 0::bigint, 'T-P04 denied: A cannot read B''s revisions (private draft)');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select is((select count(*) from public.experiences), 1::bigint, 'T-P12 valid: B reads exactly their own experience');
select is((select count(*) from public.experiences where id = t.id('expA')), 0::bigint, 'T-P02 denied: B cannot read A''s experience');
select is((select count(*) from public.revisions where experience_id = t.id('expA')), 0::bigint, 'T-P04 denied: B cannot read A''s revisions');
-- T-P03/T-P13/T-P18: writes — column grants, no direct insert, no delete
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$update public.experiences set archived_at = now() where id = t.id('expA')$q$, 'valid: A can archive their own never-published draft');
select is((select count(*) from public.experiences where id = t.id('expA') and archived_at is not null), 1::bigint, 'the archive took effect');
select lives_ok($q$update public.experiences set archived_at = null where id = t.id('expA')$q$, 'valid: A can unarchive it');
with u as (update public.experiences set archived_at = now() where id = t.id('expB') returning 1) select is((select count(*) from u), 0::bigint, 'T-P03 denied: A cannot archive B''s experience (zero rows)');
select throws_ok($q$update public.experiences set publisher_id = '00000000-0000-4000-8000-0000000000b2' where id = t.id('expA')$q$, '42501'::char(5), null::text, 'T-P13 denied: A has no UPDATE privilege on experiences.publisher_id');
select throws_ok($q$update public.experiences set slug = 'stolen' where id = t.id('expA')$q$, '42501'::char(5), null::text, 'T-P13 denied: A has no UPDATE privilege on experiences.slug');
select throws_ok($q$update public.experiences set title = 'hijack' where id = t.id('expA')$q$, '42501'::char(5), null::text, 'T-P13 denied: A has no UPDATE privilege on experiences.title');
select throws_ok($q$update public.experiences set head_revision_id = gen_random_uuid() where id = t.id('expA')$q$, '42501'::char(5), null::text, 'T-P13 denied: A has no UPDATE privilege on experiences.head_revision_id');
select throws_ok($q$update public.experiences set held_at = now() where id = t.id('expA')$q$, '42501'::char(5), null::text, 'T-P13 denied: A has no UPDATE privilege on experiences.held_at');
select throws_ok($q$update public.experiences set slug_locked_at = now() where id = t.id('expA')$q$, '42501'::char(5), null::text, 'T-P13 denied: A has no UPDATE privilege on experiences.slug_locked_at');
select throws_ok($q$update public.experiences set kind = 'data-story' where id = t.id('expA')$q$, '42501'::char(5), null::text, 'T-P13 denied: A has no UPDATE privilege on experiences.kind');
select throws_ok($q$insert into public.experiences (publisher_id, slug, kind, language, title) values ('00000000-0000-4000-8000-0000000000b1', 'direct-one', 'explainer', 'en', 'x')$q$, '42501'::char(5), null::text, 'T-P13 denied: no direct INSERT into experiences, only create_experience');
select throws_ok($q$delete from public.experiences where id = t.id('expA')$q$, '42501'::char(5), null::text, 'T-P18 denied: no self-service deletion of experiences');
select throws_ok($q$insert into public.revisions (experience_id, seq, parent_id, created_by, schema_version, document) values (t.id('expA'), 2, t.id('revA1'), '00000000-0000-4000-8000-0000000000b1', 1, t.doc('alpha-one'))$q$, '42501'::char(5), null::text, 'T-P14 denied: no direct INSERT into revisions, only save_revision');
-- T-P05..T-P08: A cannot act on B's experience; B's full chain is built first so each denial has a live target
select t.as_validator();
select public.record_validation(t.id('revB1'), true, 'zod-1');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select public.approve_revision(t.id('revB1'));
insert into t.ids select 'pubB', public.publish_revision(t.id('revB1'));
select is((select count(*) from public.published_experiences where experience_id = t.id('expB')), 1::bigint, 'valid: B approved and published their own revision');
select lives_ok($q$select public.save_revision(t.id('expB'), t.id('revB1'), t.doc('beta-one', 'Beta two', 'Beta text two.', 'data-story'))$q$, 'T-P05 valid twin: B can save a revision to their own experience');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.save_revision(t.id('expB'), (select head_revision_id from public.experiences where id = t.id('expB')), t.doc('beta-one', 'x', 'x', 'data-story'))$q$, '42501'::char(5), null::text, 'T-P05 denied: A cannot save a revision to B''s experience');
select throws_ok($q$select public.approve_revision(t.id('revB1'))$q$, '42501'::char(5), null::text, 'T-P06 denied: A cannot approve B''s revision');
select throws_ok($q$select public.publish_revision(t.id('revB1'))$q$, '42501'::char(5), null::text, 'T-P07 denied: A cannot publish B''s revision');
select throws_ok($q$select public.unpublish_experience(t.id('expB'))$q$, '42501'::char(5), null::text, 'T-P08 denied: A cannot unpublish B''s publication');
select is((select count(*) from public.publications where experience_id = t.id('expB')), 0::bigint, 'A cannot read B''s publication history');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select is((select count(*) from public.publications where experience_id = t.id('expB')), 1::bigint, 'valid twin: B reads their own publication history');
select is((select count(*) from public.published_experiences where experience_id = t.id('expB')), 1::bigint, 'B''s publication is untouched by A''s attempts');
-- T-D03: an administrator has no content access; administration needs aal2
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select is((select count(*) from public.experiences), 0::bigint, 'T-D03 denied: an administrator at aal2 reads no experiences row');
select is((select count(*) from public.revisions), 0::bigint, 'T-D03 denied: an administrator at aal2 reads no revisions row');
select is((select count(*) from public.revision_validations), 0::bigint, 'T-D03 denied: an administrator at aal2 reads no revision_validations row');
select is((select count(*) from public.approvals), 0::bigint, 'T-D03 denied: an administrator at aal2 reads no approvals row');
select is((select count(*) from public.publications), 1::bigint, 'T-D03 valid: an administrator at aal2 reads publication metadata (for takedown screens)');
select is((select count(*) from public.topics), 0::bigint, 'topics are readable by the administrator (none exist yet)');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal1');
select is((select count(*) from public.publications), 0::bigint, 'denied: an administrator at aal1 reads no publication metadata');
-- T-A01..T-A03: anonymous readers see only the public projection
select t.as_anon();
select is((select count(*) from public.published_experiences), 1::bigint, 'T-A01 valid: anon reads the live published row');
select is((select slug from public.published_experiences), 'beta-one', 'the projection holds B''s published slug');
select throws_ok($q$select * from public.experiences$q$, '42501'::char(5), null::text, 'T-A02/T-A03 denied: anon cannot select from experiences');
select throws_ok($q$select * from public.revisions$q$, '42501'::char(5), null::text, 'T-A02/T-A03 denied: anon cannot select from revisions');
select throws_ok($q$select * from public.revision_validations$q$, '42501'::char(5), null::text, 'T-A02/T-A03 denied: anon cannot select from revision_validations');
select throws_ok($q$select * from public.approvals$q$, '42501'::char(5), null::text, 'T-A02/T-A03 denied: anon cannot select from approvals');
select throws_ok($q$select * from public.publications$q$, '42501'::char(5), null::text, 'T-A02/T-A03 denied: anon cannot select from publications');
select throws_ok($q$select * from public.experience_topics$q$, '42501'::char(5), null::text, 'T-A02/T-A03 denied: anon cannot select from experience_topics');
select is((select count(*) from public.topics), 0::bigint, 'T-A01 valid: anon can read topics (none yet)');
-- T-S02/T-L10: a suspended publisher with a still-valid session is refused at the next call
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$select public.save_revision(t.id('expA'), t.id('revA1'), t.doc('alpha-one', 'Alpha two', 'Alpha text two.'))$q$, 'before suspension: A can save a revision');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select public.set_publisher_status('00000000-0000-4000-8000-0000000000b1', 'suspended', 'synthetic');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select is((select count(*) from public.experiences), 0::bigint, 'T-S02 denied: after suspension the same claims read no experience');
select is((select count(*) from public.revisions), 0::bigint, 'T-S02 denied: after suspension the same claims read no revision');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one'))$q$, '42501'::char(5), null::text, 'T-L10 denied: a suspended publisher cannot save');
select throws_ok($q$select public.create_experience('delta-one', 'explainer', t.doc('delta-one'))$q$, '42501'::char(5), null::text, 'T-S02 denied: a suspended publisher cannot create');
select throws_ok($q$select public.approve_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'T-S02 denied: a suspended publisher cannot approve');
select throws_ok($q$select public.publish_revision(t.id('revA1'))$q$, '42501'::char(5), null::text, 'T-S02 denied: a suspended publisher cannot publish');
select t.as_owner();
select is((select count(*) from public.revisions where experience_id = t.id('expA')), 2::bigint, 'work committed before the suspension is intact');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select public.set_publisher_status('00000000-0000-4000-8000-0000000000b1', 'active', 'synthetic reinstatement');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select is((select count(*) from public.experiences), 1::bigint, 'valid twin: after reinstatement the same claims read their experience again');
select lives_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one', 'Alpha three', 'Alpha text three.'))$q$, 'valid twin: after reinstatement A can save again');

select * from finish();
rollback;
