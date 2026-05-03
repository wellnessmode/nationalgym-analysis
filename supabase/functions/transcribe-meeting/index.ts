// =====================================================
// Edge Function: transcribe-meeting
// 회의록의 녹음 파일을 Whisper API 로 전사 + GPT 로 정리.
//
// Request body: { meeting_note_id: string }
//
// 처리:
//   1. meeting_notes 에서 recording_url 조회
//   2. Storage 에서 오디오 다운로드
//   3. OpenAI Whisper 로 한국어 전사
//   4. GPT-4o-mini 로 회의록 형식으로 정리 (요약 + 후속조치)
//   5. meeting_notes.content + action_items 업데이트
//   6. transcription_status = 'completed'
//
// 환경변수 (Supabase Edge Function Secrets):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (자동)
//   OPENAI_API_KEY (사용자 설정 필수)
// =====================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');

interface Req {
  meeting_note_id: string;
}

async function setStatus(id: string, status: string, patch: Record<string, unknown> = {}) {
  await supabase.from('meeting_notes').update({ transcription_status: status, ...patch }).eq('id', id);
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  let body: Req;
  try {
    body = await req.json();
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }
  const id = body.meeting_note_id;
  if (!id) return new Response('meeting_note_id required', { status: 400 });

  if (!OPENAI_API_KEY) {
    await setStatus(id, 'failed');
    return new Response(JSON.stringify({ error: 'OPENAI_API_KEY not configured' }), { status: 500 });
  }

  try {
    // 1) 회의록 조회
    const { data: note, error: noteErr } = await supabase
      .from('meeting_notes')
      .select('recording_url, content, action_items')
      .eq('id', id)
      .maybeSingle();
    if (noteErr || !note?.recording_url) {
      await setStatus(id, 'failed');
      return new Response(JSON.stringify({ error: 'recording not found' }), { status: 404 });
    }

    // 2) Storage 에서 오디오 다운로드
    const { data: audio, error: dlErr } = await supabase.storage
      .from('meeting-audio')
      .download(note.recording_url);
    if (dlErr || !audio) {
      await setStatus(id, 'failed');
      return new Response(JSON.stringify({ error: 'audio download failed' }), { status: 500 });
    }

    // 3) Whisper 전사
    const fd = new FormData();
    fd.append('file', audio, 'audio.webm');
    fd.append('model', 'whisper-1');
    fd.append('language', 'ko');
    fd.append('response_format', 'text');

    const whisperRes = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${OPENAI_API_KEY}` },
      body: fd,
    });
    if (!whisperRes.ok) {
      console.error('whisper error', whisperRes.status, await whisperRes.text());
      await setStatus(id, 'failed');
      return new Response(JSON.stringify({ error: 'transcription failed' }), { status: 500 });
    }
    const transcript = (await whisperRes.text()).trim();

    if (!transcript) {
      await setStatus(id, 'failed');
      return new Response(JSON.stringify({ error: 'empty transcript' }), { status: 500 });
    }

    // 4) GPT 로 회의록 형식 정리 (한국어, content + action_items 분리)
    const chatRes = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        temperature: 0.2,
        messages: [
          {
            role: 'system',
            content:
              '당신은 한국어 회의록 정리 전문가입니다. 사용자가 제공한 회의 전사문을 ' +
              '구조화된 회의록으로 정리하세요. 출력은 JSON 형식이며 두 필드: ' +
              '"content" (회의 내용·논의 사항·결정 사항을 마크다운 불릿/문단으로) 와 ' +
              '"action_items" (후속 조치 목록을 마크다운 체크리스트 - [ ] 항목 형식). ' +
              '없으면 빈 문자열. 원본 발언을 그대로 옮기지 말고 핵심을 요약하세요.',
          },
          {
            role: 'user',
            content: `다음은 회의 녹음의 한국어 전사입니다. 위 형식으로 정리해주세요.\n\n${transcript}`,
          },
        ],
        response_format: { type: 'json_object' },
      }),
    });

    let content = transcript;
    let actionItems = '';
    if (chatRes.ok) {
      try {
        const chatJson = await chatRes.json();
        const msg = chatJson.choices?.[0]?.message?.content;
        if (msg) {
          const parsed = JSON.parse(msg);
          content = parsed.content || transcript;
          actionItems = parsed.action_items || '';
        }
      } catch (e) {
        console.error('chat parse error', e);
      }
    } else {
      console.error('chat error', chatRes.status, await chatRes.text());
    }

    // 5) DB 업데이트 (기존 내용에 prepend, 빈 경우 그냥 set)
    const newContent = note.content && note.content.trim().length > 0
      ? `## AI 정리\n\n${content}\n\n---\n\n## 기존 메모\n\n${note.content}`
      : content;
    const newActions = actionItems && (note.action_items || '').trim().length > 0
      ? `${actionItems}\n\n---\n\n${note.action_items}`
      : actionItems || note.action_items;

    await supabase
      .from('meeting_notes')
      .update({
        content: newContent,
        action_items: newActions,
        transcription_status: 'completed',
      })
      .eq('id', id);

    return new Response(
      JSON.stringify({ ok: true, transcript_length: transcript.length }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    console.error('transcribe error', e);
    await setStatus(id, 'failed');
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
