#!/usr/bin/env bash
# Stage 3.2 concurrency checks against the LOCAL Supabase database only. Each scenario needs two
# real database sessions, so it cannot live inside a single pgTAP transaction.
#   T-L06  two saves from the same parent: one wins, the other gets an edit conflict, nothing is overwritten
#   T-L05  two concurrent publications of different approved revisions: exactly one stays live
#   T-L10  a suspension committed while a save waits for the experience lock refuses that save
# Usage: DB_URL=postgresql://... supabase/tests/concurrency/lifecycle-races.sh
# Test data is synthetic and unique per run, so the script is repeatable on a persistent stack.
set -euo pipefail
: "${DB_URL:?DB_URL must point at the LOCAL Supabase database (from supabase status -o env)}"
case "$DB_URL" in
  *127.0.0.1*|*localhost*) ;;
  *) echo "refusing to run: DB_URL is not a local address" >&2; exit 2 ;;
esac

newid() { cat /proc/sys/kernel/random/uuid; }
RUN=$(newid | cut -c1-8)
PA=$(newid)
tmp_a=$(mktemp); tmp_b=$(mktemp)
fail=0
q() { psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -At "$@"; }
claims() { echo "{\"sub\":\"$1\",\"role\":\"authenticated\",\"aal\":\"aal1\"}"; }
as_pa() { echo "begin; select set_config('request.jwt.claims', '$(claims "$PA")', true); set local role authenticated;"; }
doc() { # slug title text
  echo "\$j\${\"schemaVersion\":1,\"id\":\"$1\",\"slug\":\"$1\",\"kind\":\"explainer\",\"title\":\"$2\",\"shortTitle\":\"S\",\"language\":\"en\",\"summary\":\"Synthetic.\",\"theme\":{},\"reading\":[],\"hero\":{\"title\":\"$2\",\"intro\":[\"Intro.\"],\"actions\":[]},\"sections\":[{\"id\":\"one\",\"title\":\"One\",\"blocks\":[{\"type\":\"paragraph\",\"text\":\"$3\"}]}],\"sources\":[],\"endnotes\":[]}\$j\$::jsonb"
}
check() { # description, expected, actual
  if [ "$2" = "$3" ]; then :; else echo "FAIL: $1 (expected '$2', found '$3')"; fail=1; fi
}
as_pa_q() { { as_pa; cat; echo "commit;"; } | psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -At; }

q <<SQL
insert into auth.users (id, email, email_confirmed_at, aud, role)
  values ('$PA', 'race-pub-$RUN@example.test', now(), 'authenticated', 'authenticated');
insert into public.publishers (id, status) values ('$PA', 'active');
SQL

new_experience() { # slug -> prints experience id
  echo "select public.create_experience('$1', 'explainer', $(doc "$1" "First" "First text."));" | as_pa_q | tail -1
}
head_of() { q -c "select head_revision_id from public.experiences where id = '$1'"; }
attest() { q -c "insert into public.revision_validations (revision_id, content_hash, validator_version, passed) select id, content_hash, 'race-1', true from public.revisions where id = '$1'"; }

audit_before=$(q -c "select count(*) from public.audit_events")

# ---------------------------------------------------------------- T-L06: concurrent saves
S1="race-save-$RUN"
E1=$(new_experience "$S1"); R1=$(head_of "$E1")
( { as_pa; echo "select public.save_revision('$E1', '$R1', $(doc "$S1" "Winner" "Winner text."));"; echo "select pg_sleep(3);"; echo "commit;"; } \
  | psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -At ) > "$tmp_a" 2>&1 &
pid_a=$!
sleep 1
set +e
{ as_pa; echo "select public.save_revision('$E1', '$R1', $(doc "$S1" "Loser" "Loser text."));"; echo "commit;"; } \
  | psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -At > "$tmp_b" 2>&1
status_b=$?
wait "$pid_a"; status_a=$?
set -e
check "T-L06 first save succeeds" 0 "$status_a"
[ "$status_b" -ne 0 ] || { echo "FAIL: T-L06 concurrent save from the same parent should be refused"; fail=1; }
grep -q "edit conflict" "$tmp_b" || { echo "FAIL: T-L06 second save did not fail with an edit conflict"; cat "$tmp_b"; fail=1; }
check "T-L06 exactly two revisions" 2 "$(q -c "select count(*) from public.revisions where experience_id = '$E1'")"
check "T-L06 the winner's title is the derived title" "Winner" "$(q -c "select title from public.experiences where id = '$E1'")"
check "T-L06 the head is the first save, not overwritten" "2" "$(q -c "select seq from public.revisions where id = (select head_revision_id from public.experiences where id = '$E1')")"
check "T-L06 no revision carries the losing text" 0 "$(q -c "select count(*) from public.revisions where experience_id = '$E1' and document::text like '%Loser%'")"
[ "$fail" -eq 0 ] && echo "ok - T-L06 concurrent saves: one winner, one edit conflict, no overwrite"

