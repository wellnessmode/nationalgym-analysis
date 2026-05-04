import '../../../services/supabase_client.dart';
import '../../../shared/models/note.dart';

class NoteRepository {
  /// 현재 사용자가 볼 수 있는 모든 노트 (RLS 자동 필터)
  /// - 매니저: 본인 private + 본인 shared
  /// - admin: 본인 private + 모든 사용자의 shared
  Future<List<Note>> listVisible() async {
    final res = await supabase.from('notes').select().order('updated_at', ascending: false);
    return (res as List).map((j) => Note.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// (owner_id, scope) UPSERT — content 비우고 저장하면 새로 생성, 있으면 업데이트
  Future<Note> upsert({
    required String ownerId,
    required NoteScope scope,
    required String content,
  }) async {
    final res = await supabase
        .from('notes')
        .upsert(
          {
            'owner_id': ownerId,
            'scope': scope.dbValue,
            'content': content,
          },
          onConflict: 'owner_id,scope',
        )
        .select()
        .single();
    return Note.fromJson(res);
  }
}
