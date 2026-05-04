enum NoteScope { private, shared }

extension NoteScopeX on NoteScope {
  String get dbValue => switch (this) {
        NoteScope.private => 'private',
        NoteScope.shared => 'shared',
      };
  static NoteScope fromDb(String s) => switch (s) {
        'private' => NoteScope.private,
        'shared' => NoteScope.shared,
        _ => throw ArgumentError('unknown scope: $s'),
      };
  String get label => switch (this) {
        NoteScope.private => '개인 메모',
        NoteScope.shared => '공유 메모',
      };
}

class Note {
  final String id;
  final String ownerId;
  final NoteScope scope;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.ownerId,
    required this.scope,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        ownerId: j['owner_id'] as String,
        scope: NoteScopeX.fromDb(j['scope'] as String),
        content: (j['content'] as String?) ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}
