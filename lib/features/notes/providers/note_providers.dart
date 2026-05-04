import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/note_repository.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) => NoteRepository());

/// 내가 작성한 메모 목록 (최신 순)
final myNotesProvider = FutureProvider<List<Note>>((ref) async {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return [];
  return ref.read(noteRepositoryProvider).listMine(me.id);
});

/// 나에게 공유된 메모 목록 (남이 작성 → 나에게 공유)
final sharedToMeProvider = FutureProvider<List<Note>>((ref) async {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return [];
  return ref.read(noteRepositoryProvider).listSharedToMe(me.id);
});

/// 대표 전용: 모든 메모 (매니저 인사평가 열람용)
final allNotesAdminProvider = FutureProvider<List<Note>>((ref) async {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null || !me.isAdmin) return [];
  return ref.read(noteRepositoryProvider).listAllForAdmin();
});
