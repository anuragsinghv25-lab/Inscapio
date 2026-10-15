-- Stage 3.1 / migration 2: identity tables. Grants, RLS and policies follow in migration 3.
-- Deviations from the Phase 0 / Stage 3 design docs are listed in
-- docs/architecture/stage-3-implementation-plan.md ("3.1 reconciliation").

-- Administrators: a separate capability record, not a flag on publishers.
create table public.admins (
  user_id    uuid primary key references auth.users (id) on delete restrict,
  status     text not null default 'active' check (status in ('active', 'removed')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict, -- null for the bootstrap row
  removed_at timestamptz,
  constraint admins_removed_consistent check ((status = 'removed') = (removed_at is not null))
);

-- Publishers: created ONLY by redeem_invite(). No email column (email stays in auth.users).
create table public.publishers (
  id                uuid primary key references auth.users (id) on delete restrict,
  handle            text unique,
  display_name      text,
  bio               text,
  status            text not null default 'active' check (status in ('active', 'suspended', 'revoked')),
  status_reason     text,
  status_changed_at timestamptz,
  status_changed_by uuid references auth.users (id) on delete restrict,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint publishers_handle_format check (handle is null or handle ~ '^[a-z0-9][a-z0-9-]{2,29}$'),
  constraint publishers_handle_reserved check (
    handle is null or handle not in
      ('admin', 'studio', 'api', 'auth', 'legal', 'about', 'experiences', 'topics', 'publishers', 'inscapio', 'support')),
  constraint publishers_display_name_len check (display_name is null or char_length(display_name) between 1 and 80),
  constraint publishers_bio_len check (bio is null or char_length(bio) <= 600),
  constraint publishers_reason_len check (status_reason is null or char_length(status_reason) between 1 and 280)
);
create index publishers_status_idx on public.publishers (status);

-- A handle is chosen once (after redemption) and then fixed; id never changes.
create function private.publishers_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id then
    raise exception 'publishers.id is immutable' using errcode = '55000';
  end if;
  if old.handle is not null and new.handle is distinct from old.handle then
    raise exception 'publishers.handle is set once' using errcode = '55000';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.publishers_before_update() from public, anon, authenticated, service_role;
create trigger publishers_before_update
  before update on public.publishers
  for each row execute function private.publishers_before_update();

-- Invitations: an email-bound authorisation record. There is deliberately NO token column.
create table public.invites (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  status      text not null default 'pending' check (status in ('pending', 'redeemed', 'revoked', 'expired')),
  created_by  uuid not null references public.admins (user_id) on delete restrict,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  redeemed_by uuid references auth.users (id) on delete restrict,
  redeemed_at timestamptz,
  revoked_by  uuid references public.admins (user_id) on delete restrict,
  revoked_at  timestamptz,
  constraint invites_email_normalised check (
    email = lower(btrim(email)) and char_length(email) <= 254 and email ~ '^[^@[:space:]]+@[^@[:space:]]+$'),
  constraint invites_expiry_window check (
    expires_at > created_at and expires_at <= created_at + interval '30 days'),
  constraint invites_redeemed_consistent check (
    (status = 'redeemed' and redeemed_by is not null and redeemed_at is not null)
    or (status <> 'redeemed' and redeemed_by is null and redeemed_at is null)),
  constraint invites_revoked_consistent check (
    (status = 'revoked' and revoked_by is not null and revoked_at is not null)
    or (status <> 'revoked' and revoked_by is null and revoked_at is null))
);
-- At most one pending invitation per email.
create unique index invites_one_pending_per_email on public.invites (email) where status = 'pending';
create index invites_status_expires_idx on public.invites (status, expires_at);

-- Audit details may only carry codes and ids from this allow-list: never email, never content.
create function private.audit_details_ok(d jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(d) = 'object'
     and not exists (
       select 1 from jsonb_object_keys(d) as k
       where k not in ('invite_id', 'ttl_days', 'from', 'to'));
$$;
revoke all on function private.audit_details_ok(jsonb) from public, anon, authenticated, service_role;

create table public.audit_events (
  id           uuid primary key default gen_random_uuid(),
  at           timestamptz not null default now(),
  actor_kind   text not null check (actor_kind in ('publisher', 'admin', 'ai', 'system', 'anonymous')),
  actor_id     uuid, -- deliberately no FK: the record must outlive the account
  action       text not null check (action ~ '^[a-z_]+\.[a-z_]+$' and char_length(action) <= 60),
  subject_type text not null check (subject_type ~ '^[a-z_]+$'),
  subject_id   uuid,
  details      jsonb not null default '{}'::jsonb check (private.audit_details_ok(details)),
  request_id   text,
  aal          text
);
create index audit_events_at_idx on public.audit_events (at desc);
create index audit_events_subject_idx on public.audit_events (subject_type, subject_id, at desc);
create index audit_events_actor_idx on public.audit_events (actor_id, at desc);

create trigger audit_events_append_only
  before update or delete on public.audit_events
  for each row execute function private.forbid_modification();
create trigger audit_events_no_truncate
  before truncate on public.audit_events
  for each statement execute function private.forbid_modification();
