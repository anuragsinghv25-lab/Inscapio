-- Stage 3.2 / migration 4: the experience lifecycle functions.
-- Every function: SECURITY DEFINER, empty search_path, schema-qualified names, EXECUTE revoked from
-- PUBLIC and granted to named roles only, authorisation re-checked inside, identity from auth.uid()
-- (never an argument), and the audit row written in the same transaction as the change.
-- Errors: 42501 denied, 22023 invalid argument, 55000 state refusal, 23505 conflict.

-- Lock an experience the caller owns, then re-check that the publisher is still active. The second
-- check runs after the lock, so a suspension committed while this call waited refuses it (data model 6.1).
create function private.lock_owned_experience(p_experience_id uuid) returns public.experiences
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_exp public.experiences;
begin
  if v_uid is null or (select private.current_publisher_id()) is null then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  select * into v_exp from public.experiences e where e.id = p_experience_id for update;
  if not found or v_exp.publisher_id <> v_uid then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  if (select private.current_publisher_id()) is null then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  return v_exp;
end;
$$;

-- Parse the declared schema version from a document without raising on bad input.
create function private.document_schema_version(doc jsonb) returns integer
language sql immutable set search_path = '' as $$
  select case when jsonb_typeof(doc -> 'schemaVersion') = 'number' and (doc ->> 'schemaVersion') ~ '^[0-9]{1,6}$'
              then (doc ->> 'schemaVersion')::integer end
$$;

revoke all on function private.lock_owned_experience(uuid), private.document_schema_version(jsonb)
  from public, anon, authenticated, service_role;

-- ------------------------------------------------------------ create_experience
create function public.create_experience(p_slug text, p_kind text, p_document jsonb)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_exp uuid := gen_random_uuid();
  v_rev uuid := gen_random_uuid();
  v_sv  integer;
begin
  if v_uid is null or (select private.current_publisher_id()) is null then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  if p_kind is null or p_kind not in ('explainer', 'data-story') then
    raise exception 'invalid kind' using errcode = '22023';
  end if;
  if not private.slug_format_ok(p_slug) or p_slug = any (private.reserved_slugs()) then
    raise exception 'slug is not available' using errcode = '22023';
  end if;
  if p_document is null or pg_catalog.octet_length(p_document::text) > 1048576 then
    raise exception 'document missing or too large' using errcode = '22023';
  end if;
  v_sv := private.document_schema_version(p_document);
  if v_sv is null or not private.document_shape_ok(p_document, v_sv) then
    raise exception 'document failed the shape gate' using errcode = '22023';
  end if;
  if p_document ->> 'slug' <> p_slug or p_document ->> 'kind' <> p_kind then
    raise exception 'document slug and kind must match the experience' using errcode = '22023';
  end if;

  begin
    insert into public.experiences (id, publisher_id, slug, kind, language, title, head_revision_id)
    values (v_exp, v_uid, p_slug, p_kind, p_document ->> 'language', p_document ->> 'title', v_rev);
  exception when unique_violation then
    raise exception 'slug is not available' using errcode = '23505';
  end;
  insert into public.revisions (id, experience_id, seq, parent_id, created_by, schema_version, document)
  values (v_rev, v_exp, 1, null, v_uid, v_sv, p_document);

  perform private.write_audit('publisher', v_uid, 'experience.created', 'experience', v_exp,
    jsonb_build_object('experience_id', v_exp, 'revision_id', v_rev, 'seq', 1));
  return v_exp;
end;
$$;

