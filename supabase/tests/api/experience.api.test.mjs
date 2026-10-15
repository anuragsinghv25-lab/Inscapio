// Layer 2: the Stage 3.2 experience core through the REAL local stack (GoTrue -> PostgREST -> Postgres).
// Real sessions, real JWTs, real aal2. The two existing experience documents are used as fixtures.
// The validator attestation is made by a stand-in for the future validator service (database role
// validator_service); the full Zod validation is covered by the repository's unit tests, not here.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  SERVICE, keyHeaders, http, API, rest, rpc, createUser, signIn, claims, elevateToAal2, owner, asValidator, run,
} from './lib.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../src/content/experiences');
function loadDoc(name) {
  const dir = path.join(ROOT, name);
  const raw = JSON.parse(fs.readFileSync(path.join(dir, 'experience.json'), 'utf8'));
  const dsDir = path.join(dir, 'datasets');
  const extra = fs.existsSync(dsDir)
    ? fs.readdirSync(dsDir).filter((f) => f.endsWith('.json')).sort().map((f) => JSON.parse(fs.readFileSync(path.join(dsDir, f), 'utf8')))
    : [];
  return { ...raw, datasets: [...(raw.datasets ?? []), ...extra] };
}
const withSlug = (doc, slug) => ({ ...doc, id: slug, slug });
const state = {};
const refused = (r, code, msg) => {
  assert.ok(r.status >= 400, `${msg}: expected a refusal, got ${r.status} ${r.text}`);
  assert.equal(r.json?.code, code, `${msg}: expected SQLSTATE ${code}, got ${r.text}`);
};
const attest = (revId, ver = 'zod-1') => asValidator(`select public.record_validation('${revId}', true, '${ver}')`);
const head = async (token, expId) => (await rest('GET', `experiences?select=head_revision_id&id=eq.${expId}`, token)).json[0].head_revision_id;

test('setup: synthetic users; publishers A and B exist; the administrator is bootstrapped by the owner procedure and elevated to aal2', async () => {
  state.adminId = await createUser('x-admin');
  state.aId = await createUser('x-pub-a');
  state.bId = await createUser('x-pub-b');
  state.noneId = await createUser('x-none');
  owner(`select private.bootstrap_admin('${state.adminId}')`);
  // publishers are normally created by redeem_invite (covered in identity.api.test.mjs)
  owner(`insert into public.publishers (id, status) values ('${state.aId}', 'active'), ('${state.bId}', 'active')`);
  state.a = await signIn('x-pub-a');
  state.b = await signIn('x-pub-b');
  state.none = await signIn('x-none');
  state.admin1 = await signIn('x-admin');
  state.admin = await elevateToAal2(state.admin1);
  assert.equal(claims(state.admin).aal, 'aal2');
});

test('the shape gate accepts both real experience documents; reserved slugs are refused', async () => {
  for (const name of ['climate', 'whose-body-is-it']) {
    const slug = `${name}-api-${run}`;
    const r = await rpc('create_experience', { p_slug: slug, p_kind: loadDoc(name).kind, p_document: withSlug(loadDoc(name), slug) }, state.a);
    assert.equal(r.status, 200, `create ${name}: ${r.text}`);
    state[name] = r.json;
  }
  const reserved = await rpc('create_experience', { p_slug: 'climate', p_kind: 'data-story', p_document: withSlug(loadDoc('climate'), 'climate') }, state.a);
  refused(reserved, '22023', 'reserved slug');
  const tampered = withSlug(loadDoc('whose-body-is-it'), `tamper-${run}`);
  tampered.sections[0].blocks[0].type = 'script';
  refused(await rpc('create_experience', { p_slug: `tamper-${run}`, p_kind: 'explainer', p_document: tampered }, state.a), '22023', 'unknown block type');
  const own = await rest('GET', 'experiences?select=id,slug', state.a);
  assert.equal(own.json.length, 2, 'valid: A sees exactly their two experiences');
});

