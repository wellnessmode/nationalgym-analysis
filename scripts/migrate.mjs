#!/usr/bin/env node
// =====================================================
// scripts/migrate.mjs
// Supabase DB에 마이그레이션 자동 적용
//
// 사용법:
//   1) .env 에 SUPABASE_DB_URL 채움
//      위치: Supabase Dashboard > Project Settings > Database > Connection string > URI (transaction)
//   2) cd scripts && npm install
//   3) node migrate.mjs
//
// 기능:
//   - supabase/migrations/ 안의 .sql 파일을 사전순으로 실행
//   - 각 파일은 자체 BEGIN/COMMIT 트랜잭션 (실패 시 그 파일만 롤백)
//   - all-in-one.sql 은 무시 (개별 파일들과 중복)
// =====================================================

import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));
const migrationsDir = resolve(here, '..', 'supabase', 'migrations');

// .env 로드 (간이 파서. dotenv 안 깔아도 동작)
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
  console.error('✗ SUPABASE_DB_URL 미설정 (.env 파일 확인)');
  console.error('  Supabase Dashboard > Project Settings > Database');
  console.error('  > Connection string > URI (transaction) 값 복사해서 채울 것');
  process.exit(1);
}

// localhost 는 SSL 안 씀, Supabase 등 원격은 SSL (자가서명 허용)
const isLocal = /(localhost|127\.0\.0\.1|\/var\/run\/postgresql)/.test(url);
const client = new pg.Client({
  connectionString: url,
  ssl: isLocal ? false : { rejectUnauthorized: false },
});

console.log('▶ Supabase DB 연결 중...');
await client.connect();
console.log('  ✓ 연결됨');

const files = (await readdir(migrationsDir))
  .filter(f => f.endsWith('.sql') && f !== 'all-in-one.sql')
  .sort();

console.log(`▶ 마이그레이션 ${files.length}개 발견:`);
for (const f of files) console.log(`  - ${f}`);
console.log('');

let failed = false;
for (const f of files) {
  process.stdout.write(`▶ ${f} 실행 중...`);
  const sql = await readFile(join(migrationsDir, f), 'utf8');
  try {
    await client.query(sql);
    console.log(' ✓');
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

console.log('\n✓ 모든 마이그레이션 적용 완료');
console.log('  다음: Supabase Dashboard > Authentication > Users 에서 3개 계정 수동 추가');
console.log('    - admin@nationalgym.local');
console.log('    - manager.jung@nationalgym.local');
console.log('    - manager.kim@nationalgym.local');
