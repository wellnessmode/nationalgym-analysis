import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/branch.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/meeting_note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../attachments/widgets/attachment_picker_inline.dart';
import '../providers/meeting_note_providers.dart';
import '../widgets/audio_recorder_panel.dart';

class MeetingNoteFormScreen extends ConsumerStatefulWidget {
  /// null: 신규 작성. 값 있음: 편집.
  final MeetingNote? existing;
  const MeetingNoteFormScreen({super.key, this.existing});

  @override
  ConsumerState<MeetingNoteFormScreen> createState() => _MeetingNoteFormScreenState();
}

/// 참석자 기본 후보 (체크박스). 그 외는 _otherAttendeesCtrl 자유 입력.
const _kAttendeePresets = ['최현승', '김근희', '정인재'];

class _MeetingNoteFormScreenState extends ConsumerState<MeetingNoteFormScreen> {
  final _topicCtrl = TextEditingController();
  final _otherAttendeesCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _actionsCtrl = TextEditingController();
  final Set<String> _selectedAttendees = {};
  List<PendingAttachment> _pendingAttachments = [];
  Branch? _branch;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _topicCtrl.text = e.topic;
      _seedAttendees(e.attendees ?? '');
      _contentCtrl.text = e.content ?? '';
      _actionsCtrl.text = e.actionItems ?? '';
      _date = e.meetingDate;
    } else {
      _date = DateTime.now();
    }
  }

  void _seedAttendees(String raw) {
    if (raw.trim().isEmpty) return;
    final parts = raw.split(RegExp(r'[,、]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final others = <String>[];
    for (final p in parts) {
      if (_kAttendeePresets.contains(p)) {
        _selectedAttendees.add(p);
      } else {
        others.add(p);
      }
    }
    _otherAttendeesCtrl.text = others.join(', ');
  }

  String _composedAttendees() {
    final names = <String>[
      ..._kAttendeePresets.where(_selectedAttendees.contains),
    ];
    final other = _otherAttendeesCtrl.text.trim();
    if (other.isNotEmpty) names.add(other);
    return names.join(', ');
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _otherAttendeesCtrl.dispose();
    _contentCtrl.dispose();
    _actionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(MeetingStatus status) async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    if (_topicCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주제 입력 필요')));
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(meetingNoteRepositoryProvider);
    final attendeesStr = _composedAttendees();
    try {
      if (widget.existing == null) {
        // 신규: admin은 allBranches, manager는 myBranches
        final branches = me.isAdmin
            ? (ref.read(allBranchesProvider).valueOrNull ?? [])
            : (ref.read(myBranchesProvider).valueOrNull ?? []);
        final selectedBranch = _branch ?? (branches.isNotEmpty ? branches.first : null);
        if (selectedBranch == null) throw Exception('지점이 없습니다');
        final created = await repo.create(
          branchId: selectedBranch.id,
          authorId: me.id,
          status: status,
          meetingDate: _date,
          topic: _topicCtrl.text.trim(),
          attendees: attendeesStr.isEmpty ? null : attendeesStr,
          content: _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
          actionItems: _actionsCtrl.text.trim().isEmpty ? null : _actionsCtrl.text.trim(),
        );
        // 첨부파일 일괄 업로드
        if (_pendingAttachments.isNotEmpty) {
          await uploadPendingAttachments(
            ref: ref,
            uploaderId: me.id,
            pending: _pendingAttachments,
            meetingNoteId: created.id,
          );
        }
      } else {
        // 편집
        await repo.update(
          widget.existing!.id,
          topic: _topicCtrl.text.trim(),
          attendees: attendeesStr,
          content: _contentCtrl.text.trim(),
          actionItems: _actionsCtrl.text.trim(),
          status: status,
          meetingDate: _date,
        );
        if (_pendingAttachments.isNotEmpty) {
          await uploadPendingAttachments(
            ref: ref,
            uploaderId: me.id,
            pending: _pendingAttachments,
            meetingNoteId: widget.existing!.id,
          );
        }
        ref.invalidate(meetingNoteByIdProvider(widget.existing!.id));
      }
      if (!mounted) return;
      ref.invalidate(meetingNotesListProvider);
      Navigator.of(context).pop();
      final extra = _pendingAttachments.isEmpty ? '' : ' · 첨부 ${_pendingAttachments.length}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장됨 (${status.label})$extra')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// 음성 인식 결과를 본문 컨트롤러에 반영. interim 포함이라 전체 교체.
  void _handleTranscript(String text) {
    _contentCtrl.text = text;
    _contentCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _contentCtrl.text.length),
    );
  }

  bool _aiCleaning = false;

  /// 본문 raw transcript → Gemini 로 정리 → content + action_items 자동 채움.
  Future<void> _aiCleanup() async {
    final raw = _contentCtrl.text.trim();
    if (raw.length < 10) {
      _snack('정리할 내용이 너무 짧습니다 (10자 이상 필요)');
      return;
    }
    setState(() => _aiCleaning = true);
    try {
      final res = await ref.read(meetingNoteRepositoryProvider).aiCleanup(raw);
      if (res == null) {
        _snack('AI 정리 실패. GEMINI_API_KEY가 설정되었는지 확인하세요');
        return;
      }
      _contentCtrl.text = res.content;
      // 후속조치는 기존 내용에 prepend
      final existingActions = _actionsCtrl.text.trim();
      if (res.actionItems.isNotEmpty) {
        _actionsCtrl.text = existingActions.isEmpty
            ? res.actionItems
            : '${res.actionItems}\n\n${existingActions}';
      }
      _snack('AI 정리 완료');
    } catch (e) {
      _snack('AI 정리 오류: $e');
    } finally {
      if (mounted) setState(() => _aiCleaning = false);
    }
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    // admin이면 모든 지점, manager면 본인 담당 지점
    final branches = me.isAdmin
        ? (ref.watch(allBranchesProvider).valueOrNull ?? [])
        : (ref.watch(myBranchesProvider).valueOrNull ?? []);
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '회의록 편집' : '회의록 작성')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!isEditing && branches.length > 1)
          DropdownButtonFormField<Branch>(
            value: _branch,
            decoration: const InputDecoration(labelText: '지점', border: OutlineInputBorder()),
            items: branches.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
            onChanged: (v) => setState(() => _branch = v),
          ),
        if (!isEditing && branches.length > 1) const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text('회의일자: ${DateFormat('yyyy-MM-dd').format(_date)}'),
          trailing: TextButton(onPressed: _pickDate, child: const Text('변경')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _topicCtrl,
          decoration: const InputDecoration(labelText: '주제', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        _SectionLabel('참석자'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final name in _kAttendeePresets)
              FilterChip(
                label: Text(name),
                selected: _selectedAttendees.contains(name),
                onSelected: (sel) => setState(() {
                  sel ? _selectedAttendees.add(name) : _selectedAttendees.remove(name);
                }),
                selectedColor: Tokens.gold500.withOpacity(0.18),
                checkmarkColor: Tokens.gold600,
                shape: StadiumBorder(side: BorderSide(
                  color: _selectedAttendees.contains(name) ? Tokens.gold500 : Tokens.border,
                )),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otherAttendeesCtrl,
          decoration: const InputDecoration(
            labelText: '기타 (자유 입력)',
            border: OutlineInputBorder(),
            hintText: '예: 트레이너 3명, 외부 컨설턴트',
            isDense: true,
          ),
        ),
        const SizedBox(height: Tokens.s16),

        // 회의 음성 → 본문 자동 입력 (Web Speech API, 무료)
        AudioRecorderPanel(
          onTranscriptChunk: _handleTranscript,
          disabled: _saving || _aiCleaning,
          idleTitle: '회의 음성 인식',
          idleSubtitle: '버튼을 누르고 말씀하면 본문에 자동 입력됩니다',
        ),
        const SizedBox(height: Tokens.s8),

        // AI 정리 (Gemini, 무료 티어)
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: (_saving || _aiCleaning) ? null : _aiCleanup,
            icon: _aiCleaning
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome, size: 16, color: Tokens.gold600),
            label: Text(_aiCleaning ? 'AI 정리 중...' : 'AI로 회의록 정리'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Tokens.gold600,
              side: const BorderSide(color: Tokens.gold500),
            ),
          ),
        ),
        const SizedBox(height: Tokens.s16),

        _SectionLabel('회의 내용'),
        const _Hint('위 음성 인식 결과나 AI 정리가 자동으로 들어갑니다. 직접 작성·수정도 가능.'),
        const SizedBox(height: 6),
        TextField(
          controller: _contentCtrl,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '회의에서 논의된 주요 안건·결정 사항…',
          ),
        ),
        const SizedBox(height: Tokens.s16),

        _SectionLabel('후속 조치'),
        const _Hint('회의 후 누가·언제까지·뭘 할지. AI 정리 시 체크리스트가 자동 채워집니다.'),
        const SizedBox(height: 6),
        TextField(
          controller: _actionsCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '예) 정인재: 신규 회원 안내문 수정 (D+3)',
          ),
        ),
        const SizedBox(height: Tokens.s20),

        // 첨부파일 (저장 시 일괄 업로드)
        AttachmentPickerInline(
          pending: _pendingAttachments,
          onChanged: (l) => setState(() => _pendingAttachments = l),
        ),
        const SizedBox(height: Tokens.s20),

        Container(
          padding: const EdgeInsets.all(Tokens.s12),
          decoration: BoxDecoration(
            color: Tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(Tokens.r8),
            border: Border.all(color: Tokens.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.info_outline, size: 14, color: Tokens.textMuted),
              const SizedBox(width: 6),
              Text('저장 방식', style: Tokens.ts12.copyWith(fontWeight: FontWeight.w700, color: Tokens.textMuted)),
            ]),
            const SizedBox(height: 6),
            Text(
              '• 어젠다: 회의 전 미리 주제·참석자만 적어둘 때 (= 진행 예정)\n• 완료: 회의가 끝나고 내용 정리까지 완성됐을 때',
              style: Tokens.ts12.copyWith(color: Tokens.textMuted, height: 1.5),
            ),
          ]),
        ),
        const SizedBox(height: Tokens.s12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => _save(MeetingStatus.draft),
              child: const Text('어젠다로 저장'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : () => _save(MeetingStatus.completed),
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('완료로 저장'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: Tokens.ts13.copyWith(fontWeight: FontWeight.w700, color: Tokens.text),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 2),
      child: Text(
        text,
        style: Tokens.ts11.copyWith(color: Tokens.textMuted),
      ),
    );
  }
}

