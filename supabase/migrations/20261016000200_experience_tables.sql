-- Stage 3.2 / migration 2: the experience core tables, constraints, immutability guards and the
-- structural "shape gate". Grants and RLS follow in migration 3; no table is reachable by an API role
-- until then because 3.1's default-privilege revocation applies to everything created here.
-- The shape gate is a cheap structural check. It is NOT the full Zod validation, which is attested
-- separately through revision_validations.

-- ------------------------------------------------------------------ constants (kept in step with
-- src/content/schema by tests/unit/shape-gate-drift.test.ts)
create function private.known_block_types() returns text[]
language sql immutable set search_path = '' as $$
  select array['paragraph', 'callout', 'card', 'fact-row', 'compare-table', 'resource-box', 'source-list',
               'data-note', 'deeper', 'accordion', 'stepper', 'claims', 'classify', 'selector-content',
               'scrubber-chart']::text[]
$$;

create function private.known_endnote_types() returns text[]
language sql immutable set search_path = '' as $$
  select array['paragraph', 'source-list', 'data-note']::text[]
$$;

-- Only schema versions the application can render may be stored. Add a version here in the same
-- change that teaches the renderer and the validator about it.
create function private.supported_schema_versions() returns integer[]
language sql immutable set search_path = '' as $$
  select array[1]::integer[]
$$;

create function private.known_document_keys() returns text[]
language sql immutable set search_path = '' as $$
  select array['schemaVersion', 'id', 'slug', 'kind', 'title', 'shortTitle', 'language', 'summary', 'theme',
               'reading', 'hero', 'sections', 'sources', 'datasets', 'endnotes']::text[]
$$;

-- Slugs that must never be claimed by a publisher: the two existing file-based experiences (until
-- they are imported) and words that are, or may become, application routes. A proposal for owner review.
create function private.reserved_slugs() returns text[]
language sql immutable set search_path = '' as $$
  select array['climate', 'whose-body-is-it',
               'about', 'admin', 'api', 'app', 'assets', 'auth', 'callback', 'edit', 'experiences', 'favicon',
               'feedback', 'health', 'help', 'home', 'login', 'logout', 'new', 'null', 'preview', 'privacy',
               'public', 'robots', 'search', 'settings', 'sign-in', 'sign-out', 'sitemap', 'static', 'status',
               'studio', 'terms', 'topic', 'topics', 'undefined', 'user', 'users']::text[]
$$;

create function private.slug_format_ok(p_slug text) returns boolean
language sql immutable set search_path = '' as $$
  select p_slug is not null and char_length(p_slug) between 3 and 60 and p_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
$$;

create function private.document_shape_ok(doc jsonb, p_schema_version integer) returns boolean
language plpgsql immutable set search_path = '' as $$
declare
  k text;
  s jsonb;
  b jsonb;
begin
  if doc is null or jsonb_typeof(doc) <> 'object' then return false; end if;
  if jsonb_typeof(doc -> 'schemaVersion') <> 'number' or doc -> 'schemaVersion' <> to_jsonb(p_schema_version)
     or p_schema_version <> all (private.supported_schema_versions()) then
    return false;
  end if;
  for k in select jsonb_object_keys(doc) loop
    if k <> all (private.known_document_keys()) then return false; end if;
  end loop;
  foreach k in array array['id', 'slug', 'kind', 'title', 'language', 'summary'] loop
    if jsonb_typeof(doc -> k) <> 'string' then return false; end if;
  end loop;
  if (doc ->> 'kind') not in ('explainer', 'data-story') then return false; end if;
  if not private.slug_format_ok(doc ->> 'slug') then return false; end if;
  if char_length(doc ->> 'title') not between 1 and 200 then return false; end if;
  if char_length(doc ->> 'summary') not between 1 and 1200 then return false; end if;
  if (doc ->> 'language') !~ '^[a-z]{2}(-[A-Z]{2})?$' then return false; end if;

  if jsonb_typeof(doc -> 'sections') <> 'array' or jsonb_array_length(doc -> 'sections') not between 1 and 40 then
    return false;
  end if;
  for s in select jsonb_array_elements(doc -> 'sections') loop
    if jsonb_typeof(s) <> 'object' or jsonb_typeof(s -> 'blocks') <> 'array'
       or jsonb_array_length(s -> 'blocks') not between 1 and 40 then
      return false;
    end if;
    for b in select jsonb_array_elements(s -> 'blocks') loop
      if jsonb_typeof(b) <> 'object' or jsonb_typeof(b -> 'type') <> 'string'
         or (b ->> 'type') <> all (private.known_block_types()) then
        return false;
      end if;
    end loop;
  end loop;

  if doc ? 'endnotes' then
    if jsonb_typeof(doc -> 'endnotes') <> 'array' or jsonb_array_length(doc -> 'endnotes') > 10 then return false; end if;
    for b in select jsonb_array_elements(doc -> 'endnotes') loop
      if jsonb_typeof(b) <> 'object' or jsonb_typeof(b -> 'type') <> 'string'
         or (b ->> 'type') <> all (private.known_endnote_types()) then
        return false;
      end if;
    end loop;
  end if;
  return true;
