// =====================================================
// Edge Function: cleanup-memo
// 메모 raw 텍스트(음성 인식 결과 또는 직접 입력) → Gemini 로 정리
//
// Request body: { text: string }
// Response: { ok: true, text: string }
//
// 환경변수: GEMINI_API_KEY
// =====================================================

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');

interface Req {
  text: string;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
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
  const text = (body.text || '').trim();
  if (text.length < 5) {
    return new Response(
      JSON.stringify({ error: 'text too short' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const prompt = `다음은 사용자가 음성으로 녹음하거나 빠르게 입력한 메모 원문입니다(한국어).
음성 인식이라 오타·끊김이 있을 수 있습니다.

읽기 좋은 메모 형식으로 정리해주세요:
- 제일 위는 한 줄짜리 핵심 제목 (이모지나 마크다운 X)
- 그 아래 핵심 내용을 짧은 문장 / 글머리기호로 정리
- 중복·말끝 흐림·"음… 어…" 같은 군말 제거
- 누가 / 언제 / 무엇 / 어디 같은 핵심 정보가 있으면 살리기
- 너무 형식적으로 만들지 말고 자연스러운 메모톤 유지
- 원문에 없는 정보 추가 X

원문:
${text}`;

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
              properties: { text: { type: 'string' } },
              required: ['text'],
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
    const out = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!out) {
      return new Response(
        JSON.stringify({ error: 'empty gemini response' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      );
    }
    const parsed = JSON.parse(out);
    return new Response(
      JSON.stringify({ ok: true, text: parsed.text || '' }),
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
