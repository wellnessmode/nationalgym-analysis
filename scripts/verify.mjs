#!/usr/bin/env node
// =====================================================
// scripts/verify.mjs
// Supabase DB에 마이그레이션이 제대로 적용됐는지 검증
//
// 사용법: cd scripts && node verify.mjs
// 사전 조건: .env 의 SUPABASE_DB_URL 채워짐
// =====================================================

import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));

async function loadEnv() {
  try {
    const txt = await readFile(resolve(here, '..', '.env'), 'utf8');
    for (const line of txt.split('\n')) {
      const m = line.match(/^([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$/);
      if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  } catch {}
}
await loadEnv();

const url = process.env.SUPABASE_DB_URL;
if (!url || url.includes('YOUR_')) {
  console.error('✗ SUPABASE_DB_URL 미설정');
  process.exit(1);
}

const client = new pg.Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await client.connect();

const checks = [
  {
    name: '테이블 8개',
    sql: `SELECT COUNT(*)::int AS n FROM pg_tables WHERE schemaname='public'`,
    expect: r => r.rows[0].n === 8,
  },
  {
    name: 'RLS 8개 테이블 모두 활성',
    sql: `SELECT COUNT(*)::int AS n FROM pg_tables WHERE schemaname='public' AND rowsecurity=true`,
    expect: r => r.rows[0].n === 8,
  },
  {
    name: '정책 20개 이상',
    sql: `SELECT COUNT(*)::int AS n FROM pg_policies WHERE schemaname='public'`,
    expect: r => r.rows[0].n >= 20,
  },
  {
    name: '헬퍼 함수 5개 (current_user_id, is_admin, user_has_branch, set_updated_at, handle_new_auth_user)',
    sql: `SELECT COUNT(*)::int AS n FROM pg_proc WHERE pronamespace='public'::regnamespace
          AND proname IN ('current_user_id','is_admin','user_has_branch','set_updated_at','handle_new_auth_user')`,
    expect: r => r.rows[0].n === 5,
  },
  {
    name: 'auth.users INSERT 트리거 존재',
    sql: `SELECT COUNT(*)::int AS n FROM pg_trigger WHERE tgname='on_auth_user_created'`,
    expect: r => r.rows[0].n === 1,
  },
  {
    name: '지점 3개 (용산·서초·스튜디오)',
    sql: `SELECT name FROM branches ORDER BY name`,
    expect: r => r.rows.length === 3 && r.rows.every(x => x.name.startsWith('내셔널짐')),
  },
  {
    name: '사용자 3명 (admin 1 + manager 2)',
    sql: `SELECT COUNT(*) FILTER (WHERE role='admin')::int AS admins,
                 COUNT(*) FILTER (WHERE role='manager')::int AS managers FROM users`,
    expect: r => r.rows[0].admins === 1 && r.rows[0].managers === 2,
  },
  {
    name: '정인재 → 용산+서초 매핑',
    sql: `SELECT COUNT(*)::int AS n FROM user_branches ub
          JOIN users u ON u.id=ub.user_id
          WHERE u.email='manager.jung@nationalgym.local'`,
    expect: r => r.rows[0].n === 2,
  },
  {
    name: '김근희 → 스튜디오 매핑',
    sql: `SELECT COUNT(*)::int AS n FROM user_branches ub
          JOIN users u ON u.id=ub.user_id
          WHERE u.email='manager.kim@nationalgym.local'`,
    expect: r => r.rows[0].n === 1,
  },
];

let pass = 0, fail = 0;
for (const c of checks) {
  try {
    const r = await client.query(c.sql);
    if (c.expect(r)) {
      console.log(`  ✓ ${c.name}`);
      pass++;
    } else {
      console.log(`  ✗ ${c.name}`);
      console.log(`    실제:`, r.rows);
      fail++;
    }
  } catch (e) {
    console.log(`  ✗ ${c.name} — 쿼리 에러: ${e.message}`);
    fail++;
  }
}

await client.end();
console.log(`\n결과: ${pass} pass, ${fail} fail`);
process.exit(fail > 0 ? 1 : 0);