-- ------------------------------------------------------------ save_revision
create function public.save_revision(
  p_experience_id uuid, p_expected_parent uuid, p_document jsonb,
  p_note text default null, p_restored_from uuid default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid  uuid := (select auth.uid());
  v_exp  public.experiences;
  v_head public.revisions;
  v_doc  jsonb;
  v_sv   integer;
  v_new  uuid := gen_random_uuid();
begin
  v_exp := private.lock_owned_experience(p_experience_id);
  if v_exp.archived_at is not null then
    raise exception 'experience is archived' using errcode = '55000';
  end if;
  if p_expected_parent is distinct from v_exp.head_revision_id then
    raise exception 'edit conflict: the expected parent is not the current head' using errcode = '23505';
  end if;
  if p_note is not null and char_length(p_note) > 280 then
    raise exception 'note too long' using errcode = '22023';
  end if;

  if p_restored_from is not null then
    if p_document is not null then
      raise exception 'a restore takes its document from the source revision' using errcode = '22023';
    end if;
    select r.document into v_doc from public.revisions r
     where r.id = p_restored_from and r.experience_id = p_experience_id;
    if not found then
      raise exception 'restore source not found' using errcode = '22023';
    end if;
  else
    v_doc := p_document;
  end if;
  if v_doc is null or pg_catalog.octet_length(v_doc::text) > 1048576 then
    raise exception 'document missing or too large' using errcode = '22023';
  end if;
  v_sv := private.document_schema_version(v_doc);
  if v_sv is null or not private.document_shape_ok(v_doc, v_sv) then
    raise exception 'document failed the shape gate' using errcode = '22023';
  end if;
  if v_doc ->> 'slug' <> v_exp.slug or v_doc ->> 'kind' <> v_exp.kind then
    raise exception 'document slug and kind must match the experience' using errcode = '22023';
  end if;

  select * into v_head from public.revisions r where r.id = v_exp.head_revision_id;
  insert into public.revisions (id, experience_id, seq, parent_id, created_by, schema_version, document, note, restored_from)
  values (v_new, v_exp.id, v_head.seq + 1, v_head.id, v_uid, v_sv, v_doc, p_note, p_restored_from);

  update public.experiences
     set head_revision_id = v_new, title = v_doc ->> 'title', language = v_doc ->> 'language'
   where id = v_exp.id;

  perform private.write_audit('publisher', v_uid, 'revision.saved', 'revision', v_new,
    jsonb_build_object('experience_id', v_exp.id, 'revision_id', v_new, 'seq', v_head.seq + 1));
  return v_new;
end;
$$;

-- ------------------------------------------------------------ validator functions
-- The validator reads the stored document, runs the full Zod validation outside the database, and
-- attests the result. The database takes the hash from the stored revision: nothing about the
-- content is taken from the caller.
create function public.get_revision_for_validation(p_revision_id uuid)
returns table (revision_id uuid, experience_id uuid, schema_version integer, content_hash text, document jsonb)
language plpgsql security definer stable set search_path = '' as $$
begin
  if not (select private.is_validator()) then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  return query
    select r.id, r.experience_id, r.schema_version, r.content_hash, r.document
      from public.revisions r where r.id = p_revision_id;
end;
$$;

create function public.record_validation(
  p_revision_id uuid, p_passed boolean, p_validator_version text, p_errors jsonb default '[]'::jsonb)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_rev public.revisions;
  v_id  uuid := gen_random_uuid();
begin
  if not (select private.is_validator()) then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  if p_passed is null or p_validator_version is null or p_validator_version !~ '^[A-Za-z0-9._-]{1,40}$' then
    raise exception 'invalid attestation' using errcode = '22023';
  end if;
  if not private.validation_errors_ok(coalesce(p_errors, '[]'::jsonb), p_passed) then
    raise exception 'invalid error list: a pass has none; a failure lists paths and codes only' using errcode = '22023';
  end if;
  select * into v_rev from public.revisions r where r.id = p_revision_id;
  if not found then
    raise exception 'revision not found' using errcode = '22023';
  end if;
  begin
    insert into public.revision_validations (id, revision_id, content_hash, validator_version, passed, errors)
    values (v_id, v_rev.id, v_rev.content_hash, p_validator_version, p_passed, coalesce(p_errors, '[]'::jsonb));
  exception when unique_violation then
    raise exception 'this validator version has already attested this revision' using errcode = '23505';
  end;
  perform private.write_audit('system', null, 'revision.validated', 'revision', v_rev.id,
    jsonb_build_object('experience_id', v_rev.experience_id, 'revision_id', v_rev.id,
                       'validator_version', p_validator_version, 'passed', p_passed));
  return v_id;
end;
$$;

-- ------------------------------------------------------------ approve_revision
create function public.approve_revision(p_revision_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_rev public.revisions;
  v_exp public.experiences;
  v_att record;
begin
  if not (select private.is_human_session()) then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  select * into v_rev from public.revisions r where r.id = p_revision_id;
  if not found then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  v_exp := private.lock_owned_experience(v_rev.experience_id);
  if v_exp.archived_at is not null then
    raise exception 'experience is archived' using errcode = '55000';
  end if;
  if v_exp.held_at is not null then
    raise exception 'experience is held' using errcode = '55000';
  end if;
  if exists (select 1 from public.approvals a where a.revision_id = p_revision_id) then
    raise exception 'revision is already approved' using errcode = '55000';
  end if;
  -- the most recent attestation for this revision must be a pass for exactly this content;
  -- should two ever share a timestamp, the failure wins (fail closed)
  select v.passed, v.content_hash into v_att
    from public.revision_validations v where v.revision_id = p_revision_id
   order by v.checked_at desc, v.passed asc, v.id desc limit 1;
  if not found or v_att.passed is not true or v_att.content_hash <> v_rev.content_hash then
    raise exception 'revision has no passing validation' using errcode = '55000';
  end if;

  insert into public.approvals (revision_id, experience_id, approved_by, content_hash, approved_via)
  values (v_rev.id, v_rev.experience_id, v_uid, v_rev.content_hash, 'human_session');

  perform private.write_audit('publisher', v_uid, 'revision.approved', 'revision', v_rev.id,
    jsonb_build_object('experience_id', v_rev.experience_id, 'revision_id', v_rev.id, 'seq', v_rev.seq));
end;
$$;

-- ------------------------------------------------------------ publish_revision
create function public.publish_revision(p_revision_id uuid)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid  uuid := (select auth.uid());
  v_rev  public.revisions;
  v_exp  public.experiences;
  v_apr  public.approvals;
  v_live public.publications;
  v_pub  uuid := gen_random_uuid();
begin
  if not (select private.is_human_session()) then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  select * into v_rev from public.revisions r where r.id = p_revision_id;
  if not found then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  v_exp := private.lock_owned_experience(v_rev.experience_id);
  if v_exp.archived_at is not null then
    raise exception 'experience is archived' using errcode = '55000';
  end if;
  if v_exp.held_at is not null then
    raise exception 'experience is held' using errcode = '55000';
  end if;
  select * into v_apr from public.approvals a where a.revision_id = p_revision_id;
  if not found or v_apr.content_hash <> v_rev.content_hash then
    raise exception 'revision is not approved' using errcode = '55000';
  end if;

  select * into v_live from public.publications p
   where p.experience_id = v_exp.id and p.unpublished_at is null for update;
  if found then
    if v_live.revision_id = p_revision_id then
      raise exception 'revision is already published' using errcode = '55000';
    end if;
    update public.publications
       set unpublished_at = pg_catalog.now(), unpublished_by_kind = 'publisher', unpublished_by = v_uid,
           unpublish_reason = 'superseded'
     where id = v_live.id;
  end if;

  insert into public.publications (id, experience_id, revision_id, slug_at_publish, published_by)
  values (v_pub, v_exp.id, v_rev.id, v_exp.slug, v_uid);

  update public.experiences set slug_locked_at = coalesce(slug_locked_at, pg_catalog.now()) where id = v_exp.id;

  insert into public.published_experiences
    (experience_id, publication_id, slug, kind, title, summary, language, schema_version, document,
     publisher_id, topic_slugs, published_at)
  values (v_exp.id, v_pub, v_exp.slug, v_exp.kind, v_rev.document ->> 'title', v_rev.document ->> 'summary',
          v_rev.document ->> 'language', v_rev.schema_version, v_rev.document, v_exp.publisher_id,
          coalesce((select array_agg(t.slug order by t.slug)
                      from public.experience_topics et join public.topics t on t.id = et.topic_id
                     where et.experience_id = v_exp.id), '{}'::text[]),
          pg_catalog.now())
  on conflict (experience_id) do update
     set publication_id = excluded.publication_id, kind = excluded.kind, title = excluded.title,
         summary = excluded.summary, language = excluded.language, schema_version = excluded.schema_version,
         document = excluded.document, topic_slugs = excluded.topic_slugs, published_at = excluded.published_at;

  perform private.write_audit('publisher', v_uid, 'publication.published', 'publication', v_pub,
    jsonb_build_object('experience_id', v_exp.id, 'revision_id', v_rev.id, 'publication_id', v_pub));
  return v_pub;
end;
$$;

-- ------------------------------------------------------------ unpublish_experience
create function public.unpublish_experience(p_experience_id uuid, p_note text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid  uuid := (select auth.uid());
  v_exp  public.experiences;
  v_live public.publications;
begin
  if not (select private.is_human_session()) then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  v_exp := private.lock_owned_experience(p_experience_id);
  if p_note is not null and char_length(p_note) > 280 then
    raise exception 'note too long' using errcode = '22023';
  end if;
  select * into v_live from public.publications p
   where p.experience_id = v_exp.id and p.unpublished_at is null for update;
  if not found then
    raise exception 'experience is not published' using errcode = '55000';
  end if;
  update public.publications
     set unpublished_at = pg_catalog.now(), unpublished_by_kind = 'publisher', unpublished_by = v_uid,
         unpublish_reason = 'publisher_request', unpublish_note = p_note
   where id = v_live.id;
  delete from public.published_experiences where experience_id = v_exp.id;
  perform private.write_audit('publisher', v_uid, 'publication.unpublished', 'publication', v_live.id,
    jsonb_build_object('experience_id', v_exp.id, 'publication_id', v_live.id, 'reason_code', 'publisher_request'));
end;
$$;

-- ------------------------------------------------------------ admin_takedown and holds
-- Administrators act on publication metadata and holds only; no function here returns document content.
create function public.admin_takedown(p_experience_id uuid, p_reason_code text, p_note text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid  uuid := (select auth.uid());
  v_exp  public.experiences;
  v_live public.publications;
begin
  if not (select private.is_admin()) then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  if p_reason_code is null or p_reason_code not in ('policy', 'legal', 'safety', 'error') then
    raise exception 'invalid reason code' using errcode = '22023';
  end if;
  if p_note is null or char_length(btrim(p_note)) not between 1 and 280 then
    raise exception 'a note of 1 to 280 characters is required' using errcode = '22023';
  end if;
  select * into v_exp from public.experiences e where e.id = p_experience_id for update;
  if not found then
    raise exception 'unknown experience' using errcode = '22023';
  end if;
  select * into v_live from public.publications p
   where p.experience_id = v_exp.id and p.unpublished_at is null for update;
  if not found then
    raise exception 'experience is not published' using errcode = '55000';
  end if;
  update public.publications
     set unpublished_at = pg_catalog.now(), unpublished_by_kind = 'admin', unpublished_by = v_uid,
         unpublish_reason = p_reason_code, unpublish_note = p_note
   where id = v_live.id;
  delete from public.published_experiences where experience_id = v_exp.id;
  update public.experiences set held_at = pg_catalog.now(), held_reason = p_note where id = v_exp.id;
  perform private.write_audit('admin', v_uid, 'publication.taken_down', 'publication', v_live.id,
    jsonb_build_object('experience_id', v_exp.id, 'publication_id', v_live.id, 'reason_code', p_reason_code));
end;
$$;

create function public.set_experience_hold(p_experience_id uuid, p_held boolean, p_note text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_exp public.experiences;
begin
  if not (select private.is_admin()) then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  if p_held is null then
    raise exception 'p_held is required' using errcode = '22023';
  end if;
  if p_held and (p_note is null or char_length(btrim(p_note)) not between 1 and 280) then
    raise exception 'a note of 1 to 280 characters is required to set a hold' using errcode = '22023';
  end if;
  select * into v_exp from public.experiences e where e.id = p_experience_id for update;
  if not found then
    raise exception 'unknown experience' using errcode = '22023';
  end if;
  if (v_exp.held_at is not null) = p_held then
    raise exception 'the hold is already in that state' using errcode = '55000';
  end if;
  if p_held and exists (select 1 from public.publications p where p.experience_id = v_exp.id and p.unpublished_at is null) then
    raise exception 'use admin_takedown for a published experience' using errcode = '55000';
  end if;
  update public.experiences
     set held_at = case when p_held then pg_catalog.now() end,
         held_reason = case when p_held then p_note end
   where id = v_exp.id;
  perform private.write_audit('admin', v_uid, case when p_held then 'experience.held' else 'experience.released' end,
    'experience', v_exp.id, jsonb_build_object('experience_id', v_exp.id, 'held', p_held));
end;
$$;

-- ------------------------------------------------------------ grants
revoke all on function
  public.create_experience(text, text, jsonb),
  public.save_revision(uuid, uuid, jsonb, text, uuid),
  public.get_revision_for_validation(uuid),
  public.record_validation(uuid, boolean, text, jsonb),
  public.approve_revision(uuid),
  public.publish_revision(uuid),
  public.unpublish_experience(uuid, text),
  public.admin_takedown(uuid, text, text),
  public.set_experience_hold(uuid, boolean, text)
  from public, anon, authenticated, service_role, validator_service, ai_service;

grant execute on function
  public.create_experience(text, text, jsonb),
  public.save_revision(uuid, uuid, jsonb, text, uuid),
  public.approve_revision(uuid),
  public.publish_revision(uuid),
  public.unpublish_experience(uuid, text),
  public.admin_takedown(uuid, text, text),
  public.set_experience_hold(uuid, boolean, text)
  to authenticated;

grant execute on function
  public.get_revision_for_validation(uuid),
  public.record_validation(uuid, boolean, text, jsonb)
  to validator_service;