# ---------------------------------------------------------------- T-L05: concurrent publications
S2="race-pub-$RUN"
E2=$(new_experience "$S2"); P1=$(head_of "$E2")
P2=$(echo "select public.save_revision('$E2', '$P1', $(doc "$S2" "Second" "Second text."));" | as_pa_q | tail -1)
P3=$(echo "select public.save_revision('$E2', '$P2', $(doc "$S2" "Third" "Third text."));" | as_pa_q | tail -1)
attest "$P2"; attest "$P3"
echo "select public.approve_revision('$P2'); select public.approve_revision('$P3');" | as_pa_q >/dev/null
( { as_pa; echo "select public.publish_revision('$P2');"; echo "select pg_sleep(3);"; echo "commit;"; } \
  | psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -At ) > "$tmp_a" 2>&1 &
pid_a=$!
sleep 1
set +e
{ as_pa; echo "select public.publish_revision('$P3');"; echo "commit;"; } \
  | psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -At > "$tmp_b" 2>&1
status_b=$?
wait "$pid_a"; status_a=$?
set -e
check "T-L05 first publish succeeds" 0 "$status_a"
check "T-L05 second publish succeeds after waiting" 0 "$status_b"
check "T-L05 exactly one live publication" 1 "$(q -c "select count(*) from public.publications where experience_id = '$E2' and unpublished_at is null")"
check "T-L05 two publications in the history" 2 "$(q -c "select count(*) from public.publications where experience_id = '$E2'")"
check "T-L05 exactly one public row" 1 "$(q -c "select count(*) from public.published_experiences where experience_id = '$E2'")"
check "T-L05 the public row belongs to the live publication" 1 "$(q -c "select count(*) from public.published_experiences pe join public.publications p on p.id = pe.publication_id where pe.experience_id = '$E2' and p.unpublished_at is null")"
check "T-L05 the earlier publication was superseded" 1 "$(q -c "select count(*) from public.publications where experience_id = '$E2' and unpublish_reason = 'superseded'")"
check "T-L05 the public document is the document of the live publication's revision" 1 "$(q -c "select count(*) from public.published_experiences pe join public.publications p on p.id = pe.publication_id join public.revisions r on r.id = p.revision_id where pe.experience_id = '$E2' and pe.document = r.document")"

# ---------------------------------------------------------------- T-L10: suspension while a save waits
S3="race-susp-$RUN"
E3=$(new_experience "$S3"); Q1=$(head_of "$E3")
( q <<SQL
begin;
select 1 from public.experiences where id = '$E3' for update;
select pg_sleep(3);
update public.publishers set status = 'suspended', status_reason = 'synthetic race', status_changed_at = now() where id = '$PA';
commit;
SQL
) > "$tmp_a" 2>&1 &
pid_a=$!
sleep 1
set +e
{ as_pa; echo "select public.save_revision('$E3', '$Q1', $(doc "$S3" "Too late" "Too late text."));"; echo "commit;"; } \
  | psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -At > "$tmp_b" 2>&1
status_b=$?
wait "$pid_a"; status_a=$?
set -e
check "T-L10 the suspending session committed" 0 "$status_a"
[ "$status_b" -ne 0 ] || { echo "FAIL: T-L10 a save that waited through a suspension should be refused"; fail=1; }
grep -q "not authorised" "$tmp_b" || { echo "FAIL: T-L10 the waiting save was not refused as unauthorised"; cat "$tmp_b"; fail=1; }
check "T-L10 no revision was written after the suspension" 1 "$(q -c "select count(*) from public.revisions where experience_id = '$E3'")"
check "T-L10 work committed before the suspension is intact" "First" "$(q -c "select title from public.experiences where id = '$E3'")"

# ---------------------------------------------------------------- append-only audit
audit_after=$(q -c "select count(*) from public.audit_events")
[ "$audit_after" -gt "$audit_before" ] || { echo "FAIL: the scenarios wrote no audit events"; fail=1; }
if q -c "delete from public.audit_events where actor_id = '$PA'" >/dev/null 2>&1; then echo "FAIL: audit events could be deleted"; fail=1; fi
if q -c "update public.revisions set note = 'tamper' where experience_id = '$E1'" >/dev/null 2>&1; then echo "FAIL: a revision could be altered"; fail=1; fi

if [ "$fail" -eq 0 ]; then
  echo "ok - T-L05 concurrent publications: one live, one superseded, public row consistent"
  echo "ok - T-L10 suspension committed while a save waited: the save was refused, prior work intact"
  echo "ok - lifecycle races: audit and revisions stayed append-only"
else
  exit 1
fi
