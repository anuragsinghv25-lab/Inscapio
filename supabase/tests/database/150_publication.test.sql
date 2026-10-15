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

select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'expA', public.create_experience('alpha-one', 'explainer', t.doc('alpha-one', 'Alpha one', 'First text.'));
insert into t.ids select 'r1', head_revision_id from public.experiences where id = t.id('expA');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
insert into t.ids select 'expB', public.create_experience('beta-one', 'explainer', t.doc('beta-one'));
insert into t.ids select 'rb1', head_revision_id from public.experiences where id = t.id('expB');
-- T-L03: an unapproved revision cannot be published, and a publication row cannot exist without an approval
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.publish_revision(t.id('r1'))$q$, '55000'::char(5), null::text, 'T-L03 denied: publishing an unapproved revision is refused');
select t.as_validator();
select public.record_validation(t.id('r1'), true, 'zod-1');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.publish_revision(t.id('r1'))$q$, '55000'::char(5), null::text, 'T-L03 denied: an attested but unapproved revision is still refused');
select t.as_owner();
select throws_ok($q$insert into public.publications (experience_id, revision_id, slug_at_publish, published_by) select experience_id, id, 'alpha-one', created_by from public.revisions where id = t.id('r1')$q$, '23503'::char(5), null::text, 'T-L03 denied: even the owner cannot insert a publication for an unapproved revision (foreign key to approvals)');
select is((select count(*) from public.published_experiences), 0::bigint, 'nothing is public yet');
-- happy path (T-L01): approve, publish, anon reads
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select public.approve_revision(t.id('r1'));
insert into t.ids select 'pub1', public.publish_revision(t.id('r1'));
select t.as_anon();
select is((select count(*) from public.published_experiences where slug = 'alpha-one'), 1::bigint, 'T-L01 valid: anon reads the published experience by slug');
select t.as_owner();
select is((select document from public.published_experiences where experience_id = t.id('expA')), (select document from public.revisions where id = t.id('r1')), 'the projection is a byte-for-byte copy of the approved revision''s document');
select is((select title || '|' || summary || '|' || language || '|' || kind || '|' || publisher_id::text from public.published_experiences where experience_id = t.id('expA')), 'Alpha one|Synthetic summary.|en|explainer|00000000-0000-4000-8000-0000000000b1', 'the projection''s columns come from the approved revision and the stored experience');
select is((select publication_id from public.published_experiences where experience_id = t.id('expA')), t.id('pub1'), 'the projection points at its publication');
select is((select slug_locked_at is not null from public.experiences where id = t.id('expA')), true, 'first publication locks the slug');
select is((select count(*) from public.audit_events where action = 'publication.published' and subject_id = t.id('pub1')), 1::bigint, 'publication wrote exactly one audit event');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.publish_revision(t.id('r1'))$q$, '55000'::char(5), null::text, 'denied: the same revision cannot be published twice');
-- T-L05: drafts never change what the public sees; publishing a newer approved revision supersedes atomically
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'r2', public.save_revision(t.id('expA'), t.id('r1'), t.doc('alpha-one', 'Alpha two', 'Second text.'));
select t.as_anon();
select is((select title from public.published_experiences where slug = 'alpha-one'), 'Alpha one', 'T-L05 a newer draft does not change the public title');
select is((select (document #>> '{sections,0,blocks,0,text}') from public.published_experiences where slug = 'alpha-one'), 'First text.', 'T-L05 a newer draft does not change the public text');
select t.as_owner();
select is((select content_hash from public.revisions where id = (select r.revision_id from public.publications r where r.id = t.id('pub1'))), (select content_hash from public.revisions where id = t.id('r1')), 'the live publication still names revision 1');
select t.as_validator();
select public.record_validation(t.id('r2'), true, 'zod-1');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select public.approve_revision(t.id('r2'));
insert into t.ids select 'pub2', public.publish_revision(t.id('r2'));
select t.as_anon();
select is((select title from public.published_experiences where slug = 'alpha-one'), 'Alpha two', 'T-L05 after publishing revision 2 the public sees revision 2');
select is((select count(*) from public.published_experiences), 1::bigint, 'still exactly one public row for the experience');
select t.as_owner();
select is((select count(*) from public.publications where experience_id = t.id('expA') and unpublished_at is null), 1::bigint, 'T-L09 exactly one live publication');
select is((select unpublish_reason || '/' || unpublished_by_kind from public.publications where id = t.id('pub1')), 'superseded/publisher', 'the first publication was closed as superseded in the same transaction');
select is((select count(*) from public.publications where experience_id = t.id('expA')), 2::bigint, 'publication history is retained');
select throws_ok($q$insert into public.publications (experience_id, revision_id, slug_at_publish, published_by) select experience_id, revision_id, slug_at_publish, published_by from public.publications where id = t.id('pub2')$q$, '23505'::char(5), null::text, 'T-L09 denied: a second live publication for the same experience is refused by the partial unique index');
-- publication rows: only the unpublish columns, once; never deleted
select throws_ok($q$update public.publications set published_at = now() - interval '1 day' where id = t.id('pub2')$q$, '55000'::char(5), null::text, 'denied: published_at cannot be rewritten');
select throws_ok($q$update public.publications set revision_id = t.id('r1') where id = t.id('pub2')$q$, '55000'::char(5), null::text, 'denied: the published revision cannot be swapped');
select throws_ok($q$update public.publications set unpublish_note = 'edit' where id = t.id('pub1')$q$, '55000'::char(5), null::text, 'denied: a closed publication cannot change');
select throws_ok($q$delete from public.publications where id = t.id('pub1')$q$, '55000'::char(5), null::text, 'denied: a publication is never deleted, even by the owner');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$update public.publications set unpublished_at = now() where id = t.id('pub2')$q$, '42501'::char(5), null::text, 'T-P15 denied: authenticated cannot update a publication directly');
select throws_ok($q$delete from public.publications where id = t.id('pub2')$q$, '42501'::char(5), null::text, 'T-P15 denied: authenticated cannot delete a publication');
select throws_ok($q$insert into public.publications (experience_id, revision_id, slug_at_publish, published_by) select experience_id, revision_id, slug_at_publish, published_by from public.publications where id = t.id('pub2')$q$, '42501'::char(5), null::text, 'T-P15 denied: authenticated cannot insert a publication directly');
-- the public projection is not writable by any API role
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$insert into public.published_experiences (experience_id, publication_id, slug, kind, title, summary, language, schema_version, document, publisher_id) select experience_id, publication_id, 'forged-one', kind, title, summary, language, schema_version, document, publisher_id from public.published_experiences$q$, '42501'::char(5), null::text, 'T-P15 denied: a publisher cannot insert into the public projection');
select throws_ok($q$update public.published_experiences set title = 'forged'$q$, '42501'::char(5), null::text, 'T-P15 denied: a publisher cannot rewrite the public projection');
select throws_ok($q$delete from public.published_experiences$q$, '42501'::char(5), null::text, 'T-P15 denied: a publisher cannot delete from the public projection');
select t.as_anon();
select throws_ok($q$update public.published_experiences set title = 'forged'$q$, '42501'::char(5), null::text, 'denied: anon cannot rewrite the public projection');
select throws_ok($q$delete from public.published_experiences$q$, '42501'::char(5), null::text, 'denied: anon cannot delete from the public projection');
select t.as_service();
select throws_ok($q$update public.published_experiences set title = 'forged'$q$, '42501'::char(5), null::text, 'T-X07 denied: service_role cannot rewrite the public projection');
select t.as_owner();
select throws_ok($q$insert into public.published_experiences (experience_id, publication_id, slug, kind, title, summary, language, schema_version, document, publisher_id) select experience_id, publication_id, 'forged-two', kind, title, summary, language, schema_version, document, publisher_id from public.published_experiences$q$, '23505'::char(5), null::text, 'one public row per experience and publication (primary and unique keys)');
-- unpublish: owner only, atomic, history and slug retained
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select throws_ok($q$select public.unpublish_experience(t.id('expA'))$q$, '42501'::char(5), null::text, 'T-P08 denied: B cannot unpublish A''s experience');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.unpublish_experience(t.id('expA'), repeat('x', 281))$q$, '22023'::char(5), null::text, 'denied: an over-long note is refused');
select public.unpublish_experience(t.id('expA'), 'synthetic unpublish');
select t.as_anon();
select is((select count(*) from public.published_experiences), 0::bigint, 'T-A04 the public row is gone after unpublish');
select is((select count(*) from public.published_experiences where slug = 'alpha-one'), 0::bigint, 'T-A04 a query by slug returns nothing');
select t.as_owner();
select is((select unpublish_reason || '/' || unpublished_by_kind || '/' || unpublish_note from public.publications where id = t.id('pub2')), 'publisher_request/publisher/synthetic unpublish', 'the publication was closed with reason, actor kind and note');
select is((select count(*) from public.publications where experience_id = t.id('expA')), 2::bigint, 'publication history is retained after unpublish');
select is((select count(*) from public.audit_events where action = 'publication.unpublished' and subject_id = t.id('pub2')), 1::bigint, 'unpublish wrote exactly one audit event');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.unpublish_experience(t.id('expA'))$q$, '55000'::char(5), null::text, 'denied: an experience that is not published cannot be unpublished');
insert into t.ids select 'r3', public.save_revision(t.id('expA'), t.id('r2'), t.doc('alpha-one', 'Alpha three', 'Third text.'));
select t.as_anon();
select is((select count(*) from public.published_experiences), 0::bigint, 'T-A04 a newer draft never appears publicly after unpublish');
-- T-L08: slugs stay reserved
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select throws_ok($q$select public.create_experience('alpha-one', 'explainer', t.doc('alpha-one'))$q$, '23505'::char(5), null::text, 'T-L08 denied: B cannot take a slug after A unpublished it');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$update public.experiences set slug = 'renamed' where id = t.id('expA')$q$, '42501'::char(5), null::text, 'T-L08 denied: A cannot change a slug (no column privilege)');
select t.as_owner();
select throws_ok($q$update public.experiences set slug = 'renamed' where id = t.id('expA')$q$, '55000'::char(5), null::text, 'T-L08 denied: even the owner cannot change the slug after first publication (trigger)');
select throws_ok($q$update public.experiences set slug_locked_at = null where id = t.id('expA')$q$, '55000'::char(5), null::text, 'denied: the slug lock cannot be cleared');
select throws_ok($q$update public.experiences set publisher_id = '00000000-0000-4000-8000-0000000000b2' where id = t.id('expA')$q$, '55000'::char(5), null::text, 'denied: even the owner cannot change the experience owner');
select throws_ok($q$delete from public.experiences where id = t.id('expA')$q$, '23503'::char(5), null::text, 'T-P18 denied: an experience with history cannot be deleted (foreign keys restrict)');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'expC', public.create_experience('gamma-one', 'explainer', t.doc('gamma-one'));
select t.as_owner();
select lives_ok($q$update public.experiences set slug = 'gamma-renamed' where id = t.id('expC')$q$, 'valid twin: before first publication the slug is not yet locked (no API path changes it)');
-- republish after unpublish: a new publication
select t.as_validator();
select public.record_validation(t.id('r3'), true, 'zod-1');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select public.approve_revision(t.id('r3'));
insert into t.ids select 'pub3', public.publish_revision(t.id('r3'));
select t.as_anon();
select is((select title from public.published_experiences where slug = 'alpha-one'), 'Alpha three', 'valid: after unpublish an approved revision can be published again');
select t.as_owner();
select is((select count(*) from public.publications where experience_id = t.id('expA')), 3::bigint, 'a new publication row was created; history is intact');
-- T-L12: admin takedown — atomic removal, hold, no republish until lifted
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.admin_takedown(t.id('expA'), 'policy', 'x')$q$, '42501'::char(5), null::text, 'denied: a publisher cannot take down');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal1');
select throws_ok($q$select public.admin_takedown(t.id('expA'), 'policy', 'synthetic note')$q$, '42501'::char(5), null::text, 'denied: an administrator at aal1 cannot take down');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select throws_ok($q$select public.admin_takedown(t.id('expA'), 'fun', 'synthetic note')$q$, '22023'::char(5), null::text, 'denied: a reason code outside the allow-list is refused');
select throws_ok($q$select public.admin_takedown(t.id('expA'), 'policy', '')$q$, '22023'::char(5), null::text, 'denied: a note is required');
select throws_ok($q$select public.admin_takedown(gen_random_uuid(), 'policy', 'synthetic note')$q$, '22023'::char(5), null::text, 'denied: an unknown experience is refused');
select throws_ok($q$select public.set_experience_hold(t.id('expA'), true, 'while live')$q$, '55000'::char(5), null::text, 'denied: a live experience can only be held through admin_takedown');
select public.admin_takedown(t.id('expA'), 'safety', 'synthetic takedown');
select t.as_anon();
select is((select count(*) from public.published_experiences), 0::bigint, 'T-L12 the public row is gone after takedown');
select t.as_owner();
select is((select unpublish_reason || '/' || unpublished_by_kind || '/' || unpublished_by::text from public.publications where id = t.id('pub3')), 'safety/admin/00000000-0000-4000-8000-0000000000a1', 'T-L12 the publication records the reason code, the admin kind and the acting admin');
select is((select held_at is not null and held_reason = 'synthetic takedown' from public.experiences where id = t.id('expA')), true, 'T-L12 the hold is set with the note');
select is((select count(*) from public.audit_events where action = 'publication.taken_down' and subject_id = t.id('pub3') and details = jsonb_build_object('experience_id', t.id('expA'), 'publication_id', t.id('pub3'), 'reason_code', 'safety')), 1::bigint, 'takedown wrote exactly one audit event, with codes and ids only');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select throws_ok($q$select public.admin_takedown(t.id('expA'), 'policy', 'again')$q$, '55000'::char(5), null::text, 'denied: an experience that is not published cannot be taken down again');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'r4', public.save_revision(t.id('expA'), (select head_revision_id from public.experiences where id = t.id('expA')), t.doc('alpha-one', 'Alpha four', 'Fourth text.'));
select t.as_validator();
select public.record_validation(t.id('r4'), true, 'zod-1');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.approve_revision(t.id('r4'))$q$, '55000'::char(5), null::text, 'T-L12 denied: while held the owner cannot approve');
select throws_ok($q$select public.publish_revision(t.id('r3'))$q$, '55000'::char(5), null::text, 'T-L12 denied: while held the owner cannot republish');
select is((select count(*) from public.publications where experience_id = t.id('expA') and unpublished_at is not null), 3::bigint, 'the owner can still read the closed publication history');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select throws_ok($q$select public.set_experience_hold(t.id('expA'), false)$q$, '42501'::char(5), null::text, 'denied: a publisher cannot lift a hold');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select public.set_experience_hold(t.id('expA'), false);
select throws_ok($q$select public.set_experience_hold(t.id('expA'), false)$q$, '55000'::char(5), null::text, 'denied: lifting a hold that is not set is refused');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select public.approve_revision(t.id('r4'));
insert into t.ids select 'pub4', public.publish_revision(t.id('r4'));
select t.as_anon();
select is((select title from public.published_experiences where slug = 'alpha-one'), 'Alpha four', 'T-L12 valid twin: after an admin lifts the hold the owner can publish again');
-- T-L11: the audit insert and the action are one transaction
select t.as_owner();
create function t.fail_audit() returns trigger language plpgsql as $f$ begin raise exception 'synthetic audit failure' using errcode = 'P0001'; end $f$;
create trigger t_fail_audit before insert on public.audit_events for each row when (new.action = 'publication.unpublished') execute function t.fail_audit();
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.unpublish_experience(t.id('expA'))$q$, 'P0001'::char(5), null::text, 'T-L11 when the audit insert fails, the unpublish fails');
select t.as_owner();
select is((select count(*) from public.publications where experience_id = t.id('expA') and unpublished_at is null), 1::bigint, 'T-L11 the publication is still live: nothing was half-done');
select is((select count(*) from public.published_experiences where experience_id = t.id('expA')), 1::bigint, 'T-L11 the public row is still present');
drop trigger t_fail_audit on public.audit_events;
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$select public.unpublish_experience(t.id('expA'))$q$, 'valid twin: with the audit insert working, the unpublish succeeds');
-- suspension: committed work stays; the suspended publisher cannot publish or unpublish
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'pub5', public.publish_revision(t.id('r4'));
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select public.set_publisher_status('00000000-0000-4000-8000-0000000000b1', 'suspended', 'synthetic');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$select public.unpublish_experience(t.id('expA'))$q$, '42501'::char(5), null::text, 'T-S02 denied: a suspended publisher cannot unpublish');
select t.as_anon();
select is((select count(*) from public.published_experiences where slug = 'alpha-one'), 1::bigint, 'already-published content stays live when the publisher is suspended (an admin may take it down)');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select lives_ok($q$select public.admin_takedown(t.id('expA'), 'policy', 'synthetic takedown of a suspended publisher')$q$, 'valid: an administrator can take down content of a suspended publisher without any content access');

select * from finish();
rollback;
