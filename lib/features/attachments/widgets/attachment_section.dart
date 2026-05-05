import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/attachment.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/attachment_repository.dart';

/// task_id 또는 meeting_note_id 중 하나에 묶인 첨부파일 목록 + 추가/삭제 UI.
class AttachmentSection extends ConsumerStatefulWidget {
  final String? taskId;
  final String? meetingNoteId;
  final bool canEdit;

  const AttachmentSection({
    super.key,
    this.taskId,
    this.meetingNoteId,
    this.canEdit = true,
  }) : assert((taskId == null) != (meetingNoteId == null),
            'taskId 또는 meetingNoteId 중 하나만');

  @override
  ConsumerState<AttachmentSection> createState() => _AttachmentSectionState();
}

class _AttachmentSectionState extends ConsumerState<AttachmentSection> {
  late Future<List<Attachment>> _future;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Attachment>> _load() {
    final repo = ref.read(attachmentRepositoryProvider);
    return widget.taskId != null
        ? repo.listForTask(widget.taskId!)
        : repo.listForMeeting(widget.meetingNoteId!);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _pickFiles({FileType type = FileType.any, bool image = false}) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: !image, // 이미지/카메라는 1장씩
        withData: true,
      );
    } catch (e) {
      _snack('파일 선택 실패: $e');
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    setState(() => _uploading = true);
    final repo = ref.read(attachmentRepositoryProvider);
    int ok = 0;
    String? lastErr;
    for (final f in picked.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      try {
        await repo.upload(
          uploaderId: me.id,
          taskId: widget.taskId,
          meetingNoteId: widget.meetingNoteId,
          fileName: f.name,
          mimeType: _guessMime(f.name, f.extension),
          bytes: Uint8List.fromList(bytes),
        );
        ok++;
      } catch (e) {
        lastErr = '$e';
      }
    }
    if (mounted) {
      setState(() => _uploading = false);
      _snack(lastErr == null ? '$ok개 업로드 완료' : '$ok개 업로드 / 실패: $lastErr');
      _refresh();
    }
  }

  String _guessMime(String name, String? ext) {
    final e = (ext ?? name.split('.').lastOrNull ?? '').toLowerCase();
    return switch (e) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _open(Attachment a) async {
    try {
      final url = await ref.read(attachmentRepositoryProvider).signedUrl(a.storagePath);
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _snack('열기 실패: $e');
    }
  }

  Future<void> _delete(Attachment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('첨부파일 삭제'),
        content: Text('"${a.fileName}" 파일을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Tokens.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(attachmentRepositoryProvider).delete(a);
      _snack('삭제됨');
      _refresh();
    } catch (e) {
      _snack('삭제 실패: $e');
    }
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.r16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Tokens.textFaint.withOpacity(0.4),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: Tokens.navy900),
            title: const Text('사진 / 동영상 (갤러리)'),
            onTap: () {
              Navigator.pop(ctx);
              _pickFiles(type: FileType.media);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: Tokens.navy900),
            title: const Text('사진 촬영 / 카메라'),
            subtitle: Text('모바일 브라우저에서 카메라 바로 열림',
                style: Tokens.ts11.copyWith(color: Tokens.textMuted)),
            onTap: () {
              Navigator.pop(ctx);
              _pickFiles(type: FileType.image, image: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined, color: Tokens.navy900),
            title: const Text('PDF / 워드 / 엑셀 / 기타 파일'),
            onTap: () {
              Navigator.pop(ctx);
              _pickFiles();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Attachment>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.attach_file, size: 16, color: Tokens.textMuted),
            const SizedBox(width: 4),
            Text('첨부파일 (${items.length})',
                style: Tokens.ts12.copyWith(
                    color: Tokens.textMuted, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (widget.canEdit)
              TextButton.icon(
                onPressed: _uploading ? null : _openAddSheet,
                icon: _uploading
                    ? const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add, size: 16),
                label: Text(_uploading ? '업로드 중...' : '추가'),
                style: TextButton.styleFrom(
                  foregroundColor: Tokens.gold600,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ]),
          if (snap.connectionState == ConnectionState.waiting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('첨부된 파일이 없습니다',
                  style: Tokens.ts12.copyWith(color: Tokens.textFaint)),
            )
          else
            Column(
              children: items
                  .map((a) => _AttachmentTile(
                        a: a,
                        canDelete: widget.canEdit,
                        onOpen: () => _open(a),
                        onDelete: () => _delete(a),
                      ))
                  .toList(),
            ),
        ]);
      },
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final Attachment a;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _AttachmentTile({
    required this.a,
    required this.canDelete,
    required this.onOpen,
    required this.onDelete,
  });

  IconData get _icon {
    if (a.isImage) return Icons.image_outlined;
    if (a.isVideo) return Icons.videocam_outlined;
    if (a.isPdf) return Icons.picture_as_pdf_outlined;
    final n = a.fileName.toLowerCase();
    if (n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    if (n.endsWith('.doc') || n.endsWith('.docx')) return Icons.description_outlined;
    if (n.endsWith('.ppt') || n.endsWith('.pptx')) return Icons.slideshow_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(Tokens.r8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Tokens.navy900.withOpacity(0.08),
                borderRadius: BorderRadius.circular(Tokens.r8),
              ),
              child: Icon(_icon, color: Tokens.navy900, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  a.fileName,
                  style: Tokens.ts13.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(a.sizeLabel,
                    style: Tokens.ts11.copyWith(color: Tokens.textMuted)),
              ]),
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Tokens.textMuted),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
          ]),
        ),
      ),
    );
  }
}
