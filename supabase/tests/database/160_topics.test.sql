-- pgTAP test file (Stage 3.2). Synthetic fixtures only (example.test addresses, fixed fake UUIDs).
-- Runs inside one transaction that is rolled back. Roles are REAL database roles:
-- `set local role` + request.jwt.claims is how PostgREST presents a caller to Postgres.
begin;
create extension if not exists pgtap with schema extensions;
select plan(40);
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

-- T-D05: topics — administrator (aal2) writes; everyone else reads
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select lives_ok($q$insert into public.topics (slug, title, description, position) values ('science-topic', 'Science', 'Synthetic description', 2)$q$, 'T-D05 valid: an administrator at aal2 can create a topic');
select lives_ok($q$insert into public.topics (slug, title) values ('arts-topic', 'Arts')$q$, 'valid: a second topic');
insert into t.ids select 'topicSci', id from public.topics where slug = 'science-topic';
insert into t.ids select 'topicArts', id from public.topics where slug = 'arts-topic';
select lives_ok($q$update public.topics set title = 'Science and nature' where slug = 'science-topic'$q$, 'T-D05 valid: an administrator at aal2 can update a topic');
select throws_ok($q$insert into public.topics (slug, title) values ('Bad Slug', 'x')$q$, '23514'::char(5), null::text, 'a malformed topic slug is refused');
select throws_ok($q$insert into public.topics (slug, title) values ('science-topic', 'dup')$q$, '23505'::char(5), null::text, 'a duplicate topic slug is refused');
select throws_ok($q$update public.topics set id = gen_random_uuid() where slug = 'arts-topic'$q$, '42501'::char(5), null::text, 'denied: the topic id is not updatable by any API role');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal1');
select throws_ok($q$insert into public.topics (slug, title) values ('late-topic', 'Late')$q$, '42501'::char(5), null::text, 'T-D05 denied: an administrator at aal1 cannot create a topic');
with u as (update public.topics set title = 'x' returning 1) select is((select count(*) from u), 0::bigint, 'T-D05 denied: an administrator at aal1 cannot update a topic');
with d as (delete from public.topics returning 1) select is((select count(*) from d), 0::bigint, 'T-D05 denied: an administrator at aal1 cannot delete a topic');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$insert into public.topics (slug, title) values ('late-topic', 'Late')$q$, '42501'::char(5), null::text, 'T-D05 denied: a publisher cannot create a topic');
with u as (update public.topics set title = 'x' returning 1) select is((select count(*) from u), 0::bigint, 'T-D05 denied: a publisher cannot update a topic');
with d as (delete from public.topics returning 1) select is((select count(*) from d), 0::bigint, 'T-D05 denied: a publisher cannot delete a topic');
select t.as_user('00000000-0000-4000-8000-0000000000c1', 'aal1');
select throws_ok($q$insert into public.topics (slug, title) values ('late-topic', 'Late')$q$, '42501'::char(5), null::text, 'T-D05 denied: a user with no capability cannot create a topic');
with u as (update public.topics set title = 'x' returning 1) select is((select count(*) from u), 0::bigint, 'T-D05 denied: a user with no capability cannot update a topic');
with d as (delete from public.topics returning 1) select is((select count(*) from d), 0::bigint, 'T-D05 denied: a user with no capability cannot delete a topic');
select t.as_anon();
select throws_ok($q$insert into public.topics (slug, title) values ('late-topic', 'Late')$q$, '42501'::char(5), null::text, 'T-D05 denied: anon cannot create a topic');
select throws_ok($q$update public.topics set title = 'x'$q$, '42501'::char(5), null::text, 'T-D05 denied: anon cannot update a topic');
select throws_ok($q$delete from public.topics$q$, '42501'::char(5), null::text, 'T-D05 denied: anon cannot delete a topic');
select is((select count(*) from public.topics), 2::bigint, 'T-D05 valid: anon reads topics');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select is((select count(*) from public.topics), 2::bigint, 'T-D05 valid: a publisher reads topics');
select is((select title from public.topics where slug = 'science-topic'), 'Science and nature', 'the administrator''s update took effect');
select t.as_owner();
select is((select count(*) from public.audit_events where subject_type = 'topic' and action = 'topic.created' and actor_id = '00000000-0000-4000-8000-0000000000a1' and actor_kind = 'admin'), 2::bigint, 'each topic creation wrote an admin audit event');
select is((select count(*) from public.audit_events where subject_type = 'topic' and action = 'topic.updated'), 1::bigint, 'the topic update wrote an audit event');
select is((select count(*) from public.audit_events where subject_type = 'topic' and details::text like '%Science%'), 0::bigint, 'topic audit events carry ids only, never content');
-- experience_topics: owner-managed, isolated, copied to the projection at publish
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
insert into t.ids select 'expA', public.create_experience('alpha-one', 'explainer', t.doc('alpha-one'));
insert into t.ids select 'r1', head_revision_id from public.experiences where id = t.id('expA');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
insert into t.ids select 'expB', public.create_experience('beta-one', 'explainer', t.doc('beta-one'));
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$insert into public.experience_topics (experience_id, topic_id) values (t.id('expA'), t.id('topicSci'))$q$, 'valid: A attaches a topic to their own experience');
select lives_ok($q$insert into public.experience_topics (experience_id, topic_id) values (t.id('expA'), t.id('topicArts'))$q$, 'valid: A attaches a second topic');
select throws_ok($q$insert into public.experience_topics (experience_id, topic_id) values (t.id('expB'), t.id('topicSci'))$q$, '42501'::char(5), null::text, 'denied: A cannot attach a topic to B''s experience');
select is((select count(*) from public.experience_topics), 2::bigint, 'valid: A reads their own topic links');
select t.as_user('00000000-0000-4000-8000-0000000000b2', 'aal1');
select is((select count(*) from public.experience_topics), 0::bigint, 'denied: B reads none of A''s topic links');
with d as (delete from public.experience_topics returning 1) select is((select count(*) from d), 0::bigint, 'denied: B cannot detach the other publisher''s topic links');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select is((select count(*) from public.experience_topics), 0::bigint, 'T-D03 denied: an administrator reads no topic links (no content access)');
select throws_ok($q$delete from public.topics where slug = 'science-topic'$q$, '23503'::char(5), null::text, 'denied: a topic that is attached to an experience cannot be deleted');
select t.as_anon();
select throws_ok($q$select * from public.experience_topics$q$, '42501'::char(5), null::text, 'denied: anon cannot read topic links');
select throws_ok($q$insert into public.experience_topics (experience_id, topic_id) values (t.id('expA'), t.id('topicSci'))$q$, '42501'::char(5), null::text, 'denied: anon cannot attach topics');
select t.as_validator();
select public.record_validation(t.id('r1'), true, 'zod-1');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select public.approve_revision(t.id('r1'));
select public.publish_revision(t.id('r1'));
select t.as_anon();
select is((select topic_slugs::text from public.published_experiences where slug = 'alpha-one'), '{arts-topic,science-topic}', 'valid: the projection carries the topic slugs, sorted, copied at publish time');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select lives_ok($q$delete from public.experience_topics where experience_id = t.id('expA') and topic_id = t.id('topicArts')$q$, 'valid: A detaches a topic from their own experience');
select is((select count(*) from public.experience_topics), 1::bigint, 'the detach took effect');
select t.as_anon();
select is((select topic_slugs::text from public.published_experiences where slug = 'alpha-one'), '{arts-topic,science-topic}', 'the live projection does not change until the next publish');
select t.as_user('00000000-0000-4000-8000-0000000000a1', 'aal2');
select public.set_publisher_status('00000000-0000-4000-8000-0000000000b1', 'suspended', 'synthetic');
select t.as_user('00000000-0000-4000-8000-0000000000b1', 'aal1');
select throws_ok($q$insert into public.experience_topics (experience_id, topic_id) values (t.id('expA'), t.id('topicArts'))$q$, '42501'::char(5), null::text, 'T-S02 denied: a suspended publisher cannot attach topics');
select is((select count(*) from public.experience_topics), 0::bigint, 'T-S02 denied: a suspended publisher reads no topic links');

select * from finish();
rollback;
