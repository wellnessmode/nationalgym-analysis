// =====================================================
// Edge Function: notify
// DB 트리거가 호출 → 알림 대상 결정 → FCM 발송 + notifications 테이블 기록
//
// Request body:
// {
//   event: 'task_created' | 'task_completed' | 'task_commented'
//        | 'meeting_created' | 'meeting_status_changed' | 'meeting_commented',
//   record: { ... new row ... },
//   old?: { ... old row, for UPDATE ... }
// }
//
// 환경변수 (Supabase Dashboard > Edge Functions > notify > Secrets 에서 설정):
//   SUPABASE_URL                    (자동 제공됨)
//   SUPABASE_SERVICE_ROLE_KEY       (자동 제공됨)
//   FIREBASE_PROJECT_ID             (사용자 설정 — Firebase 프로젝트 ID)
//   FIREBASE_SERVICE_ACCOUNT        (사용자 설정 — service account JSON 통째)
// =====================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface NotifyPayload {
  event: string;
  record: Record<string, unknown>;
  old?: Record<string, unknown>;
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

const FCM_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!;
const SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!);

// ── FCM HTTP v1: OAuth 토큰 발급 ─────────────────────────────────────

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

  // private_key 는 PEM 형식. importKey + sign.
  const pem = SERVICE_ACCOUNT.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const sigBuf = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned)
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const jwt = `${unsigned}.${sigB64}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!tokenRes.ok) throw new Error(`OAuth token: ${tokenRes.status} ${await tokenRes.text()}`);
  const tokenJson = await tokenRes.json();
  cachedToken = {
    token: tokenJson.access_token,
    expiresAt: Date.now() + (tokenJson.expires_in - 60) * 1000,
  };
  return cachedToken.token;
}

async function sendFcm(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<number> {
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
  if (!res.ok) {
    console.error(`FCM send failed: ${res.status} ${await res.text()}`);
  }
  return res.status;
}

// ── 사용자 정보 헬퍼 ─────────────────────────────────────────────────

async function getUser(userId: string) {
  const { data } = await supabase.from('users').select('*').eq('id', userId).maybeSingle();
  return data;
}

async function getBranchName(branchId: string) {
  const { data } = await supabase.from('branches').select('name').eq('id', branchId).maybeSingle();
  return data?.name || '?';
}

async function notifyUsers(
  userIds: string[],
  title: string,
  body: string,
  refType: string,
  refId: string,
  type: string,
) {
  // 직렬 await → Promise.allSettled 병렬 — 5명 대상 시 5x 빨라짐.
  const uniq = [...new Set(userIds.filter(Boolean))];
  await Promise.allSettled(uniq.map(async (uid) => {
    const user = await getUser(uid);
    if (!user) return;

    // 앱 내 알림 row + FCM push 도 병렬
    await Promise.allSettled([
      supabase.from('notifications').insert({
        user_id: uid,
        ref_type: refType,
        ref_id: refId,
        type,
        message: `${title}: ${body}`,
      }),
      user.fcm_token
        ? sendFcm(user.fcm_token, title, body, { ref_type: refType, ref_id: refId, type })
            .then(async (status) => {
              // 404 (UNREGISTERED) / 410 (NotFound) → 토큰 만료 → DB 정리
              if (status === 404 || status === 410) {
                await supabase.from('users').update({ fcm_token: null }).eq('id', uid);
              }
            })
        : Promise.resolve(),
    ]);
  }));
}

// ── 이벤트 핸들러 ─────────────────────────────────────────────────────

async function handle(payload: NotifyPayload) {
  const { event, record, old } = payload;

  switch (event) {
    case 'task_created': {
      // 대표가 directive 만들면 매니저(assignee)에게 알림
      if (record.task_type !== 'directive') break;
      const branchName = await getBranchName(record.branch_id as string);
      await notifyUsers(
        [record.assignee_id as string],
        '새 업무 할당',
        `[${branchName}] ${record.title}`,
        'task',
        record.id as string,
        'assigned',
      );
      break;
    }
    case 'task_completed': {
      // status 가 done 으로 바뀐 경우만
      if (old?.status === 'done' || record.status !== 'done') break;
      // 본인이 본인 자체 업무 완료 시 자가 알림 차단
      if (record.requester_id === record.assignee_id) break;
      const assignee = await getUser(record.assignee_id as string);
      await notifyUsers(
        [record.requester_id as string],
        '업무 완료',
        `${assignee?.name || ''}: ${record.title}`,
        'task',
        record.id as string,
        'completed',
      );
      break;
    }
    case 'task_commented': {
      // task 의 requester + assignee 양쪽에게 알림 (작성자 제외)
      const { data: task } = await supabase
        .from('tasks')
        .select('title, requester_id, assignee_id')
        .eq('id', record.task_id as string)
        .maybeSingle();
      if (!task) break;
      const author = await getUser(record.user_id as string);
      const recipients = [task.requester_id, task.assignee_id].filter(
        (uid) => uid && uid !== record.user_id
      );
      await notifyUsers(
        recipients,
        '업무 댓글',
        `${author?.name || ''}: ${task.title}`,
        'task_comment',
        record.id as string,
        'commented',
      );
      break;
    }
    case 'meeting_created': {
      // draft 면 어젠다, completed 면 회의 결과 알림 — 모두 admin에게 (단, 작성자 제외)
      const isCompleted = record.status === 'completed';
      const branchName = await getBranchName(record.branch_id as string);
      const author = await getUser(record.author_id as string);
      const { data: admins } = await supabase.from('users').select('id').eq('role', 'admin');
      const recipients = (admins || [])
        .map((a: { id: string }) => a.id)
        .filter((id) => id !== record.author_id);
      await notifyUsers(
        recipients,
        isCompleted ? '회의록 완료' : '새 어젠다',
        `[${branchName}/${author?.name || ''}] ${record.topic}`,
        'meeting_note',
        record.id as string,
        isCompleted ? 'meeting_completed' : 'new_meeting_agenda',
      );
      break;
    }
    case 'meeting_status_changed': {
      // draft → completed 전환 시 admin 알림 (단, 작성자 제외)
      if (old?.status !== 'draft' || record.status !== 'completed') break;
      const branchName = await getBranchName(record.branch_id as string);
      const author = await getUser(record.author_id as string);
      const { data: admins } = await supabase.from('users').select('id').eq('role', 'admin');
      const recipients = (admins || [])
        .map((a: { id: string }) => a.id)
        .filter((id) => id !== record.author_id);
      await notifyUsers(
        recipients,
        '회의록 완료',
        `[${branchName}/${author?.name || ''}] ${record.topic}`,
        'meeting_note',
        record.id as string,
        'meeting_completed',
      );
      break;
    }
    case 'meeting_commented': {
      const { data: meeting } = await supabase
        .from('meeting_notes')
        .select('topic, author_id')
        .eq('id', record.meeting_note_id as string)
        .maybeSingle();
      if (!meeting) break;
      // 회의록 작성자 + 모든 admin 에게 알림 (단, 댓글 작성자 본인 제외)
      const author = await getUser(record.user_id as string);
      const { data: admins } = await supabase.from('users').select('id').eq('role', 'admin');
      const allRecipients = new Set<string>();
      if (meeting.author_id) allRecipients.add(meeting.author_id as string);
      for (const a of (admins || []) as Array<{ id: string }>) {
        allRecipients.add(a.id);
      }
      allRecipients.delete(record.user_id as string); // 댓글 작성자 제외
      await notifyUsers(
        Array.from(allRecipients),
        '회의록 댓글',
        `${author?.name || ''}: ${meeting.topic}`,
        'meeting_comment',
        record.id as string,
        'commented',
      );
      break;
    }
  }
}

// ── HTTP entry point ─────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }
  try {
    const payload = (await req.json()) as NotifyPayload;
    await handle(payload);
    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('notify error:', e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
