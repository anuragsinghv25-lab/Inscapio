// Layer 2: authorisation through the REAL local stack (GoTrue -> PostgREST -> Postgres).
// Real sessions, real JWTs, real MFA (aal2). No mocks. Local stack only; synthetic users only.
// Environment (from `supabase status -o env`, never stored): API_URL, ANON_KEY|PUBLISHABLE_KEY,
// SERVICE_ROLE_KEY|SECRET_KEY, DB_URL. The service key is used ONLY to create synthetic Auth users.
import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const env = process.env;
const API = env.API_URL;
const ANON = env.ANON_KEY ?? env.PUBLISHABLE_KEY;
const SERVICE = env.SERVICE_ROLE_KEY ?? env.SECRET_KEY;
const DB_URL = env.DB_URL;
for (const [k, v] of Object.entries({ API_URL: API, ANON_KEY: ANON, SERVICE_ROLE_KEY: SERVICE, DB_URL })) {
  assert.ok(v, `${k} must be set from supabase status -o env`);
}
for (const u of [API, DB_URL]) assert.match(u, /127\.0\.0\.1|localhost/, 'local stack only');

const run = crypto.randomBytes(4).toString('hex');
const PASSWORD = crypto.randomBytes(16).toString('hex'); // synthetic, generated per run, never stored
const email = (n) => `${n}-${run}@example.test`;

const keyHeaders = (key) => (key.startsWith('eyJ') ? { apikey: key, Authorization: `Bearer ${key}` } : { apikey: key });

async function http(method, url, { headers = {}, body } = {}) {
  const res = await fetch(url, {
    method,
    headers: { 'content-type': 'application/json', ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* non-JSON body */ }
  return { status: res.status, json, text };
}
const anonH = (token) => ({ apikey: ANON, Authorization: `Bearer ${token ?? ANON}` });
const rest = (method, path, token, body, extra = {}) =>
  http(method, `${API}/rest/v1/${path}`, { headers: { ...anonH(token), ...extra }, body });
const rpc = (fn, args, token) => rest('POST', `rpc/${fn}`, token, args ?? {});

async function createUser(name) {
  const r = await http('POST', `${API}/auth/v1/admin/users`, {
    headers: keyHeaders(SERVICE),
    body: { email: email(name), password: PASSWORD, email_confirm: true },
  });
  assert.equal(r.status, 200, `create user ${name}: ${r.text}`);
  return r.json.id;
}
async function signIn(name) {
  const r = await http('POST', `${API}/auth/v1/token?grant_type=password`, {
    headers: { apikey: ANON }, body: { email: email(name), password: PASSWORD },
  });
  assert.equal(r.status, 200, `sign in ${name}: ${r.text}`);
  return r.json.access_token;
}
const claims = (jwt) => JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString());

function totp(secretBase32) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const c of secretBase32.replace(/=+$/, '').toUpperCase()) bits += alphabet.indexOf(c).toString(2).padStart(5, '0');
  const bytes = Buffer.from(bits.match(/.{8}/g).map((b) => parseInt(b, 2)));
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(Date.now() / 30000)));
  const h = crypto.createHmac('sha1', bytes).update(counter).digest();
  const o = h[h.length - 1] & 0xf;
  const code = ((h.readUInt32BE(o) & 0x7fffffff) % 1_000_000).toString().padStart(6, '0');
  return code;
}
async function elevateToAal2(token) {
  const auth = { apikey: ANON, Authorization: `Bearer ${token}` };
  const enroll = await http('POST', `${API}/auth/v1/factors`, { headers: auth, body: { factor_type: 'totp', friendly_name: `t-${run}` } });
  assert.equal(enroll.status, 200, `mfa enroll: ${enroll.text}`);
  const { id, totp: { secret } } = enroll.json;
  const ch = await http('POST', `${API}/auth/v1/factors/${id}/challenge`, { headers: auth, body: {} });
  assert.equal(ch.status, 200, `mfa challenge: ${ch.text}`);
  const ver = await http('POST', `${API}/auth/v1/factors/${id}/verify`, { headers: auth, body: { challenge_id: ch.json.id, code: totp(secret) } });
  assert.equal(ver.status, 200, `mfa verify: ${ver.text}`);
  return ver.json.access_token;
}
const owner = (sql) => execFileSync('psql', [DB_URL, '-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1', '-c', sql]).toString().trim();
const denied = (r, msg) => {
  assert.ok(r.status >= 400, `${msg}: expected a refusal, got ${r.status} ${r.text}`);
  assert.equal(r.json?.code, '42501', `${msg}: expected SQLSTATE 42501, got ${r.text}`);
};

const state = {};

test('setup: synthetic users exist and the admin is bootstrapped by the owner procedure', async () => {
  state.adminId = await createUser('admin');
  state.pubId = await createUser('publisher');
  state.plainId = await createUser('plain');
  owner(`select private.bootstrap_admin('${state.adminId}')`);
});

