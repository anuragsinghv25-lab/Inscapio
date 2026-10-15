-- pgTAP test file (Stage 3.2). Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(53);
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
insert into t.ids select 'r1', head_revision_id from public.experiences where id = t.id('expA');
insert into t.ids select 'r2', public.save_revision(t.id('expA'), t.id('r1'), t.doc('alpha-one', 'Two', 'Text two.'));
insert into t.ids select 'r3', public.save_revision(t.id('expA'), t.id('r2'), t.doc('alpha-one', 'Three', 'Text three.'));
insert into t.ids select 'r4', public.save_revision(t.id('expA'), t.id('r3'), t.doc('alpha-one', 'Four', 'Text four.'));
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
insert into t.ids select 'expB', public.create_experience('beta-one', 'explainer', t.doc('beta-one'));
insert into t.ids select 'rb1', head_revision_id from public.experiences where id = t.id('expB');
-- T-L02: no attestation, no approval
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.approve_revision(t.id('r1'))$q$, '55000'::char(5), null::text, 'T-L02 denied: a revision with no attestation cannot be approved');
-- T-L02: the publisher cannot write an attestation, by any path
select throws_ok($q$insert into public.revision_validations (revision_id, content_hash, validator_version, passed) select id, content_hash, 'self', true from public.revisions where id = t.id('r1')$q$, '42501'::char(5), null::text, 'T-L02 denied: no direct INSERT into revision_validations');
select throws_ok($q$select public.record_validation(t.id('r1'), true, 'self')$q$, '42501'::char(5), null::text, 'T-L02 denied: a publisher cannot call record_validation');
select throws_ok($q$select * from public.get_revision_for_validation(t.id('r1'))$q$, '42501'::char(5), null::text, 'denied: a publisher cannot call get_revision_for_validation');
-- attestation input rules
select t.as_validator();
select throws_ok($q$select public.record_validation(gen_random_uuid(), true, 'zod-1')$q$, '22023'::char(5), null::text, 'denied: an unknown revision cannot be attested');
select throws_ok($q$select public.record_validation(t.id('r1'), null, 'zod-1')$q$, '22023'::char(5), null::text, 'denied: a null verdict is refused');
select throws_ok($q$select public.record_validation(t.id('r1'), true, 'bad version!')$q$, '22023'::char(5), null::text, 'denied: a malformed validator version is refused');
select throws_ok($q$select public.record_validation(t.id('r1'), true, 'zod-1', '[{"path":"a","code":"c"}]')$q$, '22023'::char(5), null::text, 'denied: a pass may not carry errors');
select throws_ok($q$select public.record_validation(t.id('r1'), false, 'zod-1', '[]')$q$, '22023'::char(5), null::text, 'denied: a failure must list at least one error');
select throws_ok($q$select public.record_validation(t.id('r1'), false, 'zod-1', '[{"path":"a","code":"c","message":"secret content"}]')$q$, '22023'::char(5), null::text, 'denied: errors carry paths and codes only, never document text');
select throws_ok($q$select public.record_validation(t.id('r1'), false, 'zod-1', '{"path":"a"}')$q$, '22023'::char(5), null::text, 'denied: errors must be an array');
select lives_ok($q$select public.record_validation(t.id('r1'), false, 'zod-1', '[{"path":"sections.0.title","code":"too_big"}]')$q$, 'valid: a failure with paths and codes is recorded');
select throws_ok($q$select public.record_validation(t.id('r1'), false, 'zod-1', '[{"path":"a","code":"b"}]')$q$, '23505'::char(5), null::text, 'denied: the same validator version cannot attest the same revision twice');
select t.as_owner();
select is((select content_hash = (select content_hash from public.revisions where id = t.id('r1')) from public.revision_validations where revision_id = t.id('r1')), true, 'the attestation''s hash was copied by the database from the stored revision');
select is((select count(*) from public.audit_events where action = 'revision.validated' and subject_id = t.id('r1')), 1::bigint, 'the attestation wrote exactly one audit event');
-- a failed attestation blocks approval; a later passing attestation of the same content allows it
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select is((select count(*) from public.revision_validations where revision_id = t.id('r1')), 1::bigint, 'T-P12 valid: the owner can read the attestation, including its errors');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select is((select count(*) from public.revision_validations where revision_id = t.id('r1')), 0::bigint, 'T-P04 denied: another publisher cannot read it');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.approve_revision(t.id('r1'))$q$, '55000'::char(5), null::text, 'T-L02 denied: a revision whose attestation failed cannot be approved');
select t.as_validator();
select lives_ok($q$select public.record_validation(t.id('r1'), true, 'zod-2')$q$, 'valid: a newer validator version attests a pass');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$select public.approve_revision(t.id('r1'))$q$, 'valid twin: with the latest attestation passing, the revision can be approved');
select t.as_owner();
select is((select approved_by from public.approvals where revision_id = t.id('r1')), '00000000-0000-4000-8000-0000000000b1'::uuid, 'the approver is the verified caller');
select is((select approved_via from public.approvals where revision_id = t.id('r1')), 'human_session', 'the approval records the human-session path');
select is((select content_hash = (select content_hash from public.revisions where id = t.id('r1')) from public.approvals where revision_id = t.id('r1')), true, 'T-L04 the approval is bound to the revision''s content hash');
select is((select count(*) from public.audit_events where action = 'revision.approved' and subject_id = t.id('r1')), 1::bigint, 'the approval wrote exactly one audit event');
-- the latest attestation governs: a later failure withdraws eligibility
select t.as_validator();
select public.record_validation(t.id('r2'), true, 'zod-1');
select public.record_validation(t.id('r2'), false, 'zod-2', '[{"path":"hero.intro","code":"too_small"}]');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.approve_revision(t.id('r2'))$q$, '55000'::char(5), null::text, 'denied: when the latest attestation is a failure the revision cannot be approved, even though an older one passed');
-- T-L04: approval is bound to the exact revision — no approve-latest, no transfer
select t.as_validator();
select public.record_validation(t.id('r3'), true, 'zod-1');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$select public.approve_revision(t.id('r3'))$q$, 'valid: revision 3 is attested and approved');
select throws_ok($q$select public.publish_revision(t.id('r4'))$q$, '55000'::char(5), null::text, 'T-L04 denied: an approval for revision 3 cannot publish revision 4');
select throws_ok($q$select public.approve_revision(t.id('r4'))$q$, '55000'::char(5), null::text, 'denied: revision 4 has no attestation of its own');
select t.as_owner();
select throws_ok($q$insert into public.approvals (revision_id, experience_id, approved_by, content_hash) select id, experience_id, created_by, repeat('a', 64) from public.revisions where id = t.id('r4')$q$, '23503'::char(5), null::text, 'T-L04 denied: an approval with a hash that is not the revision''s hash is refused by the foreign key, even for the owner');
select throws_ok($q$insert into public.revision_validations (revision_id, content_hash, validator_version, passed) select id, repeat('b', 64), 'zod-9', true from public.revisions where id = t.id('r4')$q$, '23503'::char(5), null::text, 'denied: an attestation naming a different hash is refused by the foreign key, even for the owner');
select throws_ok($q$insert into public.approvals (revision_id, experience_id, approved_by, content_hash) select r.id, b.experience_id, r.created_by, r.content_hash from public.revisions r, public.revisions b where r.id = t.id('r4') and b.id = t.id('rb1')$q$, '23503'::char(5), null::text, 'denied: an approval naming a different experience than the revision''s is refused');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.approve_revision(t.id('r1'))$q$, '55000'::char(5), null::text, 'denied: a revision cannot be approved twice');
-- T-P06: ownership and state gates on approval
select t.as_validator();
select public.record_validation(t.id('rb1'), true, 'zod-1');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.approve_revision(t.id('rb1'))$q$, '42501'::char(5), null::text, 'T-P06 denied: A cannot approve B''s attested revision');
select throws_ok($q$select public.approve_revision(gen_random_uuid())$q$, '42501'::char(5), null::text, 'denied: an unknown revision id is indistinguishable from someone else''s');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select lives_ok($q$select public.approve_revision(t.id('rb1'))$q$, 'valid twin: B approves their own attested revision');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$update public.experiences set archived_at = now() where id = t.id('expA')$q$, 'valid: A archives the experience');
select t.as_validator();
select public.record_validation(t.id('r4'), true, 'zod-1');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.approve_revision(t.id('r4'))$q$, '55000'::char(5), null::text, 'denied: an archived experience cannot take an approval');
select lives_ok($q$update public.experiences set archived_at = null where id = t.id('expA')$q$, 'valid: A unarchives it');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select public.set_experience_hold(t.id('expA'), true, 'synthetic hold');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.approve_revision(t.id('r4'))$q$, '55000'::char(5), null::text, 'denied: a held experience cannot take an approval');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select public.set_experience_hold(t.id('expA'), false);
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$select public.approve_revision(t.id('r4'))$q$, 'valid twin: once the hold is lifted the approval succeeds');
-- only a human session can approve
select t.as_anon();
select throws_ok($q$select public.approve_revision(t.id('rb1'))$q$, '42501'::char(5), null::text, 'denied: anon cannot approve');
select t.as_authenticated_nosub();
select throws_ok($q$select public.approve_revision(t.id('rb1'))$q$, '42501'::char(5), null::text, 'denied: an authenticated role with no subject cannot approve');
select t.as_service();
select throws_ok($q$select public.approve_revision(t.id('rb1'))$q$, '42501'::char(5), null::text, 'denied: service_role cannot approve');
select t.as_user('00000000-0000-4000-8000-0000000000b3', 'aal1');
select throws_ok($q$select public.approve_revision(t.id('r1'))$q$, '42501'::char(5), null::text, 'T-S02 denied: a suspended publisher cannot approve');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select throws_ok($q$select public.approve_revision(t.id('r1'))$q$, '42501'::char(5), null::text, 'denied: an administrator cannot approve a publisher''s revision (admin is not content access)');
-- T-M05: approvals and attestations are append-only for every role
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$update public.approvals set note = 'x' where revision_id = t.id('r1')$q$, '42501'::char(5), null::text, 'denied: authenticated cannot update an approval');
select throws_ok($q$delete from public.approvals where revision_id = t.id('r1')$q$, '42501'::char(5), null::text, 'denied: authenticated cannot delete an approval');
select throws_ok($q$insert into public.approvals (revision_id, experience_id, approved_by, content_hash) select id, experience_id, created_by, content_hash from public.revisions where id = t.id('r2')$q$, '42501'::char(5), null::text, 'T-P15 denied: authenticated cannot insert an approval directly');
select t.as_owner();
select throws_ok($q$update public.approvals set note = 'x' where revision_id = t.id('r1')$q$, '55000'::char(5), null::text, 'denied: even the owner cannot update an approval');
select throws_ok($q$delete from public.approvals where revision_id = t.id('r1')$q$, '55000'::char(5), null::text, 'denied: even the owner cannot delete an approval');
select throws_ok($q$update public.revision_validations set passed = true where revision_id = t.id('r1')$q$, '55000'::char(5), null::text, 'denied: even the owner cannot alter an attestation');
select throws_ok($q$delete from public.revision_validations where revision_id = t.id('r1')$q$, '55000'::char(5), null::text, 'denied: even the owner cannot delete an attestation');
select throws_ok($q$truncate public.revision_validations$q$, '55000'::char(5), null::text, 'denied: even the owner cannot truncate attestations');

select * from finish();
rollback;
