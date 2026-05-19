// =====================================================
// Edge Function: cleanup-meeting
// 회의 음성 인식 결과 (raw transcript) → Gemini로 회의록 형식으로 정리
//
// Request body: { meeting_note_id: string, transcript: string }
// Response: { ok: true, content: string, action_items: string }
//
// 무료 한도: Gemini 1.5 Flash — 15 RPM, 1500 RPD, 1M tokens/day
// 환경변수: GEMINI_API_KEY (Google AI Studio https://aistudio.google.com/app/apikey 에서 무료 발급)
// =====================================================

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');

interface Req {
  meeting_note_id?: string;
  transcript: string;
}

/// JWT role 검증 — anon key 로 호출 시 차단 (Gemini API 비용 abuse 방지)
function requireAuthenticated(req: Request): Response | null {
  const auth = req.headers.get('Authorization');
  if (!auth || !auth.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401, headers: { 'Content-Type': 'application/json' },
    });
  }
  try {
    const payloadB64 = auth.substring(7).split('.')[1];
    const payload = JSON.parse(atob(payloadB64.replace(/-/g, '+').replace(/_/g, '/')));
    if (payload.role !== 'authenticated') {
      return new Response(JSON.stringify({ error: 'forbidden — login required' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }
    return null;
  } catch (_) {
    return new Response(JSON.stringify({ error: 'invalid token' }), {
      status: 401, headers: { 'Content-Type': 'application/json' },
    });
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const authErr = requireAuthenticated(req);
  if (authErr) return authErr;
  if (!GEMINI_API_KEY) {
    return new Response(
      JSON.stringify({ error: 'GEMINI_API_KEY not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  let body: Req;
  try {
    body = await req.json();
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }
  const transcript = (body.transcript || '').trim();
  if (transcript.length < 10) {
    return new Response(
      JSON.stringify({ error: 'transcript too short' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const prompt = `다음은 회의 음성 인식 결과(한국어)입니다. 음성 인식이라 일부 오타나 끊김이 있을 수 있습니다.

이를 구조화된 회의록으로 정리해주세요:
- "content": 회의 내용·논의 사항·결정 사항을 마크다운 형식으로. 핵심 위주로 요약하되 중요 발언은 보존. 불필요한 반복 제거.
- "action_items": 후속 조치/할 일을 마크다운 체크리스트(- [ ] 형식)로. 없으면 빈 문자열.

원본 발화를 그대로 옮기지 말고 핵심을 정리하세요. 누락된 맥락은 자연스럽게 보완.

음성 인식 결과:
${transcript}`;

  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.3,
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'object',
              properties: {
                content: { type: 'string' },
                action_items: { type: 'string' },
              },
              required: ['content', 'action_items'],
            },
          },
        }),
      },
    );

    if (!res.ok) {
      const errText = await res.text();
      console.error('gemini api error', res.status, errText);
      return new Response(
        JSON.stringify({ error: 'gemini api error', status: res.status, detail: errText }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      );
    }

    const data = await res.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      return new Response(
        JSON.stringify({ error: 'empty gemini response', detail: JSON.stringify(data).slice(0, 500) }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      );
    }

    const parsed = JSON.parse(text);
    return new Response(
      JSON.stringify({
        ok: true,
        content: parsed.content || '',
        action_items: parsed.action_items || '',
      }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('cleanup error', e);
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
