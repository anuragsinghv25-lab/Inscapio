-- Stage 3.1 / migration 4: audit writer, invitation and publisher-status functions,
-- and the owner-only administrator bootstrap procedure.
-- Every function: SECURITY DEFINER, empty search_path, schema-qualified names, EXECUTE revoked
-- from PUBLIC and granted to named roles only. Identity always comes from auth.uid(),
-- never from an argument. Errors: 42501 denied, 22023 invalid argument, 55000 state refusal.

create function private.write_audit(
  p_actor_kind text, p_actor_id uuid, p_action text,
  p_subject_type text, p_subject_id uuid, p_details jsonb default '{}'::jsonb)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_events (actor_kind, actor_id, action, subject_type, subject_id, details, aal)
  values (p_actor_kind, p_actor_id, p_action, p_subject_type, p_subject_id,
          coalesce(p_details, '{}'::jsonb), (select auth.jwt()) ->> 'aal');
$$;
revoke all on function private.write_audit(text, uuid, text, text, uuid, jsonb)
  from public, anon, authenticated, service_role;

-- ------------------------------------------------------------ create_invite
create function public.create_invite(p_email text, p_ttl_days integer default 7)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := (select auth.uid());
  v_email text;
  v_id    uuid;
begin
  if not (select private.is_admin()) then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  if p_ttl_days is null or p_ttl_days < 1 or p_ttl_days > 30 then
    raise exception 'ttl must be between 1 and 30 days' using errcode = '22023';
  end if;
  v_email := lower(btrim(coalesce(p_email, '')));
  if char_length(v_email) > 254 or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+$' then
    raise exception 'invalid email' using errcode = '22023';
  end if;

  -- Serialise concurrent invitations for the same email.
  perform pg_advisory_xact_lock(hashtextextended(v_email, 0));

  if exists (
    select 1
    from auth.users u
    join public.publishers p on p.id = u.id
    where lower(u.email) = v_email) then
    raise exception 'email already belongs to a publisher' using errcode = '23505';
  end if;

  -- A lapsed pending invitation must not block a fresh one.
  update public.invites
     set status = 'expired'
   where email = v_email and status = 'pending' and expires_at <= now();

  insert into public.invites (email, created_by, expires_at)
  values (v_email, v_admin, now() + make_interval(days => p_ttl_days))
  returning id into v_id; -- a live pending invitation raises 23505 (partial unique index)

  perform private.write_audit('admin', v_admin, 'invite.created', 'invite', v_id,
                              jsonb_build_object('invite_id', v_id, 'ttl_days', p_ttl_days));
  return v_id;
end;
$$;

-- ------------------------------------------------------------ revoke_invite
create function public.revoke_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := (select auth.uid());
  v_inv   public.invites;
begin
  if not (select private.is_admin()) then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  select * into v_inv from public.invites where id = p_invite_id for update;
  if not found or v_inv.status <> 'pending' then
    raise exception 'invite is not pending' using errcode = '55000';
  end if;
  update public.invites
     set status = 'revoked', revoked_by = v_admin, revoked_at = now()
   where id = p_invite_id;
  perform private.write_audit('admin', v_admin, 'invite.revoked', 'invite', p_invite_id,
                              jsonb_build_object('invite_id', p_invite_id));
end;
$$;

-- ------------------------------------------------------------ redeem_invite
-- Takes NO arguments: the caller's uid and email come from the database, so a client can
-- neither choose whose invitation to redeem nor supply a role. Requires BOTH a verified email
-- (auth.users.email_confirmed_at) and a pending, unexpired invitation for that same email.
-- One statement = one transaction: any refusal leaves no partial record.
create function public.redeem_invite()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_email text;
  v_inv   public.invites;
