// =====================================================
// Edge Function: due-reminder
// 매일 오전 9시 (KST) cron으로 호출.
// D-1 (내일 마감), D-day (오늘 마감), D+ (경과) 업무에 대한 푸시 발송.
// 경과는 담당자 + 대표 양쪽 모두 알림.
//
// Cron 설정 (Supabase Dashboard > Edge Functions > Cron Jobs):
//   schedule: "0 0 * * *"  (UTC 자정 = KST 오전 9시)
//   function: due-reminder
// =====================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

const FCM_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!;
const SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!);

// ── OAuth & FCM (notify와 동일) ─────────────────────────────────────

let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now()) return cachedToken.token;

  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: SERVICE_ACCOUNT.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const enc = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const header = enc({ alg: 'RS256', typ: 'JWT' });
  const payload = enc(claim);
  const unsigned = `${header}.${payload}`;
  const pem = SERVICE_ACCOUNT.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8', der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign']
  );
  const sigBuf = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const jwt = `${unsigned}.${sigB64}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`OAuth: ${res.status}`);
  const j = await res.json();
  cachedToken = { token: j.access_token, expiresAt: Date.now() + (j.expires_in - 60) * 1000 };
  return cachedToken.token;
}

async function sendFcm(fcmToken: string, title: string, body: string, data: Record<string, string>) {
  const accessToken = await getAccessToken();
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data,
          webpush: {
            fcm_options: { link: '/' },
            notification: { icon: '/icons/Icon-192.png' },
          },
        },
      }),
    }
  );
  if (!res.ok) console.error(`FCM ${res.status}: ${await res.text()}`);
}

async function notify(uids: string[], title: string, body: string, type: string, refId: string) {
  const unique = [...new Set(uids.filter(Boolean))];
  if (unique.length === 0) return;
  const { data: users } = await supabase
    .from('users')
    .select('id, fcm_token')
    .in('id', unique);

  for (const u of users || []) {
    await supabase.from('notifications').insert({
      user_id: u.id, ref_type: 'task', ref_id: refId, type, message: `${title}: ${body}`,
    });
    if (u.fcm_token) await sendFcm(u.fcm_token, title, body, { ref_type: 'task', ref_id: refId, type });
  }
}

// ── Main: due-soon / overdue 업무 조회 후 알림 ───────────────────────

Deno.serve(async (_req) => {
  try {
    // KST 기준 오늘 날짜 (UTC + 9h offset)
    const nowUtc = new Date();
    const kst = new Date(nowUtc.getTime() + 9 * 3600 * 1000);
    const today = kst.toISOString().split('T')[0];
    const tomorrow = new Date(kst.getTime() + 24 * 3600 * 1000).toISOString().split('T')[0];

    // 활성 업무만 (done/on_hold 제외)
    const { data: tasks } = await supabase
      .from('tasks')
      .select('id, title, due_date, status, assignee_id, requester_id')
      .in('status', ['todo', 'in_progress'])
      .not('due_date', 'is', null);

    const { data: admins } = await supabase.from('users').select('id').eq('role', 'admin');
    const adminIds = (admins || []).map((a: { id: string }) => a.id);

    let sentCount = 0;

    for (const t of tasks || []) {
      if (!t.due_date) continue;
      const due = t.due_date;
      if (due === tomorrow) {
        // D-1
        await notify([t.assignee_id], '내일 마감', t.title, 'due_soon', t.id);
        sentCount++;
      } else if (due === today) {
        // D-day
        await notify([t.assignee_id], '오늘 마감', t.title, 'due_soon', t.id);
        sentCount++;
      } else if (due < today) {
        // 경과 — 담당자 + 대표
        const days = Math.floor(
          (Date.parse(today) - Date.parse(due)) / (24 * 3600 * 1000)
        );
        await notify(
          [t.assignee_id, ...adminIds],
          `${days}일 경과`,
          t.title, 'overdue', t.id,
        );
        sentCount++;
      }
    }

    return new Response(
      JSON.stringify({ ok: true, today, sent: sentCount, total: (tasks || []).length }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('due-reminder error:', e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { 'Content-Type': 'application/json' },
    });
  }
});
