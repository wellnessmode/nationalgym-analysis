import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/tokens.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/attachment_repository.dart';

/// 작성 폼 (업무·회의록 신규) 에서 사용. task/meeting 이 아직 생성 안 된 시점에
/// 첨부파일을 메모리에 모아두고, 저장 시 부모가 일괄 upload 호출.
///
/// 사용:
///   - 부모는 List<PendingAttachment> _pending 보관
///   - AttachmentPickerInline(pending: _pending, onChanged: ...)
///   - 폼 저장 후 createdId 받으면 .uploadAll(repo, uploaderId, taskId/meetingNoteId, _pending)
class PendingAttachment {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  PendingAttachment(this.fileName, this.mimeType, this.bytes);
  int get sizeBytes => bytes.length;
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
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    _ => 'application/octet-stream',
  };
}

String _sizeLabel(int b) {
  if (b < 1024) return '${b}B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)}MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)}GB';
}

/// 폼 저장 직후 호출 — 모은 파일들을 실제 attachments 테이블에 업로드.
/// 정확히 [taskId] 또는 [meetingNoteId] 중 하나만 지정.
Future<int> uploadPendingAttachments({
  required WidgetRef ref,
  required String uploaderId,
  required List<PendingAttachment> pending,
  String? taskId,
  String? meetingNoteId,
}) async {
  if (pending.isEmpty) return 0;
  final repo = ref.read(attachmentRepositoryProvider);
  int ok = 0;
  for (final p in pending) {
    try {
      await repo.upload(
        uploaderId: uploaderId,
        taskId: taskId,
        meetingNoteId: meetingNoteId,
        fileName: p.fileName,
        mimeType: p.mimeType,
        bytes: p.bytes,
      );
      ok++;
    } catch (_) {}
  }
  return ok;
}

class AttachmentPickerInline extends ConsumerStatefulWidget {
  final List<PendingAttachment> pending;
  final ValueChanged<List<PendingAttachment>> onChanged;
  const AttachmentPickerInline({
    super.key,
    required this.pending,
    required this.onChanged,
  });

  @override
  ConsumerState<AttachmentPickerInline> createState() =>
      _AttachmentPickerInlineState();
}

class _AttachmentPickerInlineState
    extends ConsumerState<AttachmentPickerInline> {
  bool _picking = false;

  Future<void> _pick({FileType type = FileType.any, bool image = false}) async {
    setState(() => _picking = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: !image,
        withData: true,
      );
      if (picked == null) return;
      final added = <PendingAttachment>[];
      for (final f in picked.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        added.add(PendingAttachment(
          f.name,
          _guessMime(f.name, f.extension),
          Uint8List.fromList(bytes),
        ));
      }
      widget.onChanged([...widget.pending, ...added]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('파일 선택 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _remove(int idx) {
    final next = [...widget.pending]..removeAt(idx);
    widget.onChanged(next);
  }

  void _openSheet() {
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
            leading: const Icon(Icons.photo_library_outlined,
                color: Tokens.navy900),
            title: const Text('사진 / 동영상 (갤러리)'),
            onTap: () {
              Navigator.pop(ctx);
              _pick(type: FileType.media);
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.camera_alt_outlined, color: Tokens.navy900),
            title: const Text('사진 촬영 / 카메라'),
            subtitle: Text('모바일 브라우저에서 카메라 바로 열림',
                style: Tokens.ts11.copyWith(color: Tokens.textMuted)),
            onTap: () {
              Navigator.pop(ctx);
              _pick(type: FileType.image, image: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined,
                color: Tokens.navy900),
            title: const Text('PDF / 워드 / 엑셀 / 기타 파일'),
            onTap: () {
              Navigator.pop(ctx);
              _pick();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  IconData _iconFor(PendingAttachment p) {
    if (p.mimeType.startsWith('image/')) return Icons.image_outlined;
    if (p.mimeType.startsWith('video/')) return Icons.videocam_outlined;
    if (p.mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    final n = p.fileName.toLowerCase();
    if (n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    if (n.endsWith('.doc') || n.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final disabled = me == null || _picking;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.attach_file, size: 16, color: Tokens.textMuted),
        const SizedBox(width: 4),
        Text('첨부파일 (${widget.pending.length})',
            style: Tokens.ts12.copyWith(
                color: Tokens.textMuted, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton.icon(
          onPressed: disabled ? null : _openSheet,
          icon: _picking
              ? const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add, size: 16),
          label: const Text('추가'),
          style: TextButton.styleFrom(
            foregroundColor: Tokens.gold600,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ]),
      if (widget.pending.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '저장 시 함께 업로드할 파일을 골라두세요',
            style: Tokens.ts11.copyWith(color: Tokens.textFaint),
          ),
        )
      else
        Column(
          children: [
            for (var i = 0; i < widget.pending.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Tokens.navy900.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(Tokens.r8),
                    ),
                    child: Icon(_iconFor(widget.pending[i]),
                        color: Tokens.navy900, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.pending[i].fileName,
                            style: Tokens.ts13
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(_sizeLabel(widget.pending[i].sizeBytes),
                              style: Tokens.ts11
                                  .copyWith(color: Tokens.textMuted)),
                        ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: Tokens.textMuted),
                    onPressed: () => _remove(i),
                    visualDensity: VisualDensity.compact,
                  ),
                ]),
              ),
          ],
        ),
    ]);
  }
}