begin
  if v_uid is null then
    raise exception 'not authorised' using errcode = '42501';
  end if;

  select lower(btrim(u.email)) into v_email
  from auth.users u
  where u.id = v_uid and u.email_confirmed_at is not null;
  if v_email is null or v_email = '' then
    raise exception 'invite not redeemable' using errcode = '55000';
  end if;

  -- An existing publisher row (any status) is never re-created or re-activated here.
  if exists (select 1 from public.publishers where id = v_uid) then
    raise exception 'invite not redeemable' using errcode = '55000';
  end if;

  -- Row lock: a concurrent second redemption waits, then finds no pending row.
  select * into v_inv
  from public.invites
  where email = v_email and status = 'pending'
  for update;
  if not found or v_inv.expires_at <= now() then
    raise exception 'invite not redeemable' using errcode = '55000';
  end if;

  insert into public.publishers (id) values (v_uid);
  update public.invites
     set status = 'redeemed', redeemed_by = v_uid, redeemed_at = now()
   where id = v_inv.id;
  perform private.write_audit('publisher', v_uid, 'invite.redeemed', 'invite', v_inv.id,
                              jsonb_build_object('invite_id', v_inv.id));
  return v_uid;
end;
$$;

-- ------------------------------------------------------ set_publisher_status
create function public.set_publisher_status(p_publisher_id uuid, p_status text, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin  uuid := (select auth.uid());
  v_old    text;
  v_action text;
begin
  if not (select private.is_admin()) then
    raise exception 'not authorised' using errcode = '42501';
  end if;
  if p_status is null or p_status not in ('active', 'suspended', 'revoked') then
    raise exception 'invalid status' using errcode = '22023';
  end if;
  if p_reason is null or char_length(btrim(p_reason)) not between 1 and 280 then
    raise exception 'a reason of 1 to 280 characters is required' using errcode = '22023';
  end if;

  select status into v_old from public.publishers where id = p_publisher_id for update;
  if not found then
    raise exception 'publisher not found' using errcode = '55000';
  end if;
  if v_old = p_status then
    raise exception 'status unchanged' using errcode = '55000';
  end if;

  update public.publishers
     set status = p_status, status_reason = btrim(p_reason),
         status_changed_at = now(), status_changed_by = v_admin
   where id = p_publisher_id;

  v_action := case p_status
                when 'suspended' then 'publisher.suspended'
                when 'revoked'   then 'publisher.revoked'
                else 'publisher.reinstated' end;
  perform private.write_audit('admin', v_admin, v_action, 'publisher', p_publisher_id,
                              jsonb_build_object('from', v_old, 'to', p_status));
end;
$$;

-- ------------------------------------------------- administrator bootstrap
-- Owner-only. See docs/runbooks/bootstrap-first-admin.md. Not reachable through the API.
create function private.bootstrap_admin(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.admins (user_id, status) values (p_user_id, 'active')
  on conflict (user_id) do update set status = 'active', removed_at = null;
  perform private.write_audit('system', null, 'admin.bootstrapped', 'admin', p_user_id, '{}'::jsonb);
end;
$$;

create function private.remove_admin(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.admins set status = 'removed', removed_at = now()
   where user_id = p_user_id and status = 'active';
  if not found then
    raise exception 'no active administrator with that id' using errcode = '55000';
  end if;
  perform private.write_audit('system', null, 'admin.removed', 'admin', p_user_id, '{}'::jsonb);
end;
$$;

-- ------------------------------------------------------------- grants
revoke all on function public.create_invite(text, integer) from public, anon, authenticated, service_role;
revoke all on function public.revoke_invite(uuid) from public, anon, authenticated, service_role;
revoke all on function public.redeem_invite() from public, anon, authenticated, service_role;
revoke all on function public.set_publisher_status(uuid, text, text) from public, anon, authenticated, service_role;
revoke all on function private.bootstrap_admin(uuid) from public, anon, authenticated, service_role;
revoke all on function private.remove_admin(uuid) from public, anon, authenticated, service_role;

grant execute on function public.create_invite(text, integer) to authenticated;
grant execute on function public.revoke_invite(uuid) to authenticated;
grant execute on function public.redeem_invite() to authenticated;
grant execute on function public.set_publisher_status(uuid, text, text) to authenticated;
