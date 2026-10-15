-- pgTAP test file (Stage 3.2). Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(55);
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

select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'expA', public.create_experience('alpha-one', 'explainer', t.doc('alpha-one'));
insert into t.ids select 'rev1', head_revision_id from public.experiences where id = t.id('expA');
insert into t.ids select 'expH', public.create_experience('hash-probe', 'explainer', t.doc('hash-probe'));
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
insert into t.ids select 'expB', public.create_experience('beta-one', 'explainer', t.doc('beta-one'));
insert into t.ids select 'revB1', head_revision_id from public.experiences where id = t.id('expB');
-- save_revision: append, chain, derive
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'rev2', public.save_revision(t.id('expA'), t.id('rev1'), t.doc('alpha-one', 'Alpha two', 'Second text.'), 'second draft');
select t.as_owner();
select is((select seq from public.revisions where id = t.id('rev2')), 2, 'valid: the second revision has seq 2');
select is((select parent_id from public.revisions where id = t.id('rev2')), t.id('rev1'), 'the parent is the previous head');
select is((select head_revision_id from public.experiences where id = t.id('expA')), t.id('rev2'), 'the head advanced to the new revision');
select is((select title from public.experiences where id = t.id('expA')), 'Alpha two', 'the derived title follows the head document');
select is((select note from public.revisions where id = t.id('rev2')), 'second draft', 'the note is stored');
select is((select created_by from public.revisions where id = t.id('rev2')), '00000000-0000-4000-8000-0000000000b1'::uuid, 'the author is the verified caller');
select is((select author_kind from public.revisions where id = t.id('rev2')), 'human', 'the author kind is human');
-- content hash: computed by the database from the stored document
select is((select content_hash = pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(document::text, 'UTF8')), 'hex') from public.revisions where id = t.id('rev2')), true, 'the stored hash is the sha-256 of the stored document');
insert into public.revisions (id, experience_id, seq, parent_id, created_by, schema_version, document, content_hash) select gen_random_uuid(), r.experience_id, 2, r.id, r.created_by, r.schema_version, r.document, repeat('0', 64) from public.revisions r where r.experience_id = t.id('expH') and r.seq = 1;
select is((select content_hash = pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(document::text, 'UTF8')), 'hex') and content_hash <> repeat('0', 64) from public.revisions where experience_id = t.id('expH') and seq = 2), true, 'a caller-supplied hash is overwritten: even the table owner cannot store a false hash');
select is((select count(distinct content_hash) from public.revisions where experience_id = t.id('expA')), 2::bigint, 'different documents have different hashes');
-- T-L06: optimistic concurrency — a stale or missing expected parent is a conflict, never an overwrite
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.save_revision(t.id('expA'), t.id('rev1'), t.doc('alpha-one', 'Stale', 'Stale text.'))$q$, '23505'::char(5), null::text, 'T-L06 denied: saving from a stale parent is an edit conflict');
select throws_ok($q$select public.save_revision(t.id('expA'), null, t.doc('alpha-one', 'Null parent', 'x'))$q$, '23505'::char(5), null::text, 'T-L06 denied: saving with no expected parent is an edit conflict');
select throws_ok($q$select public.save_revision(t.id('expA'), t.id('revB1'), t.doc('alpha-one', 'Foreign parent', 'x'))$q$, '23505'::char(5), null::text, 'T-L06 denied: another experience''s revision is not the head');
select t.as_owner();
select is((select count(*) from public.revisions where experience_id = t.id('expA')), 2::bigint, 'refused saves wrote no revision');
select is((select head_revision_id from public.experiences where id = t.id('expA')), t.id('rev2'), 'the head is unchanged by refused saves');
select is((select title from public.experiences where id = t.id('expA')), 'Alpha two', 'the derived title is unchanged by refused saves');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$select public.save_revision(t.id('expA'), t.id('rev2'), t.doc('alpha-one', 'Alpha three', 'Third text.'))$q$, 'valid twin: saving from the current head succeeds');
-- T-L07: restore creates a new revision; the old one is byte-identical
select t.as_owner();
insert into t.ids select 'rev1doc', gen_random_uuid();
create temp table t_before as select id, document, content_hash, note, seq, parent_id from public.revisions where experience_id = t.id('expA');
grant select on t_before to public;
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'rev4', public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), null, 'restore of the first draft', t.id('rev1'));
select t.as_owner();
select is((select seq from public.revisions where id = t.id('rev4')), 4, 'valid: a restore appends a new revision (seq 4)');
select is((select restored_from from public.revisions where id = t.id('rev4')), t.id('rev1'), 'the restore records its source');
select is((select document from public.revisions where id = t.id('rev4')), (select document from public.revisions where id = t.id('rev1')), 'the restored document equals the source document');
select is((select count(*) from t_before b join public.revisions r on r.id = b.id where r.document = b.document and r.content_hash = b.content_hash and r.note is not distinct from b.note and r.seq = b.seq and r.parent_id is not distinct from b.parent_id), (select count(*) from t_before), 'T-L07 every earlier revision is byte-identical after the restore');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.save_revision(t.id('expA'), t.id('rev4'), t.doc('alpha-one'), null, t.id('rev1'))$q$, '22023'::char(5), null::text, 'denied: a restore may not also supply a document');
select throws_ok($q$select public.save_revision(t.id('expA'), t.id('rev4'), null, null, t.id('revB1'))$q$, '22023'::char(5), null::text, 'denied: a restore source from another experience is refused');
select throws_ok($q$select public.save_revision(t.id('expA'), t.id('rev4'), null)$q$, '22023'::char(5), null::text, 'denied: no document and no restore source is refused');
-- T-P14: revisions are append-only for every role
select throws_ok($q$update public.revisions set note = 'edited' where id = t.id('rev1')$q$, '42501'::char(5), null::text, 'T-P14 denied: authenticated cannot update a revision');
select throws_ok($q$delete from public.revisions where id = t.id('rev1')$q$, '42501'::char(5), null::text, 'T-P14 denied: authenticated cannot delete a revision');
select t.as_service();
select throws_ok($q$update public.revisions set note = 'edited' where id = t.id('rev1')$q$, '42501'::char(5), null::text, 'T-P14 denied: service_role cannot update a revision');
select t.as_owner();
select throws_ok($q$update public.revisions set note = 'edited' where id = t.id('rev1')$q$, '55000'::char(5), null::text, 'T-P14/T-M05 denied: even the table owner cannot update a revision (trigger)');
select throws_ok($q$update public.revisions set document = '{}'::jsonb where id = t.id('rev1')$q$, '55000'::char(5), null::text, 'T-M05 denied: even the owner cannot rewrite a document');
select throws_ok($q$delete from public.revisions where id = t.id('rev1')$q$, '55000'::char(5), null::text, 'T-M05 denied: even the owner cannot delete a revision');
select throws_ok($q$truncate public.revisions$q$, '0A000'::char(5), null::text, 'T-M05 denied: even the owner cannot truncate revisions (referenced by foreign keys; the truncate trigger is the second guard)');
select is((select count(*) from public.revisions where id = t.id('rev1') and note is null), 1::bigint, 'the first revision is unchanged by every attempt');
-- T-L13: the shape gate rejects malformed documents at save
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), jsonb_set(t.doc('alpha-one'), '{schemaVersion}', '2'))$q$, '22023'::char(5), null::text, 'T-L13 denied: a wrong schemaVersion');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one') - 'schemaVersion')$q$, '22023'::char(5), null::text, 'T-L13 denied: a missing schemaVersion');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one') || '{"onclick": "x"}'::jsonb)$q$, '22023'::char(5), null::text, 'T-L13 denied: an unknown top-level key (script-like field)');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), jsonb_set(t.doc('alpha-one'), '{sections,0,blocks,0,type}', '"html"'))$q$, '22023'::char(5), null::text, 'T-L13 denied: an unknown block type');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), jsonb_set(t.doc('alpha-one'), '{sections}', '[]'))$q$, '22023'::char(5), null::text, 'T-L13 denied: an empty sections list');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), jsonb_set(t.doc('alpha-one'), '{sections,0,blocks}', '"nope"'))$q$, '22023'::char(5), null::text, 'T-L13 denied: a non-array blocks value');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), jsonb_set(t.doc('alpha-one'), '{endnotes}', '[{"type":"stepper"}]'))$q$, '22023'::char(5), null::text, 'T-L13 denied: a non-endnote block in endnotes');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), jsonb_set(t.doc('alpha-one'), '{language}', '"English"'))$q$, '22023'::char(5), null::text, 'T-L13 denied: a malformed language code');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one', repeat('t', 201)))$q$, '22023'::char(5), null::text, 'T-L13 denied: an over-long title');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one', 'ok', repeat('x', 1100000)))$q$, '22023'::char(5), null::text, 'T-L13 denied: an over-size document (> 1 MiB)');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), '[]'::jsonb)$q$, '22023'::char(5), null::text, 'T-L13 denied: a non-object document');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('someone-else'))$q$, '22023'::char(5), null::text, 'T-L13 denied: a document whose slug differs from the experience');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one', p_kind => 'data-story'))$q$, '22023'::char(5), null::text, 'T-L13 denied: a document whose kind differs from the experience');
select t.as_owner();
select is((select count(*) from public.revisions where experience_id = t.id('expA')), 4::bigint, 'no rejected document was stored');
select throws_ok($q$insert into public.revisions (experience_id, seq, parent_id, created_by, schema_version, document) select experience_id, 5, id, created_by, 1, '{"schemaVersion":1}'::jsonb from public.revisions where id = t.id('rev4')$q$, '23514'::char(5), null::text, 'the shape gate is also a table CHECK: even a direct owner insert of a malformed document fails');
select throws_ok($q$insert into public.revisions (experience_id, seq, parent_id, created_by, schema_version, document) select experience_id, 5, id, created_by, 1, t.doc('alpha-one') from public.revisions where id = t.id('rev4') union all select experience_id, 5, id, created_by, 1, t.doc('alpha-one') from public.revisions where id = t.id('rev4')$q$, '23505'::char(5), null::text, 'revisions (experience, seq) is unique: two revisions cannot share a position');
select throws_ok($q$insert into public.revisions (experience_id, seq, parent_id, created_by, schema_version, document) select experience_id, 5, null, created_by, 1, t.doc('alpha-one') from public.revisions where id = t.id('rev4')$q$, '23514'::char(5), null::text, 'only revision 1 may have no parent');
select throws_ok($q$insert into public.revisions (experience_id, seq, parent_id, created_by, schema_version, document) select r.experience_id, 5, b.id, r.created_by, 1, t.doc('alpha-one') from public.revisions r, public.revisions b where r.id = t.id('rev4') and b.id = t.id('revB1')$q$, '23503'::char(5), null::text, 'a parent from another experience is refused by the composite foreign key');
-- archived and held experiences
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$update public.experiences set archived_at = now() where id = t.id('expA')$q$, 'valid: A archives their draft');
select throws_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one', 'Archived', 'x'))$q$, '55000'::char(5), null::text, 'denied: an archived experience cannot take a new revision');
select lives_ok($q$update public.experiences set archived_at = null where id = t.id('expA')$q$, 'valid: A unarchives it');
select lives_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one', 'Unarchived', 'x'))$q$, 'valid twin: after unarchiving a revision can be saved again');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select public.set_experience_hold(t.id('expA'), true, 'synthetic hold');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$select public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one', 'Held draft', 'x'))$q$, 'a hold blocks approval and publication, not drafting: a held experience still takes revisions');

select * from finish();
rollback;
