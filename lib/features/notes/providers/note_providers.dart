import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/note.dart';
import '../data/note_repository.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) => NoteRepository());

final notesProvider = FutureProvider<List<Note>>((ref) async {
  return ref.read(noteRepositoryProvider).listVisible();
});
