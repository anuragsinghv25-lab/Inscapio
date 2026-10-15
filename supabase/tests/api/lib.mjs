// Shared helpers for the Layer 2 tests: the REAL local stack (GoTrue -> PostgREST -> Postgres).
// Real sessions, real JWTs, real MFA (aal2). No mocks. Local stack only; synthetic users only.
// Environment (from `supabase status -o env`, never stored): API_URL, ANON_KEY|PUBLISHABLE_KEY,
// SERVICE_ROLE_KEY|SECRET_KEY, DB_URL. The service key is used ONLY to create synthetic Auth users.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

const env = process.env;
export const API = env.API_URL;
export const ANON = env.ANON_KEY ?? env.PUBLISHABLE_KEY;
export const SERVICE = env.SERVICE_ROLE_KEY ?? env.SECRET_KEY;
export const DB_URL = env.DB_URL;
for (const [k, v] of Object.entries({ API_URL: API, ANON_KEY: ANON, SERVICE_ROLE_KEY: SERVICE, DB_URL })) {
  assert.ok(v, `${k} must be set from supabase status -o env`);
}
for (const u of [API, DB_URL]) assert.match(u, /127\.0\.0\.1|localhost/, 'local stack only');

export const run = crypto.randomBytes(4).toString('hex');
export const PASSWORD = crypto.randomBytes(16).toString('hex'); // synthetic, generated per run, never stored
export const email = (n) => `${n}-${run}@example.test`;

export const keyHeaders = (key) => (key.startsWith('eyJ') ? { apikey: key, Authorization: `Bearer ${key}` } : { apikey: key });

export async function http(method, url, { headers = {}, body } = {}) {
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
export const anonH = (token) => ({ apikey: ANON, Authorization: `Bearer ${token ?? ANON}` });
export const rest = (method, path, token, body, extra = {}) =>
  http(method, `${API}/rest/v1/${path}`, { headers: { ...anonH(token), ...extra }, body });
export const rpc = (fn, args, token) => rest('POST', `rpc/${fn}`, token, args ?? {});

export async function createUser(name) {
  const r = await http('POST', `${API}/auth/v1/admin/users`, {
    headers: keyHeaders(SERVICE),
    body: { email: email(name), password: PASSWORD, email_confirm: true },
  });
  assert.equal(r.status, 200, `create user ${name}: ${r.text}`);
  return r.json.id;
}
export async function signIn(name) {
  const r = await http('POST', `${API}/auth/v1/token?grant_type=password`, {
    headers: { apikey: ANON }, body: { email: email(name), password: PASSWORD },
  });
  assert.equal(r.status, 200, `sign in ${name}: ${r.text}`);
  return r.json.access_token;
}
export const claims = (jwt) => JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString());

export function totp(secretBase32) {
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
export async function elevateToAal2(token) {
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
export const owner = (sql) => execFileSync('psql', [DB_URL, '-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1', '-c', sql]).toString().trim();
export const denied = (r, msg) => {
  assert.ok(r.status >= 400, `${msg}: expected a refusal, got ${r.status} ${r.text}`);
  assert.equal(r.json?.code, '42501', `${msg}: expected SQLSTATE 42501, got ${r.text}`);
};


// The validator is a database role with no login in this increment. A future validator service will
// connect as a member of it; here the test stands in for that service by switching to the role in a
// local session. Membership exists only inside one transaction and is never committed (see below).
export const asValidator = (sql) =>
  execFileSync('psql', [DB_URL, '-X', '-q', '-At', '-v', 'ON_ERROR_STOP=1'], {
    // Everything is one transaction, and the membership is granted AND revoked inside it. Role
    // membership changes are transactional, so the grant is never committed: if the statement fails,
    // psql stops, the connection closes and the transaction (grant included) rolls back; if it
    // succeeds, the revoke commits together with the work. No cleanup step can be skipped.
    input: `begin;\ngrant validator_service to postgres;\nset local role validator_service;\n${sql};\nreset role;\nrevoke validator_service from postgres;\ncommit;\n`,
  }).toString().trim();
