import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/meeting_note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/pill.dart';
import '../../../shared/widgets/section.dart';
import '../providers/meeting_note_providers.dart';
import 'meeting_note_form_screen.dart';

class MeetingNoteDetailScreen extends ConsumerWidget {
  final String meetingNoteId;
  const MeetingNoteDetailScreen({super.key, required this.meetingNoteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(meetingNoteByIdProvider(meetingNoteId));
    final me = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('회의록'),
        actions: [
          noteAsync.maybeWhen(
            data: (n) {
              if (me != null && (me.isAdmin || me.id == n.authorId)) {
                return IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: '편집',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MeetingNoteFormScreen(existing: n),
                  )),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: noteAsync.when(
        data: (note) => _Body(note: note),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('에러: $e', style: Tokens.ts13)),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final MeetingNote note;
  const _Body({required this.note});
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null || _commentCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(meetingNoteRepositoryProvider).addComment(
            meetingNoteId: widget.note.id,
            userId: me.id,
            content: _commentCtrl.text.trim(),
          );
      _commentCtrl.clear();
      if (mounted) ref.invalidate(meetingCommentsProvider(widget.note.id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final users = ref.watch(allUsersProvider).valueOrNull ?? [];
    final branches = ref.watch(allBranchesProvider).valueOrNull ?? [];
    final author = users.where((u) => u.id == n.authorId).firstOrNull;
    final branch = branches.where((b) => b.id == n.branchId).firstOrNull;
    final commentsAsync = ref.watch(meetingCommentsProvider(n.id));
    final isDraft = n.status == MeetingStatus.draft;

    return ListView(padding: const EdgeInsets.only(bottom: Tokens.s32), children: [
      // Draft banner
      if (isDraft)
        Container(
          margin: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s16, Tokens.s16, 0),
          padding: const EdgeInsets.all(Tokens.s14),
          decoration: BoxDecoration(
            color: Tokens.warning.withOpacity(0.10),
            borderRadius: BorderRadius.circular(Tokens.r12),
            border: Border.all(color: Tokens.warning.withOpacity(0.3)),
          ),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: Tokens.warning, borderRadius: BorderRadius.circular(Tokens.r8)),
              child: const Icon(Icons.edit_note, color: Colors.white, size: 18),
            ),
            const SizedBox(width: Tokens.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('어젠다', style: Tokens.ts13.copyWith(fontWeight: FontWeight.w700, color: Tokens.warning)),
                Text('회의 후 내용을 채워 완료로 전환하세요', style: Tokens.ts12.copyWith(color: Tokens.text)),
              ]),
            ),
          ]),
        ),

      // Hero
      Container(
        margin: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s16, Tokens.s16, 0),
        padding: const EdgeInsets.all(Tokens.s20),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.r16),
          border: Border.all(color: Tokens.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Pill(
            label: isDraft ? '어젠다' : '완료',
            color: isDraft ? Tokens.warning : Tokens.success,
            icon: isDraft ? Icons.edit_note : Icons.check_circle,
          ),
          const SizedBox(height: Tokens.s12),
          Text(n.topic, style: Tokens.ts22),
        ]),
      ),

      // Meta
      Section(title: '정보', children: [
        _MetaRow(icon: Icons.event, label: '회의일자', value: DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(n.meetingDate)),
        _MetaRow(icon: Icons.business_outlined, label: '지점', value: branch?.name ?? '-'),
        _MetaRow(icon: Icons.person_outline, label: '작성', value: author?.name ?? '?'),
        if (n.attendees != null && n.attendees!.isNotEmpty)
          _MetaRow(icon: Icons.groups_outlined, label: '참석자', value: n.attendees!),
      ]),

      // Content
      if (n.content != null && n.content!.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s24, Tokens.s16, Tokens.s8),
          child: Text(
            '내용',
            style: Tokens.ts11.copyWith(color: Tokens.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Tokens.s16),
          padding: const EdgeInsets.all(Tokens.s16),
          decoration: BoxDecoration(
            color: Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.r12),
            border: Border.all(color: Tokens.border),
          ),
          child: Text(n.content!, style: Tokens.ts14.copyWith(height: 1.6)),
        ),
      ],

      // Action items
      if (n.actionItems != null && n.actionItems!.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s24, Tokens.s16, Tokens.s8),
          child: Text(
            '후속 조치',
            style: Tokens.ts11.copyWith(color: Tokens.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: Tokens.s16),
          padding: const EdgeInsets.all(Tokens.s16),
          decoration: BoxDecoration(
            color: Tokens.gold500.withOpacity(0.06),
            borderRadius: BorderRadius.circular(Tokens.r12),
            border: Border.all(color: Tokens.gold500.withOpacity(0.25)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.task_alt, size: 18, color: Tokens.gold600),
            const SizedBox(width: Tokens.s8),
            Expanded(child: Text(n.actionItems!, style: Tokens.ts14.copyWith(height: 1.6))),
          ]),
        ),
      ],

      // Comments
      Padding(
        padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s24, Tokens.s16, Tokens.s8),
        child: Text(
          '댓글',
          style: Tokens.ts11.copyWith(color: Tokens.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
        child: commentsAsync.when(
          data: (comments) {
            if (comments.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(Tokens.s16),
                decoration: BoxDecoration(color: Tokens.surfaceAlt, borderRadius: BorderRadius.circular(Tokens.r12)),
                child: Center(
                  child: Text('아직 댓글이 없습니다', style: Tokens.ts13.copyWith(color: Tokens.textMuted)),
                ),
              );
            }
            return Column(children: [
              for (final c in comments)
                _CommentBubble(
                  authorName: users.where((u) => u.id == c.userId).firstOrNull?.name ?? '?',
                  content: c.content,
                  at: c.createdAt,
                ),
            ]);
          },
          loading: () => const Padding(padding: EdgeInsets.all(Tokens.s16), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('에러: $e', style: Tokens.ts13.copyWith(color: Tokens.danger)),
        ),
      ),
      const SizedBox(height: Tokens.s12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              style: Tokens.ts14,
              decoration: const InputDecoration(hintText: '댓글 작성...', isDense: true),
            ),
          ),
          const SizedBox(width: Tokens.s8),
          IconButton.filled(
            onPressed: _saving ? null : _addComment,
            icon: const Icon(Icons.send, size: 18),
            style: IconButton.styleFrom(backgroundColor: Tokens.navy900, minimumSize: const Size(48, 48)),
          ),
        ]),
      ),
    ]);
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s12),
      child: Row(children: [
        Icon(icon, size: 18, color: Tokens.textMuted),
        const SizedBox(width: Tokens.s12),
        Text(label, style: Tokens.ts13.copyWith(color: Tokens.textMuted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: Tokens.ts14.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ]),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final String authorName;
  final String content;
  final DateTime at;
  const _CommentBubble({required this.authorName, required this.content, required this.at});
  @override
  Widget build(BuildContext context) {
    final initial = authorName.isNotEmpty ? authorName.characters.first : '?';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Tokens.s4),
      padding: const EdgeInsets.all(Tokens.s12),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.r12),
        border: Border.all(color: Tokens.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          decoration: const BoxDecoration(color: Tokens.navy900, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: Tokens.s10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(authorName, style: Tokens.ts13.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: Tokens.s6),
              Text(DateFormat('MM-dd HH:mm').format(at.toLocal()),
                  style: Tokens.ts11.copyWith(color: Tokens.textFaint)),
            ]),
            const SizedBox(height: 2),
            Text(content, style: Tokens.ts14),
          ]),
        ),
      ]),
    );
  }
}
