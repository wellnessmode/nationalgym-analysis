#!/usr/bin/env node
// Set GitHub Action secrets via API.
// Usage: GH_TOKEN=ghp_... node set-secret.mjs <SECRET_NAME> <SECRET_VALUE>
// or pipe many: cat secrets.env | node set-secret.mjs --stdin

import sodium from 'libsodium-wrappers';

const REPO_OWNER = 'wellnessmode';
const REPO_NAME = 'nationalgym-analysis';
const TOKEN = process.env.GH_TOKEN;
if (!TOKEN) { console.error('GH_TOKEN env var required'); process.exit(1); }

await sodium.ready;

async function getPublicKey() {
  const r = await fetch(`https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/secrets/public-key`, {
    headers: { Authorization: `Bearer ${TOKEN}`, Accept: 'application/vnd.github+json' }
  });
  if (!r.ok) throw new Error(`get public-key: ${r.status} ${await r.text()}`);
  return r.json();
}

function encrypt(value, pubKeyBase64) {
  const pubKey = sodium.from_base64(pubKeyBase64, sodium.base64_variants.ORIGINAL);
  const msg = sodium.from_string(value);
  const cipher = sodium.crypto_box_seal(msg, pubKey);
  return sodium.to_base64(cipher, sodium.base64_variants.ORIGINAL);
}

async function setSecret(name, value, pk) {
  const encrypted_value = encrypt(value, pk.key);
  const r = await fetch(`https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/secrets/${name}`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ encrypted_value, key_id: pk.key_id })
  });
  if (!r.ok) throw new Error(`set ${name}: ${r.status} ${await r.text()}`);
  return r.status;
}

const args = process.argv.slice(2);
const pk = await getPublicKey();

if (args[0] === '--stdin') {
  const buf = await new Promise(res => {
    let s = '';
    process.stdin.on('data', d => s += d);
    process.stdin.on('end', () => res(s));
  });
  const lines = buf.split('\n').map(l => l.trim()).filter(l => l && !l.startsWith('#'));
  for (const line of lines) {
    const eq = line.indexOf('=');
    if (eq < 0) continue;
    const k = line.slice(0, eq).trim();
    const v = line.slice(eq + 1).trim();
    if (!k || !v) continue;
    const status = await setSecret(k, v, pk);
    console.log(`  ✓ ${k}  (HTTP ${status})`);
  }
} else if (args.length === 2) {
  const status = await setSecret(args[0], args[1], pk);
  console.log(`✓ ${args[0]}  (HTTP ${status})`);
} else {
  console.error('Usage:\n  GH_TOKEN=... node set-secret.mjs <NAME> <VALUE>\n  cat env.txt | GH_TOKEN=... node set-secret.mjs --stdin');
  process.exit(1);
}
