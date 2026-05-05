#!/usr/bin/env node
// =====================================================
// mgmt-migrate.mjs
// Supabase Management API 를 통해 마이그레이션 적용.
// DB 비밀번호 인증을 우회 — Personal Access Token 만 사용.
//
// 환경변수:
//   SUPABASE_ACCESS_TOKEN  Supabase Personal Access Token (sbp_...)
//   SUPABASE_PROJECT_REF   프로젝트 ref (예: bcvqcwgwjodofoapynyu)
//
// migrate.mjs 와 동일하게 _migrations 테이블로 idempotent 트래킹.
// =====================================================

import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const migrationsDir = resolve(here, '..', 'supabase', 'migrations');

const TOKEN = process.env.SUPABASE_ACCESS_TOKEN;
const PROJECT_REF = process.env.SUPABASE_PROJECT_REF;
if (!TOKEN || !PROJECT_REF) {
  console.error('✗ SUPABASE_ACCESS_TOKEN + SUPABASE_PROJECT_REF 둘 다 필요');
  process.exit(1);
}

const API = `https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`;

async function runSql(sql, { allowError = false } = {}) {
  const res = await fetch(API, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  const text = await res.text();
  if (!res.ok) {
    if (allowError) return { error: text, status: res.status };
    throw new Error(`API ${res.status}: ${text.slice(0, 800)}`);
  }
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function reportFatal(stage, e) {
  const report = `Migration FATAL at ${stage}
Message: ${e?.message || String(e)}
Stack: ${(e?.stack || '').split('\n').slice(0, 4).join(' | ')}`;
  console.error(report);
  const ghToken = process.env.GH_TOKEN_FOR_COMMENTS || process.env.GITHUB_TOKEN;
  const ghRepo = process.env.GITHUB_REPOSITORY;
  const ghSha = process.env.GITHUB_SHA;
  if (ghToken && ghRepo && ghSha) {
    try {
      await fetch(`https://api.github.com/repos/${ghRepo}/commits/${ghSha}/comments`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${ghToken}`,
          Accept: 'application/vnd.github+json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ body: '## Migration error (mgmt-api)\n\n```\n' + report + '\n```' }),
      });
    } catch (_) {}
  }
}

async function main() {
  console.log('▶ Supabase Management API 연결 중...');
  const ping = await runSql(`SELECT 'ok' AS ping`);
  console.log(`  ✓ 연결 OK (응답: ${JSON.stringify(ping).slice(0, 60)})`);

  console.log('▶ _migrations 테이블 보장...');
  await runSql(`
    CREATE TABLE IF NOT EXISTS public._migrations (
      filename text PRIMARY KEY,
      applied_at timestamptz NOT NULL DEFAULT NOW()
    );
  `);

  const trackedRes = await runSql('SELECT filename FROM public._migrations');
  const tracked = new Set((Array.isArray(trackedRes) ? trackedRes : []).map(r => r.filename));
  console.log(`  ✓ 적용된 마이그레이션: ${tracked.size}`);

  // 0001~0008 자동 마킹 (raw schema 가 이미 있으면)
  if (tracked.size === 0) {
    const exists = await runSql(
      `SELECT 1 AS x FROM pg_tables WHERE schemaname='public' AND tablename='branches' LIMIT 1`
    );
    if (Array.isArray(exists) && exists.length > 0) {
      const known = [
        '0001_schema.sql',
        '0002_helpers_and_auth.sql',
        '0003_rls.sql',
        '0004_seed.sql',
        '0005_update_emails.sql',
        '0006_notification_triggers.sql',
        '0007_cron_due_reminder.sql',
        '0008_relink_users.sql',
      ];
      for (const f of known) {
        await runSql(`INSERT INTO public._migrations (filename) VALUES ('${f}') ON CONFLICT DO NOTHING`);
        tracked.add(f);
      }
      console.log(`  ✓ 기존 스키마 감지 — 0001~0008 자동 마킹`);
    }
  }

  const files = (await readdir(migrationsDir))
    .filter(f => /^\d{4}.*\.sql$/.test(f))
    .sort();

  let applied = 0;
  for (const f of files) {
    if (tracked.has(f)) continue;
    const sql = await readFile(join(migrationsDir, f), 'utf8');
    console.log(`▶ 적용 중: ${f} (${sql.length} bytes)`);
    try {
      await runSql(sql);
      await runSql(
        `INSERT INTO public._migrations (filename) VALUES ('${f.replace(/'/g, "''")}') ON CONFLICT DO NOTHING`
      );
      console.log(`  ✓ ${f}`);
      applied++;
    } catch (e) {
      await reportFatal(`apply ${f}`, e);
      throw e;
    }
  }

  console.log(`\n✅ 완료. 새로 적용: ${applied}, 기존: ${tracked.size}`);
}

try {
  await main();
} catch (e) {
  await reportFatal('main', e);
  process.exit(1);
}
