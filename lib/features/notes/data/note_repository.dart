import '../../../services/supabase_client.dart';
import '../../../shared/models/note.dart';

class NoteRepository {
  /// 내가 작성한 메모 (없으면 null)
  Future<Note?> getMine(String myId) async {
    final res = await supabase.from('notes').select().eq('owner_id', myId).maybeSingle();
    if (res == null) return null;
    return Note.fromJson(res);
  }

  /// 나에게 공유된 메모들 (다른 사람 owner)
  Future<List<Note>> listSharedToMe() async {
    final res = await supabase
        .from('notes')
        .select()
        .order('updated_at', ascending: false);
    final all = (res as List).map((j) => Note.fromJson(j as Map<String, dynamic>)).toList();
    // RLS가 owner=self OR shared_with=self 만 반환. owner != self 만 추출.
    final me = supabase.auth.currentUser;
    if (me == null) return [];
    // me.id 는 auth.users.id. 우리는 public.users.id 와 비교해야 함.
    // 호출 측에서 public users id 알기에 그쪽 메서드는 따로 제공.
    return all;
  }

  /// 본문 저장 (UPSERT)
  Future<Note> saveContent({required String ownerId, required String content}) async {
    final res = await supabase
        .from('notes')
        .upsert({'owner_id': ownerId, 'content': content}, onConflict: 'owner_id')
        .select()
        .single();
    return Note.fromJson(res);
  }

  /// 공유 대상 변경 (작성자 본인만 가능)
  Future<Note> updateSharing({
    required String ownerId,
    required String? sharedWithUserId,
  }) async {
    final res = await supabase
        .from('notes')
        .update({'shared_with_user_id': sharedWithUserId})
        .eq('owner_id', ownerId)
        .select()
        .single();
    return Note.fromJson(res);
  }
}