exception when others then
  return false;
end;
$$;

-- Validation errors carry paths and codes only, never document content.
create function private.validation_errors_ok(errs jsonb, p_passed boolean) returns boolean
language plpgsql immutable set search_path = '' as $$
declare e jsonb; k text;
begin
  if errs is null or jsonb_typeof(errs) <> 'array' or pg_catalog.octet_length(errs::text) > 8192 then return false; end if;
  if p_passed then return jsonb_array_length(errs) = 0; end if;
  if jsonb_array_length(errs) not between 1 and 50 then return false; end if;
  for e in select jsonb_array_elements(errs) loop
    if jsonb_typeof(e) <> 'object' then return false; end if;
    for k in select jsonb_object_keys(e) loop
      if k not in ('path', 'code') then return false; end if;
    end loop;
    if jsonb_typeof(e -> 'path') <> 'string' or char_length(e ->> 'path') > 200 then return false; end if;
    if jsonb_typeof(e -> 'code') <> 'string' or char_length(e ->> 'code') > 64 then return false; end if;
  end loop;
  return true;
exception when others then
  return false;
end;
$$;

revoke all on function private.known_block_types(), private.known_endnote_types(), private.supported_schema_versions(),
  private.known_document_keys(), private.reserved_slugs(), private.slug_format_ok(text),
  private.document_shape_ok(jsonb, integer), private.validation_errors_ok(jsonb, boolean)
  from public, anon, authenticated, service_role;

create function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;
revoke all on function private.touch_updated_at() from public, anon, authenticated, service_role;

-- ------------------------------------------------------------------ topics
create table public.topics (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  title       text not null,
  description text,
  position    integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  -- inline, not private.slug_format_ok(): CHECKs run with the writing role's privileges, and that role must
  -- not need EXECUTE on any private function
  constraint topics_slug_format check (char_length(slug) between 3 and 60 and slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint topics_title_len   check (char_length(title) between 1 and 80),
  constraint topics_desc_len    check (description is null or char_length(description) <= 280)
);
create trigger topics_touch before update on public.topics
  for each row execute function private.touch_updated_at();

-- Administrator writes to topics are direct DML (RLS: is_admin), so the audit row is written by trigger,
-- in the same transaction.
create function private.topics_audit() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_id  uuid := coalesce(new.id, old.id);
begin
  perform private.write_audit(case when v_uid is null then 'system' else 'admin' end, v_uid,
    case tg_op when 'INSERT' then 'topic.created' when 'UPDATE' then 'topic.updated' else 'topic.deleted' end,
    'topic', v_id, jsonb_build_object('topic_id', v_id));
  return null;
end;
$$;
revoke all on function private.topics_audit() from public, anon, authenticated, service_role;
create trigger topics_audit after insert or update or delete on public.topics
  for each row execute function private.topics_audit();

-- ------------------------------------------------------------------ experiences
create table public.experiences (
  id               uuid primary key default gen_random_uuid(),
  publisher_id     uuid not null references public.publishers (id) on delete restrict,
  slug             text not null unique,
  kind             text not null check (kind in ('explainer', 'data-story')),
  language         text not null check (language ~ '^[a-z]{2}(-[A-Z]{2})?$'),
  title            text not null check (char_length(title) between 1 and 200),
  head_revision_id uuid,
  slug_locked_at   timestamptz,
  held_at          timestamptz,
  held_reason      text,
  archived_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint experiences_slug_format check (char_length(slug) between 3 and 60 and slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint experiences_hold_consistent check ((held_at is null) = (held_reason is null)),
  constraint experiences_hold_reason_len check (held_reason is null or char_length(held_reason) between 1 and 280)
);
create index experiences_publisher_updated_idx on public.experiences (publisher_id, updated_at desc);

-- ------------------------------------------------------------------ revisions (append-only)
create table public.revisions (
  id             uuid primary key default gen_random_uuid(),
  experience_id  uuid not null references public.experiences (id) on delete restrict,
  seq            integer not null check (seq >= 1),
  parent_id      uuid,
  author_kind    text not null default 'human' check (author_kind in ('human', 'ai')),
  created_by     uuid not null references public.publishers (id) on delete restrict,
  schema_version integer not null check (schema_version >= 1),
  document       jsonb not null,
  content_hash   text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  note           text check (note is null or char_length(note) <= 280),
  restored_from  uuid,
  created_at     timestamptz not null default now(),
  constraint revisions_experience_seq_key unique (experience_id, seq),
  constraint revisions_id_experience_key  unique (id, experience_id),
  constraint revisions_id_hash_key        unique (id, content_hash),
  constraint revisions_parent_fk   foreign key (parent_id, experience_id) references public.revisions (id, experience_id),
  constraint revisions_restored_fk foreign key (restored_from, experience_id) references public.revisions (id, experience_id),
  constraint revisions_parent_seq check ((seq = 1) = (parent_id is null)),
  constraint revisions_document_object check (jsonb_typeof(document) = 'object'),
  constraint revisions_document_size check (pg_catalog.octet_length(document::text) <= 1048576),
  constraint revisions_shape_gate check (private.document_shape_ok(document, schema_version))
);
create index revisions_experience_seq_idx on public.revisions (experience_id, seq desc);
create index revisions_content_hash_idx on public.revisions (content_hash);

-- The hash is always computed here, from the stored document: a caller-supplied value is overwritten.
create function private.revisions_before_insert() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.content_hash := pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(new.document::text, 'UTF8')), 'hex');
  return new;