test('ownership isolation through the API: B sees and changes nothing of A', async () => {
  const bSees = await rest('GET', 'experiences?select=id', state.b);
  assert.deepEqual(bSees.json, [], 'B reads none of A\'s experiences');
  const revs = await rest('GET', 'revisions?select=id', state.b);
  assert.deepEqual(revs.json, [], 'B reads none of A\'s revisions');
  const h = await head(state.a, state['climate']);
  refused(await rpc('save_revision', { p_experience_id: state.climate, p_expected_parent: h, p_document: withSlug(loadDoc('climate'), `climate-api-${run}`) }, state.b), '42501', 'B saves to A');
  refused(await rpc('approve_revision', { p_revision_id: h }, state.b), '42501', 'B approves A\'s revision');
  refused(await rpc('publish_revision', { p_revision_id: h }, state.b), '42501', 'B publishes A\'s revision');
  const patch = await rest('PATCH', `experiences?id=eq.${state.climate}`, state.b, { archived_at: new Date().toISOString() }, { Prefer: 'return=representation' });
  assert.deepEqual(patch.json, [], 'B cannot archive A\'s experience (zero rows)');
  const own = await rest('PATCH', `experiences?id=eq.${state.climate}`, state.a, { archived_at: null }, { Prefer: 'return=representation' });
  assert.equal(own.json.length, 1, 'valid twin: A can update their own archived_at');
  refused(await rest('PATCH', `experiences?id=eq.${state.climate}`, state.a, { slug: 'stolen' }), '42501', 'slug is not updatable');
  refused(await rest('PATCH', `experiences?id=eq.${state.climate}`, state.a, { publisher_id: state.bId }), '42501', 'owner is not updatable');
  refused(await rest('POST', 'experiences', state.a, { publisher_id: state.aId, slug: 'direct-insert', kind: 'explainer', language: 'en', title: 'x' }), '42501', 'direct insert');
  refused(await rest('DELETE', `experiences?id=eq.${state.climate}`, state.a), '42501', 'delete');
  const none = await rpc('create_experience', { p_slug: `none-${run}`, p_kind: 'explainer', p_document: withSlug(loadDoc('whose-body-is-it'), `none-${run}`) }, state.none);
  refused(none, '42501', 'a signed-in user with no publisher record cannot create');
});

test('the publisher cannot attest or bypass validation; approval needs a passing attestation for the exact content', async () => {
  const h = await head(state.a, state.climate);
  refused(await rpc('record_validation', { p_revision_id: h, p_passed: true, p_validator_version: 'self' }, state.a), '42501', 'publisher record_validation');
  refused(await rpc('get_revision_for_validation', { p_revision_id: h }, state.a), '42501', 'publisher get_revision_for_validation');
  refused(await rest('POST', 'revision_validations', state.a, { revision_id: h, content_hash: 'x', validator_version: 'v', passed: true }), '42501', 'direct attestation insert');
  refused(await rpc('approve_revision', { p_revision_id: h }, state.a), '55000', 'approve with no attestation');
  asValidator(`select public.record_validation('${h}', false, 'zod-1', '[{"path":"sections.0","code":"synthetic"}]')`);
  refused(await rpc('approve_revision', { p_revision_id: h }, state.a), '55000', 'approve after a failed attestation');
  const seen = await rest('GET', `revision_validations?select=passed,errors&revision_id=eq.${h}`, state.a);
  assert.equal(seen.json[0].passed, false, 'valid: the owner can read their attestation');
  assert.deepEqual((await rest('GET', 'revision_validations?select=id', state.b)).json, [], 'B cannot read it');
  attest(h, 'zod-2');
  const ok = await rpc('approve_revision', { p_revision_id: h }, state.a);
  assert.equal(ok.status, 204, `approve after a passing attestation: ${ok.text}`);
  const apr = await rest('GET', `approvals?select=approved_by,approved_via,content_hash&revision_id=eq.${h}`, state.a);
  const rev = await rest('GET', `revisions?select=content_hash&id=eq.${h}`, state.a);
  assert.equal(apr.json[0].approved_by, state.aId);
  assert.equal(apr.json[0].approved_via, 'human_session');
  assert.equal(apr.json[0].content_hash, rev.json[0].content_hash, 'the approval is bound to the revision\'s content hash');
  state.climateRev1 = h;
});

test('the secret key (service_role) cannot forge approvals, publications, the projection or revisions', async () => {
  const sk = keyHeaders(SERVICE);
  const call = (method, p, body) => http(method, `${API}/rest/v1/${p}`, { headers: sk, body });
  refused(await call('POST', 'approvals', { revision_id: state.climateRev1, experience_id: state.climate, approved_by: state.aId, content_hash: 'x' }), '42501', 'service approvals insert');
  refused(await call('POST', 'publications', { experience_id: state.climate, revision_id: state.climateRev1, slug_at_publish: 'x', published_by: state.aId }), '42501', 'service publications insert');
  refused(await call('POST', 'published_experiences', { experience_id: state.climate }), '42501', 'service projection insert');
  refused(await call('PATCH', `revisions?id=eq.${state.climateRev1}`, { note: 'forged' }), '42501', 'service revisions update');
  refused(await http('POST', `${API}/rest/v1/rpc/approve_revision`, { headers: sk, body: { p_revision_id: state.climateRev1 } }), '42501', 'service approve_revision');
  refused(await http('POST', `${API}/rest/v1/rpc/record_validation`, { headers: sk, body: { p_revision_id: state.climateRev1, p_passed: true, p_validator_version: 'forged' } }), '42501', 'service record_validation');
});

