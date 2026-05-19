// =====================================================
// Edge Function: transcribe-audio
// MediaRecorder 로 녹음한 오디오 → Gemini 1.5 Flash 로 전사.
//
// Request body: { storage_path: string }
// Response: { ok: true, text: string }
//
// 무료: Gemini 1.5 Flash 15 RPM, 무료 티어 audio understanding 지원.
// =====================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');

interface Req {
  storage_path: string;
  mime_type?: string;
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
  const path = body.storage_path;
  const mime = body.mime_type || 'audio/webm';
  if (!path) {
    return new Response(
      JSON.stringify({ error: 'storage_path required' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // 1) Storage 에서 파일 다운로드 (service role)
  const { data: blob, error: dlErr } = await supabase.storage
    .from('recordings')
    .download(path);
  if (dlErr || !blob) {
    return new Response(
      JSON.stringify({ error: 'download failed', detail: dlErr?.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
  const buf = new Uint8Array(await blob.arrayBuffer());
  // base64 encode
  let b64 = '';
  const chunkSize = 0x8000;
  for (let i = 0; i < buf.length; i += chunkSize) {
    b64 += String.fromCharCode(...buf.subarray(i, i + chunkSize));
  }
  const base64Audio = btoa(b64);

  // 2) Gemini 1.5 Flash 호출 — 인라인 오디오 + 전사 프롬프트
  const prompt = `이 오디오는 한국 헬스장 직원들의 회의 또는 메모 녹음입니다.
정확히 음성에서 들리는 대로 한국어로 전사해주세요.
- 발화자 구분 X (대명사·존칭만 자연스럽게)
- 말끝 흐림이나 'ㅁㅁ', '음...', '어...' 같은 군말 제거
- 문장은 자연스럽게 띄어쓰기 + 마침표
- 음성에 없는 내용 추가 X
- 만약 무음이거나 인식 불가하면 빈 문자열 반환`;

  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: prompt },
              { inline_data: { mime_type: mime, data: base64Audio } },
            ],
          }],
          generationConfig: {
            temperature: 0.1,
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
        JSON.stringify({ error: 'gemini api error', status: res.status, detail: errText.slice(0, 500) }),
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
    console.error('transcribe error', e);
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