test('T-A09 / T-A05 anon cannot call identity functions or read identity tables through the API', async () => {
  for (const fn of ['create_invite', 'revoke_invite', 'redeem_invite', 'set_publisher_status']) {
    denied(await rpc(fn, {}), `anon rpc ${fn}`);
  }
  for (const table of ['admins', 'publishers', 'invites', 'audit_events']) {
    denied(await rest('GET', table), `anon select ${table}`);
  }
});

test('the private schema is not exposed through the API', async () => {
  const r = await rest('POST', 'rpc/is_admin', undefined, {}, { 'Content-Profile': 'private' });
  assert.ok(r.status >= 400 && r.status < 500, `private schema must not be reachable, got ${r.status}`);
});

test('T-I01 a signed-in user with no capability cannot create invitations', async () => {
  const t = await signIn('plain');
  denied(await rpc('create_invite', { p_email: email('x') }, t), 'plain user create_invite');
});

test('T-I02 / T-I03 an administrator is refused at aal1 and accepted at aal2 (real TOTP)', async () => {
  const aal1 = await signIn('admin');
  assert.equal(claims(aal1).aal, 'aal1');
  denied(await rpc('create_invite', { p_email: email('publisher') }, aal1), 'admin at aal1');
  state.adminAal2 = await elevateToAal2(aal1);
  assert.equal(claims(state.adminAal2).aal, 'aal2');
  const ok = await rpc('create_invite', { p_email: email('publisher') }, state.adminAal2);
  assert.equal(ok.status, 200, `admin at aal2: ${ok.text}`);
  assert.match(String(ok.json), /^[0-9a-f-]{36}$/);
  const audit = await rest('GET', 'audit_events?select=action&action=eq.invite.created', state.adminAal2);
  assert.ok(audit.json.length >= 1, 'admin at aal2 can read the audit log');
  const audit1 = await rest('GET', 'audit_events?select=action', aal1);
  assert.deepEqual(audit1.json, [], 'admin at aal1 sees no audit events');
});

test('T-S04 changing user_metadata / requesting a role does not grant privileges', async () => {
  const t = await signIn('plain');
  const upd = await http('PUT', `${API}/auth/v1/user`, {
    headers: { apikey: ANON, Authorization: `Bearer ${t}` },
    body: { data: { role: 'admin', is_admin: true, aal: 'aal2' } },
  });
  assert.ok(upd.status < 500, `metadata update: ${upd.text}`);
  const fresh = await signIn('plain'); // new token that now carries the forged metadata
  assert.equal(claims(fresh).user_metadata?.role, 'admin', 'precondition: the forged metadata is present in the token');
  denied(await rpc('create_invite', { p_email: email('y') }, fresh), 'forged user_metadata');
  const admins = await rest('GET', 'admins?select=user_id', fresh);
  assert.deepEqual(admins.json, [], 'forged metadata reveals no admin rows');
});

test('T-I04 / T-S04 redemption: valid for the invited verified user, refused the second time', async () => {
  const t = await signIn('publisher');
  state.pubToken = t;
  const first = await rpc('redeem_invite', {}, t);
  assert.equal(first.status, 200, `redeem: ${first.text}`);
  assert.equal(first.json, state.pubId);
  const me = await rest('GET', 'publishers?select=id,status', t);
  assert.deepEqual(me.json, [{ id: state.pubId, status: 'active' }]);
  const again = await rpc('redeem_invite', {}, t);
  assert.ok(again.status >= 400 && again.json?.code === '55000', `second redemption refused: ${again.text}`);
});

test('T-I01 a publisher cannot issue invitations or promote themselves', async () => {
  denied(await rpc('create_invite', { p_email: email('z') }, state.pubToken), 'publisher create_invite');
  denied(await rest('POST', 'admins', state.pubToken, { user_id: state.pubId }), 'publisher insert admins');
});

test('T-S02 a suspended publisher loses access immediately, with the SAME token', async () => {
  const before = await rest('PATCH', `publishers?id=eq.${state.pubId}`, state.pubToken, { display_name: 'Synthetic' }, { Prefer: 'return=representation' });
  assert.equal(before.status, 200);
  assert.equal(before.json.length, 1, 'valid: an active publisher can edit their profile');
  const sus = await rpc('set_publisher_status', { p_publisher_id: state.pubId, p_status: 'suspended', p_reason: 'synthetic test' }, state.adminAal2);
  assert.equal(sus.status, 204 , `suspend: ${sus.text}`);
  const after = await rest('PATCH', `publishers?id=eq.${state.pubId}`, state.pubToken, { display_name: 'After' }, { Prefer: 'return=representation' });
  assert.deepEqual(after.json, [], 'denied: the stale-session publisher can no longer edit');
  const own = await rest('GET', 'publishers?select=status', state.pubToken);
  assert.deepEqual(own.json, [{ status: 'suspended' }]);
});

test('T-S05 a token with altered claims is rejected', async () => {
  const parts = state.pubToken.split('.');
  const forged = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
  forged.aal = 'aal2';
  forged.sub = state.adminId;
  const bad = `${parts[0]}.${Buffer.from(JSON.stringify(forged)).toString('base64url')}.${parts[2]}`;
  const r = await rpc('create_invite', { p_email: email('forged') }, bad);
  assert.equal(r.status, 401, `forged token must be rejected: ${r.text}`);
});
