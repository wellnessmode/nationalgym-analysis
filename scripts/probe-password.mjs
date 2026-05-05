#!/usr/bin/env node
// 여러 비밀번호 후보를 빠르게 시도해 어느 게 서버에 등록되어 있는지 찾기.
// 5초 timeout, 동시 1개만 시도 (Supabase rate limit 회피).

import pg from 'pg';

const HOST = 'aws-1-ap-northeast-1.pooler.supabase.com';
const PORT = 5432;
const USER = 'postgres.bcvqcwgwjodofoapynyu';
const DB = 'postgres';

const candidates = [
  'Gkqrleh1@#',
  'Gkqrleheheh!@#',
  'NgWorkspace2026Strong',
  'BFmi3ZYRyhWKV0dQ',
  'NgwSafe2026',
  'pwd12345',
  'password123',
  // 대소문자/공백 변형
  'NgWorkspace2026Strong ',
  ' NgWorkspace2026Strong',
  'NgWorkspace2026strong',
  'ngworkspace2026strong',
];

async function tryPassword(pw) {
  const client = new pg.Client({
    host: HOST, port: PORT, user: USER, database: DB, password: pw,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 5000,
    statement_timeout: 5000,
  });
  try {
    await client.connect();
    await client.query('SELECT 1');
    await client.end();
    return { ok: true };
  } catch (e) {
    try { await client.end(); } catch (_) {}
    return { ok: false, code: e.code, msg: e.message?.slice(0, 80) };
  }
}

console.log(`Testing ${candidates.length} password candidates against ${HOST}:${PORT}\n`);
let found = null;
for (const pw of candidates) {
  process.stdout.write(`  trying "${pw}" ... `);
  const r = await tryPassword(pw);
  if (r.ok) {
    console.log('✓ MATCH');
    found = pw;
    break;
  } else {
    console.log(`✗ ${r.code || ''}`);
  }
}
console.log();
if (found) {
  console.log(`✅ Working password found: "${found}"`);
  process.exit(0);
} else {
  console.log('❌ No candidate matched. Reset password and try fresh.');
  process.exit(1);
}
