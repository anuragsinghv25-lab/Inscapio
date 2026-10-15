#!/usr/bin/env bash
# T-I07: two simultaneous redemptions by the same verified user produce exactly one publisher,
# one redeemed invitation and one audit event. Runs against the LOCAL Supabase database only.
# Two real database sessions are needed, so this cannot live inside a single pgTAP transaction.
# Usage: DB_URL=postgresql://... supabase/tests/concurrency/redeem-invite-race.sh
# (DB_URL comes from `supabase status -o env`; nothing is stored in the repository.)
set -euo pipefail
: "${DB_URL:?DB_URL must point at the LOCAL Supabase database (from supabase status -o env)}"
case "$DB_URL" in
  *127.0.0.1*|*localhost*) ;;
  *) echo "refusing to run: DB_URL is not a local address" >&2; exit 2 ;;
esac

# Unique synthetic data per run, so the script is repeatable against a persistent local stack.
newid() { cat /proc/sys/kernel/random/uuid; }
RUN=$(newid | cut -c1-8)
ADMIN=$(newid)
USER_ID=$(newid)
EMAIL="race-user-$RUN@example.test"
tmp_a=$(mktemp); tmp_b=$(mktemp)
q() { psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -At "$@"; }

audit_before=$(q -c "select count(*) from public.audit_events")
q <<SQL
insert into auth.users (id, email, email_confirmed_at, aud, role) values
  ('$ADMIN', 'race-admin-$RUN@example.test', now(), 'authenticated', 'authenticated'),
  ('$USER_ID', '$EMAIL', now(), 'authenticated', 'authenticated');
select private.bootstrap_admin('$ADMIN');
insert into public.invites (email, created_by, expires_at)
  values ('$EMAIL', '$ADMIN', now() + interval '1 day');
SQL

claims="{\"sub\":\"$USER_ID\",\"role\":\"authenticated\",\"aal\":\"aal1\"}"

# Session A holds the invitation row lock for 3 seconds before committing.
( psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -At <<SQL
begin;
select set_config('request.jwt.claims', '$claims', true);
set local role authenticated;
select public.redeem_invite();
select pg_sleep(3);
commit;
SQL
) > "$tmp_a" 2>&1 &
pid_a=$!
sleep 1
# Session B starts while A holds the lock; it must wait, then be refused.
set +e
psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -At > "$tmp_b" 2>&1 <<SQL
begin;
select set_config('request.jwt.claims', '$claims', true);
set local role authenticated;
select public.redeem_invite();
commit;
SQL
status_b=$?
wait "$pid_a"; status_a=$?
set -e

fail=0
[ "$status_a" -eq 0 ] || { echo "FAIL: first redemption should succeed (exit $status_a)"; cat "$tmp_a"; fail=1; }
[ "$status_b" -ne 0 ] || { echo "FAIL: concurrent second redemption should be refused"; fail=1; }
grep -q "invite not redeemable" "$tmp_b" || { echo "FAIL: second redemption did not fail with the expected refusal"; cat "$tmp_b"; fail=1; }

pubs=$(q -c "select count(*) from public.publishers where id = '$USER_ID'")
redeemed=$(q -c "select count(*) from public.invites where email = '$EMAIL' and status = 'redeemed'")
events=$(q -c "select count(*) from public.audit_events where action = 'invite.redeemed' and actor_id = '$USER_ID'")
[ "$pubs" = 1 ] || { echo "FAIL: expected 1 publisher row, found $pubs"; fail=1; }
[ "$redeemed" = 1 ] || { echo "FAIL: expected 1 redeemed invitation, found $redeemed"; fail=1; }
[ "$events" = 1 ] || { echo "FAIL: expected 1 audit event, found $events"; fail=1; }

# Append-only audit invariant: this run added exactly two events (admin bootstrap, redemption),
# and an attempt to delete or alter them is refused even for the table owner.
audit_after=$(q -c "select count(*) from public.audit_events")
[ $((audit_after - audit_before)) -eq 2 ] || { echo "FAIL: expected 2 new audit events, found $((audit_after - audit_before))"; fail=1; }
if q -c "delete from public.audit_events where actor_id = '$USER_ID'" >/dev/null 2>&1; then echo "FAIL: audit events could be deleted"; fail=1; fi
if q -c "update public.audit_events set action = 'invite.created' where actor_id = '$USER_ID'" >/dev/null 2>&1; then echo "FAIL: audit events could be altered"; fail=1; fi
[ "$(q -c "select count(*) from public.audit_events where action = 'invite.redeemed' and actor_id = '$USER_ID'")" = 1 ] || { echo "FAIL: audit event changed after tamper attempts"; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "ok - T-I07 concurrent redemption: 1 publisher, 1 redeemed invitation, 1 audit event; second session refused; audit append-only held"
else
  exit 1
fi
