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

const isLocal = /(localhost|127\.0\.0\.1|\/var\/run\/postgresql)/.test(url);
const client = new pg.Client({
  connectionString: url,
  ssl: isLocal ? false : { rejectUnauthorized: false },
});
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
          WHERE u.name='정인재'`,
    expect: r => r.rows[0].n === 2,
  },
  {
    name: '김근희 → 스튜디오 매핑',
    sql: `SELECT COUNT(*)::int AS n FROM user_branches ub
          JOIN users u ON u.id=ub.user_id
          WHERE u.name='김근희'`,
    expect: r => r.rows[0].n === 1,
  },
  {
    name: '3명 모두 auth.users 와 링크됨 (auth_user_id NOT NULL)',
    sql: `SELECT COUNT(*)::int AS n FROM users WHERE auth_user_id IS NOT NULL`,
    expect: r => r.rows[0].n === 3,
  },
];

let pass = 0, fail = 0;
const lines = [];
for (const c of checks) {
  try {
    const r = await client.query(c.sql);
    if (c.expect(r)) {
      console.log(`  ✓ ${c.name}`);
      lines.push(`✓ ${c.name}`);
      pass++;
    } else {
      const actual = JSON.stringify(r.rows);
      console.log(`  ✗ ${c.name}`);
      console.log(`    실제:`, r.rows);
      lines.push(`✗ ${c.name}\n    실제: ${actual}`);
      fail++;
    }
  } catch (e) {
    console.log(`  ✗ ${c.name} — 쿼리 에러: ${e.message}`);
    lines.push(`✗ ${c.name} — 쿼리 에러: ${e.message}`);
    fail++;
  }
}

// 추가 진단: users + auth.users 현재 상태 덤프
let dump = '';
try {
  const u = await client.query(`SELECT email, name, role, auth_user_id IS NOT NULL AS linked FROM users ORDER BY role, email`);
  dump += '\n\n## public.users 현재 상태\n' + JSON.stringify(u.rows, null, 2);
  const a = await client.query(`SELECT email, id FROM auth.users ORDER BY email`);
  dump += '\n\n## auth.users 현재 상태\n' + JSON.stringify(a.rows.map(r => ({ email: r.email, id: r.id.slice(0, 8) + '...' })), null, 2);
} catch (e) {
  dump += '\n\n## dump 실패: ' + e.message;
}

await client.end();
console.log(`\n결과: ${pass} pass, ${fail} fail`);

// commit comment 발행 (실패 시)
if (fail > 0) {
  const ghToken = process.env.GH_TOKEN_FOR_COMMENTS || process.env.GITHUB_TOKEN;
  const ghRepo = process.env.GITHUB_REPOSITORY;
  const ghSha = process.env.GITHUB_SHA;
  if (ghToken && ghRepo && ghSha) {
    try {
      const body = '## Verify failed\n\n' + lines.join('\n') + dump;
      await fetch(`https://api.github.com/repos/${ghRepo}/commits/${ghSha}/comments`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${ghToken}`,
          Accept: 'application/vnd.github+json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ body }),
      });
      console.log('(verify result posted as commit comment)');
    } catch (e) {
      console.log('(failed to post: ' + e.message + ')');
    }
  }
}

process.exit(fail > 0 ? 1 : 0);