test('administrator (aal2), anon and a non-publisher user cannot attest or read for validation; the validator can, and the hash comes from the stored revision', async () => {
  const h = state.climateRev1;
  const args = { p_revision_id: h, p_passed: true, p_validator_version: 'forged' };
  for (const [who, token] of [['administrator aal2', state.admin], ['non-publisher user', state.none], ['anon', undefined]]) {
    refused(await rpc('record_validation', args, token), '42501', `${who} record_validation`);
    refused(await rpc('get_revision_for_validation', { p_revision_id: h }, token), '42501', `${who} get_revision_for_validation`);
    refused(await rest('POST', 'revision_validations', token, { revision_id: h, content_hash: 'x', validator_version: 'forged', passed: true }), '42501', `${who} direct attestation insert`);
    refused(await rest('PATCH', `revision_validations?revision_id=eq.${h}`, token, { passed: true }), '42501', `${who} attestation update`);
  }
  // a client cannot supply a content hash: no such parameter exists, so PostgREST finds no matching function
  const withHash = await rpc('record_validation', { ...args, p_content_hash: 'a'.repeat(64) }, state.admin);
  assert.ok(withHash.status >= 400 && withHash.json?.code !== undefined, `a hash argument must not be accepted: ${withHash.text}`);
  // positive counterpart: the validator reads exactly the stored revision and its hash
  const stored = (await rest('GET', `revisions?select=content_hash&id=eq.${h}`, state.a)).json[0].content_hash;
  const got = asValidator(`select content_hash from public.get_revision_for_validation('${h}')`);
  assert.equal(got, stored, 'valid: the validator receives the stored hash');
  // and the zero attestations written by all of the above denials
  assert.equal(owner(`select count(*) from public.revision_validations where validator_version = 'forged'`), '0');
});

test('publish, public read, drafts do not leak, unpublish removes the public row', async () => {
  const pub = await rpc('publish_revision', { p_revision_id: state.climateRev1 }, state.a);
  assert.equal(pub.status, 200, `publish: ${pub.text}`);
  state.pubId = pub.json;
  const slug = `climate-api-${run}`;
  const anon = await rest('GET', `published_experiences?select=slug,title,document&slug=eq.${slug}`);
  assert.equal(anon.json.length, 1, 'anon reads the published experience by slug');
  assert.equal(anon.json[0].document.sections.length, loadDoc('climate').sections.length, 'the whole real document is served');
  const draft = withSlug(loadDoc('climate'), slug);
  draft.title = 'A later draft title';
  const h = await head(state.a, state.climate);
  const saved = await rpc('save_revision', { p_experience_id: state.climate, p_expected_parent: h, p_document: draft }, state.a);
  assert.equal(saved.status, 200, `save: ${saved.text}`);
  const still = await rest('GET', `published_experiences?select=title&slug=eq.${slug}`);
  assert.equal(still.json[0].title, loadDoc('climate').title, 'a newer draft does not change what anon sees');
  for (const t of ['experiences', 'revisions', 'revision_validations', 'approvals', 'publications', 'experience_topics']) {
    refused(await rest('GET', t), '42501', `anon select ${t}`);
  }
  refused(await rest('PATCH', 'published_experiences?slug=eq.' + slug, state.a, { title: 'forged' }), '42501', 'publisher rewrite of the projection');
  refused(await rpc('unpublish_experience', { p_experience_id: state.climate }, state.b), '42501', 'B unpublish');
  const un = await rpc('unpublish_experience', { p_experience_id: state.climate, p_note: 'api test' }, state.a);
  assert.equal(un.status, 204, `unpublish: ${un.text}`);
  assert.deepEqual((await rest('GET', `published_experiences?select=slug&slug=eq.${slug}`)).json, [], 'the public row is gone');
  const clash = await rpc('create_experience', { p_slug: slug, p_kind: 'data-story', p_document: withSlug(loadDoc('climate'), slug) }, state.b);
  refused(clash, '23505', 'the slug stays reserved after unpublish');
});

