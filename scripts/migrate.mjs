#!/usr/bin/env node
// =====================================================
// scripts/migrate.mjs
// Supabase DB에 마이그레이션 자동 적용
//
// 사용법:
//   1) .env 에 SUPABASE_DB_URL 채움
//      위치: Supabase Dashboard > Project Settings > Database > Connection string > URI
//   2) cd scripts && npm install
//   3) node migrate.mjs
//
// 동작:
//   - public._migrations 테이블로 적용 이력 트래킹
//   - 첫 실행에서 'branches' 테이블 존재하면 0001-0004 백필 (기존 적용분 인정)
//   - 미적용 파일만 실행, 성공 시 _migrations에 기록
//   - all-in-one.sql 은 무시 (개별 파일들과 중복)
// =====================================================

import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));
const migrationsDir = resolve(here, '..', 'supabase', 'migrations');

// .env 로드 (간이 파서)
async function loadEnv() {
  try {
    const envPath = resolve(here, '..', '.env');
    const txt = await readFile(envPath, 'utf8');
    for (const line of txt.split('\n')) {
      const m = line.match(/^([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$/);
      if (m && !process.env[m[1]]) {
        process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
      }
    }
  } catch {}
}
await loadEnv();

const url = process.env.SUPABASE_DB_URL;
if (!url || url.includes('YOUR_')) {
  console.error('✗ SUPABASE_DB_URL 미설정');
  process.exit(1);
}

const isLocal = /(localhost|127\.0\.0\.1|\/var\/run\/postgresql)/.test(url);
const client = new pg.Client({
  connectionString: url,
  ssl: isLocal ? false : { rejectUnauthorized: false },
});

console.log('▶ Supabase DB 연결 중...');
await client.connect();
console.log('  ✓ 연결됨');

// 1) 트래킹 테이블 보장
await client.query(`
  CREATE TABLE IF NOT EXISTS public._migrations (
    filename text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT NOW()
  );
`);

// 2) 백필: 첫 실행 + 'branches' 존재하면 0001-0004 적용된 것으로 기록
const trackedRes = await client.query('SELECT filename FROM public._migrations');
const tracked = new Set(trackedRes.rows.map(r => r.filename));

if (tracked.size === 0) {
  const exists = await client.query(
    `SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='branches'`
  );
  if (exists.rows.length > 0) {
    const knownApplied = [
      '0001_schema.sql',
      '0002_helpers_and_auth.sql',
      '0003_rls.sql',
      '0004_seed.sql',
    ];
    for (const f of knownApplied) {
      await client.query(
        `INSERT INTO public._migrations (filename) VALUES ($1) ON CONFLICT DO NOTHING`,
        [f]
      );
      tracked.add(f);
    }
    console.log(`  ✓ 백필: 기존 적용분 ${knownApplied.length}개 인정`);
  }
}

// 3) 파일 목록 (사전순)
const files = (await readdir(migrationsDir))
  .filter(f => f.endsWith('.sql') && f !== 'all-in-one.sql')
  .sort();

console.log(`▶ 발견된 마이그레이션 ${files.length}개`);
console.log('');

let appliedCount = 0;
let failed = false;

for (const f of files) {
  if (tracked.has(f)) {
    console.log(`▶ ${f} (이미 적용됨, 스킵)`);
    continue;
  }
  process.stdout.write(`▶ ${f} 실행 중...`);
  const sql = await readFile(join(migrationsDir, f), 'utf8');
  try {
    await client.query(sql);
    await client.query(
      `INSERT INTO public._migrations (filename) VALUES ($1)`,
      [f]
    );
    console.log(' ✓');
    appliedCount++;
  } catch (e) {
    console.log(' ✗');
    console.error(`  에러: ${e.message}`);
    failed = true;
    break;
  }
}

await client.end();

if (failed) {
  console.error('\n✗ 마이그레이션 실패');
  process.exit(1);
}

console.log(`\n✓ 완료. 새로 적용: ${appliedCount}개 / 전체: ${files.length}개`);
