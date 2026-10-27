'use strict';

// Drop-in environment adapter for the existing CrimBlox core.js.
// Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY on the trusted server only.
// Keeps the existing core's JSON state shape while moving persistence to Supabase.
const crypto = require('node:crypto');

async function createSupabaseEnv({
  dev = process.env.NODE_ENV !== 'production',
  limits,
  wsUrl = null,
  adminUsers = (process.env.ADMIN_USERS || '').split(',').filter(Boolean),
} = {}) {
  const base = String(process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!base || !key) throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.');
  const tableUrl = base + '/rest/v1/crimblox_backend_state';
  const bucket = 'crimblox-backend-objects';
  const headers = {
    apikey: key,
    Authorization: 'Bearer ' + key,
    'Content-Type': 'application/json',
  };
  async function request(url, options = {}) {
    const response = await fetch(url, { ...options, headers: { ...headers, ...(options.headers || {}) } });
    if (!response.ok) {
      const body = await response.text().catch(() => '');
      throw new Error('Supabase request failed (' + response.status + '): ' + body.slice(0, 500));
    }
    return response;
  }
  const loaded = await request(tableUrl + '?id=eq.1&select=state', { headers: { Accept: 'application/json' } });
  const rows = await loaded.json();
  if (!rows.length) throw new Error('Missing crimblox_backend_state seed row; apply the CrimBlox migration first.');
  let current = rows[0].state || {};
  let saveChain = Promise.resolve();
  const saveState = db => {
    const snapshot = JSON.parse(JSON.stringify(db));
    saveChain = saveChain.then(() => request(tableUrl + '?on_conflict=id', {
      method: 'POST',
      headers: { Prefer: 'resolution=merge-duplicates,return=minimal' },
      body: JSON.stringify({ id: 1, state: snapshot, updated_at: new Date().toISOString() }),
    })).then(() => { current = snapshot; });
    saveChain.catch(err => console.error('[CrimBlox] Supabase state save failed:', err.message));
    return saveChain;
  };
  const objectUrl = keyPath => base + '/storage/v1/object/' + bucket + '/' + keyPath.split('/').map(encodeURIComponent).join('/');
  return {
    mode: 'supabase', dev, limits, wsUrl, adminUsers,
    now: () => Date.now(),
    rand: n => crypto.randomBytes(n).toString('hex'),
    sha256: async s => crypto.createHash('sha256').update(s).digest('hex'),
    hashPassword: (pw, salt) => new Promise((resolve, reject) =>
      crypto.scrypt(pw, salt, 32, { N: 16384 }, (err, out) => err ? reject(err) : resolve(out.toString('hex')))),
    b64head: (b, n) => Buffer.from(b.slice(0, Math.ceil(n * 4 / 3) + 4), 'base64').subarray(0, n),
    defer: fn => setTimeout(fn, 0),
    load: () => current,
    save: saveState,
    flush: async db => { await saveState(db); await saveChain; },
    putFile: async (objectKey, b64) => {
      await request(objectUrl(objectKey), {
        method: 'POST',
        headers: { 'Content-Type': 'text/plain; charset=utf-8', 'x-upsert': 'true' },
        body: b64,
      });
    },
    getFile: async objectKey => {
      const response = await request(objectUrl(objectKey), { headers: { Accept: 'text/plain' } });
      return response.text();
    },
  };
}
module.exports = { createSupabaseEnv };
