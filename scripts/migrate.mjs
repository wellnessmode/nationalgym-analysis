#!/usr/bin/env node
import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));
const migrationsDir = resolve(here, '..', 'supabase', 'migrations');

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

async function reportFatal(stage, e) {
  const dbHost = (url.match(/@([^/:]+)/) || [])[1] || 'N/A';
  const dbUser = (url.match(/\/\/([^:]+):/) || [])[1] || 'N/A';
  const dbPort = (url.match(/:(\d+)\//) || [])[1] || 'N/A';
  const passLen = ((url.match(/:[^@]*@/) || [])[0] || '').length - 2;
  const report = `Migration FATAL at ${stage}
Code: ${e?.code || 'N/A'}
Message: ${e?.message || String(e)}
Detail: ${e?.detail || 'N/A'}
Where: ${e?.where || 'N/A'}
Errno: ${e?.errno || 'N/A'}
Stack snippet: ${(e?.stack || '').split('\n').slice(0, 4).join(' | ')}
DB host: ${dbHost}
DB user: ${dbUser}
DB port: ${dbPort}
Password length (encoded): ${passLen}`;
  console.error(report);
  const ghToken = process.env.GH_TOKEN_FOR_COMMENTS || process.env.GITHUB_TOKEN;
  const ghRepo = process.env.GITHUB_REPOSITORY;
  const ghSha = process.env.GITHUB_SHA;
  if (ghToken && ghRepo && ghSha) {
    try {
      const res = await fetch(`https://api.github.com/repos/${ghRepo}/commits/${ghSha}/comments`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${ghToken}`,
          Accept: 'application/vnd.github+json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ body: '## Migration error\n\n```\n' + report + '\n```' }),
      });
      console.error(`(commit comment POST: ${res.status})`);
      if (!res.ok) console.error(await res.text());
    } catch (postErr) {
      console.error('(commit comment failed: ' + postErr.message + ')');
    }
  } else {
    console.error(`(no comment posted: token=${!!ghToken} repo=${ghRepo} sha=${ghSha})`);
  }
}

async function main() {
  const client = new pg.Client({
    connectionString: url,
    ssl: isLocal ? false : { rejectUnauthorized: false },
  });

  console.log('▶ Supabase DB 연결 중...');
  await client.connect();
  console.log('  ✓ 연결됨');

  await client.query(`
    CREATE TABLE IF NOT EXISTS public._migrations (
      filename text PRIMARY KEY,
      applied_at timestamptz NOT NULL DEFAULT NOW()
    );
  `);

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

  const files = (await readdir(migrationsDir))
    .filter(f => f.endsWith('.sql') && f !== 'all-in-one.sql')
    .sort();

  console.log(`▶ 발견된 마이그레이션 ${files.length}개\n`);

  let appliedCount = 0;
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
      e.message = `[file: ${f}] ` + e.message;
      throw e;
    }
  }

  await client.end();
  console.log(`\n✓ 완료. 새로 적용: ${appliedCount}개 / 전체: ${files.length}개`);
}

main().catch(async (e) => {
  await reportFatal('main', e);
  process.exit(1);
});