test('admin takedown at aal2: no content access, atomic removal, hold blocks the owner until lifted', async () => {
  const wb = state['whose-body-is-it'];
  const h = await head(state.a, wb);
  attest(h);
  assert.equal((await rpc('approve_revision', { p_revision_id: h }, state.a)).status, 204);
  assert.equal((await rpc('publish_revision', { p_revision_id: h }, state.a)).status, 200);
  const slug = `whose-body-is-it-api-${run}`;
  assert.equal((await rest('GET', `published_experiences?select=slug&slug=eq.${slug}`)).json.length, 1);
  for (const t of ['experiences', 'revisions', 'revision_validations', 'approvals']) {
    assert.deepEqual((await rest('GET', `${t}?select=*`, state.admin)).json, [], `the administrator at aal2 reads no ${t} row`);
  }
  assert.ok((await rest('GET', 'publications?select=id,unpublished_at', state.admin)).json.length >= 1, 'valid: the administrator reads publication metadata');
  refused(await rpc('admin_takedown', { p_experience_id: wb, p_reason_code: 'policy', p_note: 'synthetic' }, state.a), '42501', 'publisher takedown');
  refused(await rpc('admin_takedown', { p_experience_id: wb, p_reason_code: 'policy', p_note: 'synthetic' }, state.admin1), '42501', 'administrator at aal1');
  const td = await rpc('admin_takedown', { p_experience_id: wb, p_reason_code: 'safety', p_note: 'synthetic takedown' }, state.admin);
  assert.equal(td.status, 204, `takedown: ${td.text}`);
  assert.deepEqual((await rest('GET', `published_experiences?select=slug&slug=eq.${slug}`)).json, [], 'the public row is gone');
  refused(await rpc('publish_revision', { p_revision_id: h }, state.a), '55000', 'held experience cannot be republished');
  refused(await rpc('set_experience_hold', { p_experience_id: wb, p_held: false }, state.a), '42501', 'publisher lifts hold');
  assert.equal((await rpc('set_experience_hold', { p_experience_id: wb, p_held: false }, state.admin)).status, 204);
  assert.equal((await rpc('publish_revision', { p_revision_id: h }, state.a)).status, 200, 'valid twin: after the hold is lifted the owner republishes');
});

test('T-S02/T-L10 at the API: a suspended publisher\'s existing token loses access immediately; reinstatement restores it', async () => {
  const before = await rest('GET', 'experiences?select=id', state.a);
  assert.equal(before.json.length, 2);
  assert.equal((await rpc('set_publisher_status', { p_publisher_id: state.aId, p_status: 'suspended', p_reason: 'synthetic' }, state.admin)).status, 204);
  assert.deepEqual((await rest('GET', 'experiences?select=id', state.a)).json, [], 'the same token reads no experience');
  refused(await rpc('create_experience', { p_slug: `late-${run}`, p_kind: 'explainer', p_document: withSlug(loadDoc('whose-body-is-it'), `late-${run}`) }, state.a), '42501', 'suspended create');
  refused(await rpc('unpublish_experience', { p_experience_id: state['whose-body-is-it'] }, state.a), '42501', 'suspended unpublish');
  assert.equal((await rest('GET', `published_experiences?select=slug&slug=eq.whose-body-is-it-api-${run}`)).json.length, 1, 'already-published content stays live');
  assert.equal((await rpc('set_publisher_status', { p_publisher_id: state.aId, p_status: 'active', p_reason: 'synthetic reinstatement' }, state.admin)).status, 204);
  assert.equal((await rest('GET', 'experiences?select=id', state.a)).json.length, 2, 'valid twin: the same token reads again after reinstatement');
});

test('T-S05 a token with altered claims is rejected on the new functions too', async () => {
  const parts = state.a.split('.');
  const forged = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
  forged.sub = state.bId;
  const bad = `${parts[0]}.${Buffer.from(JSON.stringify(forged)).toString('base64url')}.${parts[2]}`;
  const r = await rpc('create_experience', { p_slug: `forged-${run}`, p_kind: 'explainer', p_document: withSlug(loadDoc('whose-body-is-it'), `forged-${run}`) }, bad);
  assert.equal(r.status, 401, `forged token must be rejected: ${r.text}`);
});

test('sentinel: no validator_service or ai_service membership was left behind by any test in this file', () => {
  assert.equal(owner(`select count(*) from pg_auth_members m join pg_roles r on r.oid = m.roleid where r.rolname in ('validator_service','ai_service')`), '0');
});
