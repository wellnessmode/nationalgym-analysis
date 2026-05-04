class Attachment {
  final String id;
  final String? taskId;
  final String? meetingNoteId;
  final String uploaderId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  Attachment({
    required this.id,
    required this.taskId,
    required this.meetingNoteId,
    required this.uploaderId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isPdf => mimeType == 'application/pdf';

  String get sizeLabel {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    if (sizeBytes < 1024 * 1024 * 1024) return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)}MB';
    return '${(sizeBytes / 1024 / 1024 / 1024).toStringAsFixed(1)}GB';
  }

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'] as String,
        taskId: j['task_id'] as String?,
        meetingNoteId: j['meeting_note_id'] as String?,
        uploaderId: j['uploader_id'] as String,
        storagePath: j['storage_path'] as String,
        fileName: j['file_name'] as String,
        mimeType: j['mime_type'] as String,
        sizeBytes: (j['size_bytes'] as num).toInt(),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
