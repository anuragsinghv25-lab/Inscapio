// Regression tests for the test harness itself: a failing operation must not leave a standing
// validator_service membership (or a lingering role) behind. Needs only the database, not the API.
import test from 'node:test';
import assert from 'node:assert/strict';
import { asValidator, owner, serviceRoleMemberships, actingMemberships } from './lib.mjs';

const baseline = serviceRoleMemberships();

test('harness: before the checks, no session can act as a service role (any baseline row is admin-only)', () => {
  assert.equal(actingMemberships(), '0', `baseline memberships: ${baseline}`);
});

test('harness: a successful validator call runs as validator_service and leaves memberships exactly as they were', () => {
  assert.equal(asValidator('select current_user'), 'validator_service');
  assert.equal(serviceRoleMemberships(), baseline);
  assert.equal(actingMemberships(), '0');
});

test('harness: a FAILING validator call throws and leaves memberships exactly as they were', () => {
  assert.throws(() => asValidator('select 1/0'), /Command failed|division by zero/);
  assert.equal(serviceRoleMemberships(), baseline, 'the failed call must not leave a membership');
  assert.equal(actingMemberships(), '0');
});

test('harness: a refusal from the database (an unknown revision; a privilege the role lacks) also leaves nothing behind', () => {
  assert.throws(() => asValidator(`select public.record_validation(gen_random_uuid(), true, 'x')`), /Command failed|revision not found/);
  assert.equal(serviceRoleMemberships(), baseline);
  assert.throws(() => asValidator('select count(*) from public.admins'), /Command failed|permission denied/);
  assert.equal(serviceRoleMemberships(), baseline);
  assert.equal(actingMemberships(), '0');
});

test('harness: the role is not left set, and the owner path still works afterwards', () => {
  assert.equal(owner('select current_user'), 'postgres');
  assert.equal(asValidator('select current_user'), 'validator_service');
  assert.equal(serviceRoleMemberships(), baseline);
});