end;
$$;
revoke all on function private.revisions_before_insert() from public, anon, authenticated, service_role;
create trigger revisions_hash before insert on public.revisions
  for each row execute function private.revisions_before_insert();
create trigger revisions_append_only before update or delete on public.revisions
  for each row execute function private.forbid_modification();
create trigger revisions_no_truncate before truncate on public.revisions
  for each statement execute function private.forbid_modification();

-- head pointer: deferrable to break the creation cycle; composite so the head always belongs to this experience
alter table public.experiences
  add constraint experiences_head_fk foreign key (head_revision_id, id)
  references public.revisions (id, experience_id) deferrable initially deferred;
create index experiences_head_idx on public.experiences (head_revision_id);

create function private.experiences_before_update() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.id <> old.id or new.publisher_id <> old.publisher_id or new.kind <> old.kind then
    raise exception 'id, owner and kind are immutable' using errcode = '55000';
  end if;
  if new.slug is distinct from old.slug and old.slug_locked_at is not null then
    raise exception 'the slug is locked after first publication' using errcode = '55000';
  end if;
  if old.slug_locked_at is not null and new.slug_locked_at is distinct from old.slug_locked_at then
    raise exception 'slug_locked_at cannot change once set' using errcode = '55000';
  end if;
  if new.archived_at is not null and old.archived_at is null
     and exists (select 1 from public.publications p where p.experience_id = old.id and p.unpublished_at is null) then
    raise exception 'a published experience cannot be archived; unpublish it first' using errcode = '55000';
  end if;
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;
revoke all on function private.experiences_before_update() from public, anon, authenticated, service_role;
create trigger experiences_guard before update on public.experiences
  for each row execute function private.experiences_before_update();

-- ------------------------------------------------------------------ experience_topics
create table public.experience_topics (
  experience_id uuid not null references public.experiences (id) on delete restrict,
  topic_id      uuid not null references public.topics (id) on delete restrict,
  primary key (experience_id, topic_id)
);
create index experience_topics_topic_idx on public.experience_topics (topic_id);

-- ------------------------------------------------------------------ revision_validations (append-only)
create table public.revision_validations (
  id                uuid primary key default gen_random_uuid(),
  revision_id       uuid not null,
  content_hash      text not null,
  validator_version text not null check (validator_version ~ '^[A-Za-z0-9._-]{1,40}$'),
  passed            boolean not null,
  errors            jsonb not null default '[]'::jsonb,
  -- clock_timestamp(), not now(): attestations in one transaction must still be ordered
  checked_at        timestamptz not null default clock_timestamp(),
  constraint revision_validations_revision_version_key unique (revision_id, validator_version),
  -- the attestation names the exact content it covers
  constraint revision_validations_revision_fk foreign key (revision_id, content_hash)
    references public.revisions (id, content_hash) on delete restrict,
  constraint revision_validations_errors_ok check (private.validation_errors_ok(errors, passed))
);
create index revision_validations_revision_idx on public.revision_validations (revision_id, checked_at desc);
create trigger revision_validations_append_only before update or delete on public.revision_validations
  for each row execute function private.forbid_modification();
create trigger revision_validations_no_truncate before truncate on public.revision_validations
  for each statement execute function private.forbid_modification();

