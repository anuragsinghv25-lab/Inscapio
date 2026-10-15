// Regression tests for the test harness itself: a failing operation must not leave a standing
// validator_service membership (or a lingering role) behind. Needs only the database, not the API.
import test from 'node:test';
import assert from 'node:assert/strict';
import { asValidator, owner } from './lib.mjs';

const members = () => owner(`select count(*) from pg_auth_members m join pg_roles r on r.oid = m.roleid where r.rolname in ('validator_service','ai_service')`);

// pg_has_role() is true for a superuser regardless, so check the membership catalogue itself
const postgresIsMember = () => owner(`select count(*) from pg_auth_members m join pg_roles r on r.oid = m.roleid join pg_roles g on g.oid = m.member where r.rolname = 'validator_service' and g.rolname = 'postgres'`);

test('harness: no service-role membership exists before the checks', () => {
  assert.equal(members(), '0');
});

test('harness: a successful validator call runs as validator_service and leaves no membership', () => {
  assert.equal(asValidator('select current_user'), 'validator_service');
  assert.equal(members(), '0');
  assert.equal(postgresIsMember(), '0');
});

test('harness: a FAILING validator call throws and leaves no membership behind', () => {
  assert.throws(() => asValidator('select 1/0'), /Command failed|division by zero/);
  assert.equal(members(), '0', 'the failed call must not leave a membership');
  assert.equal(postgresIsMember(), '0');
});

test('harness: a refusal from the database function (not a syntax error) also leaves nothing behind', () => {
  assert.throws(() => asValidator(`select public.record_validation(gen_random_uuid(), true, 'x')`), /Command failed|revision not found/);
  assert.equal(members(), '0');
  // and the validator can still not do something it was never granted, even inside the helper
  assert.throws(() => asValidator('select count(*) from public.admins'), /Command failed|permission denied/);
  assert.equal(members(), '0');
});

test('harness: the role is not left set, and the owner path still works afterwards', () => {
  assert.equal(owner('select current_user'), 'postgres');
  assert.equal(asValidator('select current_user'), 'validator_service');
  assert.equal(members(), '0');
});
