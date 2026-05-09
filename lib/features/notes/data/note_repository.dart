import '../../../services/supabase_client.dart';
import '../../../shared/models/note.dart';

class NoteRepository {
  /// 내가 작성한 메모들 (최신 순)
  Future<List<Note>> listMine(String myId) async {
    final res = await supabase
        .from('notes')
        .select()
        .eq('owner_id', myId)
        .order('updated_at', ascending: false);
    return (res as List).map((j) => Note.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// 나에게 공유된 메모들 (다른 사람이 만들어서 나에게 공유)
  Future<List<Note>> listSharedToMe(String myId) async {
    final res = await supabase
        .from('notes')
        .select()
        .eq('shared_with_user_id', myId)
        .order('updated_at', ascending: false);
    return (res as List)
        .map((j) => Note.fromJson(j as Map<String, dynamic>))
        .where((n) => n.ownerId != myId)
        .toList();
  }

  /// 단일 메모 조회
  Future<Note?> getById(String id) async {
    final res = await supabase.from('notes').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return Note.fromJson(res);
  }

  /// 빈 메모 생성 (에디터에서 자동 저장으로 채워짐)
  Future<Note> createEmpty({required String ownerId}) async {
    final res = await supabase
        .from('notes')
        .insert({'owner_id': ownerId, 'title': '', 'content': ''})
        .select()
        .single();
    return Note.fromJson(res);
  }

  /// 제목·본문 저장
  Future<Note> save({
    required String id,
    required String title,
    required String content,
  }) async {
    final res = await supabase
        .from('notes')
        .update({'title': title, 'content': content})
        .eq('id', id)
        .select()
        .single();
    return Note.fromJson(res);
  }

  /// 공유 대상 변경 (작성자만 가능 — DB 트리거로 강제됨)
  Future<Note> updateSharing({
    required String id,
    required String? sharedWithUserId,
  }) async {
    final res = await supabase
        .from('notes')
        .update({'shared_with_user_id': sharedWithUserId})
        .eq('id', id)
        .select()
        .single();
    return Note.fromJson(res);
  }

  /// 메모 삭제 (작성자만)
  Future<void> delete(String id) async {
    await supabase.from('notes').delete().eq('id', id);
  }

  /// Gemini Edge Function — 메모 raw 텍스트(음성 인식 결과 포함)를 정돈된 메모로 변환.
  /// null = 실패.
  Future<String?> aiCleanup(String text) async {
    try {
      final res = await supabase.functions.invoke(
        'cleanup-memo',
        body: {'text': text},
      );
      final data = res.data;
      if (data is Map && data['ok'] == true) {
        return (data['text'] as String?) ?? '';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 대표 전용: 모든 사용자의 메모 열람 (인사평가 목적)
  Future<List<Note>> listAllForAdmin() async {
    final res = await supabase
        .from('notes')
        .select()
        .order('updated_at', ascending: false);
    return (res as List).map((j) => Note.fromJson(j as Map<String, dynamic>)).toList();
  }
}