-- ------------------------------------------------------------------ approvals (append-only)
create table public.approvals (
  revision_id   uuid primary key,
  experience_id uuid not null,
  approved_by   uuid not null references public.publishers (id) on delete restrict,
  approved_at   timestamptz not null default now(),
  content_hash  text not null,
  approved_via  text not null default 'human_session' check (approved_via = 'human_session'),
  note          text check (note is null or char_length(note) <= 280),
  constraint approvals_revision_experience_key unique (revision_id, experience_id),
  constraint approvals_revision_experience_fk foreign key (revision_id, experience_id)
    references public.revisions (id, experience_id) on delete restrict,
  -- the approval is bound to the exact content
  constraint approvals_revision_hash_fk foreign key (revision_id, content_hash)
    references public.revisions (id, content_hash) on delete restrict
);
create index approvals_experience_idx on public.approvals (experience_id, approved_at desc);
create trigger approvals_append_only before update or delete on public.approvals
  for each row execute function private.forbid_modification();
create trigger approvals_no_truncate before truncate on public.approvals
  for each statement execute function private.forbid_modification();

-- ------------------------------------------------------------------ publications
create table public.publications (
  id                  uuid primary key default gen_random_uuid(),
  experience_id       uuid not null references public.experiences (id) on delete restrict,
  revision_id         uuid not null,
  slug_at_publish     text not null,
  published_at        timestamptz not null default now(),
  published_by        uuid not null references public.publishers (id) on delete restrict,
  unpublished_at      timestamptz,
  unpublished_by_kind text check (unpublished_by_kind in ('publisher', 'admin', 'system')),
  unpublished_by      uuid,
  unpublish_reason    text check (unpublish_reason in
                        ('publisher_request', 'superseded', 'policy', 'legal', 'safety', 'error')),
  unpublish_note      text check (unpublish_note is null or char_length(unpublish_note) <= 280),
  -- a publication cannot exist without an approval of this revision of this experience
  constraint publications_approval_fk foreign key (revision_id, experience_id)
    references public.approvals (revision_id, experience_id) on delete restrict,
  constraint publications_unpublish_consistent check (
    (unpublished_at is null and unpublished_by_kind is null and unpublish_reason is null
       and unpublished_by is null and unpublish_note is null)
    or (unpublished_at is not null and unpublished_by_kind is not null and unpublish_reason is not null))
);
create unique index publications_one_live_per_experience on public.publications (experience_id)
  where unpublished_at is null;
create index publications_experience_idx on public.publications (experience_id, published_at desc);
create index publications_revision_idx on public.publications (revision_id);

-- Only the unpublish columns may change, and only once; a publication is never deleted.
create function private.publications_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.unpublished_at is not null then
    raise exception 'a closed publication cannot change' using errcode = '55000';
  end if;
  if new.id is distinct from old.id or new.experience_id is distinct from old.experience_id
     or new.revision_id is distinct from old.revision_id or new.slug_at_publish is distinct from old.slug_at_publish
     or new.published_at is distinct from old.published_at or new.published_by is distinct from old.published_by then
    raise exception 'only the unpublish columns of a publication may change' using errcode = '55000';
  end if;
  if new.unpublished_at is null then
    raise exception 'an update must close the publication' using errcode = '55000';
  end if;
  return new;
end;
$$;
revoke all on function private.publications_guard() from public, anon, authenticated, service_role;
create trigger publications_update_guard before update on public.publications
  for each row execute function private.publications_guard();
create trigger publications_no_delete before delete on public.publications
  for each row execute function private.forbid_modification();
create trigger publications_no_truncate before truncate on public.publications
  for each statement execute function private.forbid_modification();

-- ------------------------------------------------------------------ published_experiences (public projection)
create table public.published_experiences (
  experience_id  uuid primary key references public.experiences (id) on delete restrict,
  publication_id uuid not null unique references public.publications (id) on delete restrict,
  slug           text not null unique,
  kind           text not null check (kind in ('explainer', 'data-story')),
  title          text not null,
  summary        text not null,
  language       text not null,
  schema_version integer not null,
  document       jsonb not null,
  publisher_id   uuid not null references public.publishers (id) on delete restrict,
  topic_slugs    text[] not null default '{}',
  published_at   timestamptz not null default now(),
  constraint published_experiences_slug_format check (char_length(slug) between 3 and 60 and slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint published_experiences_shape_gate check (private.document_shape_ok(document, schema_version))
);
create index published_experiences_published_idx on public.published_experiences (published_at desc);
create index published_experiences_topics_idx on public.published_experiences using gin (topic_slugs);
