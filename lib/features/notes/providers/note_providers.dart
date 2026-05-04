import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/note_repository.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) => NoteRepository());

/// 내가 작성한 메모 (없으면 null)
final myNoteProvider = FutureProvider<Note?>((ref) async {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return null;
  return ref.read(noteRepositoryProvider).getMine(me.id);
});

/// 나에게 공유된 메모 목록 (남이 작성하고 나에게 공유한 것)
final sharedToMeProvider = FutureProvider<List<Note>>((ref) async {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return [];
  final all = await ref.read(noteRepositoryProvider).listSharedToMe();
  // 본인 메모는 제외
  return all.where((n) => n.ownerId != me.id).toList();
});
