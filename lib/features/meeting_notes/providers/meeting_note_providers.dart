import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/meeting_note.dart';
import '../data/meeting_note_repository.dart';

final meetingNoteRepositoryProvider =
    Provider<MeetingNoteRepository>((ref) => MeetingNoteRepository());

final meetingNotesListProvider = FutureProvider<List<MeetingNote>>((ref) async {
  return ref.read(meetingNoteRepositoryProvider).list();
});

final meetingNoteByIdProvider = FutureProvider.family<MeetingNote, String>((ref, id) async {
  return ref.read(meetingNoteRepositoryProvider).getById(id);
});

final meetingCommentsProvider =
    FutureProvider.family<List<MeetingComment>, String>((ref, meetingNoteId) async {
  return ref.read(meetingNoteRepositoryProvider).listComments(meetingNoteId);
});
