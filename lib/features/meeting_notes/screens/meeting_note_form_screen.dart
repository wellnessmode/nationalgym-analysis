import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/branch.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/meeting_note.dart';
import '../../../shared/providers/auth_provider.dart';
import '../providers/meeting_note_providers.dart';
import '../widgets/audio_recorder_panel.dart';

class MeetingNoteFormScreen extends ConsumerStatefulWidget {
  /// null: 신규 작성. 값 있음: 편집.
  final MeetingNote? existing;
  const MeetingNoteFormScreen({super.key, this.existing});

  @override
  ConsumerState<MeetingNoteFormScreen> createState() => _MeetingNoteFormScreenState();
}

class _MeetingNoteFormScreenState extends ConsumerState<MeetingNoteFormScreen> {
  final _topicCtrl = TextEditingController();
  final _attendeesCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _actionsCtrl = TextEditingController();
  Branch? _branch;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _topicCtrl.text = e.topic;
      _attendeesCtrl.text = e.attendees ?? '';
      _contentCtrl.text = e.content ?? '';
      _actionsCtrl.text = e.actionItems ?? '';
      _date = e.meetingDate;
    } else {
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _attendeesCtrl.dispose();
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
    try {
      if (widget.existing == null) {
        // 신규
        final branches = ref.read(myBranchesProvider).valueOrNull ?? [];
        final selectedBranch = _branch ?? (branches.isNotEmpty ? branches.first : null);
        if (selectedBranch == null) throw Exception('지점이 없습니다');
        await repo.create(
          branchId: selectedBranch.id,
          authorId: me.id,
          status: status,
          meetingDate: _date,
          topic: _topicCtrl.text.trim(),
          attendees: _attendeesCtrl.text.trim().isEmpty ? null : _attendeesCtrl.text.trim(),
          content: _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
          actionItems: _actionsCtrl.text.trim().isEmpty ? null : _actionsCtrl.text.trim(),
        );
      } else {
        // 편집
        await repo.update(
          widget.existing!.id,
          topic: _topicCtrl.text.trim(),
          attendees: _attendeesCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          actionItems: _actionsCtrl.text.trim(),
          status: status,
          meetingDate: _date,
        );
        ref.invalidate(meetingNoteByIdProvider(widget.existing!.id));
      }
      if (!mounted) return;
      ref.invalidate(meetingNotesListProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장됨 (${status.label})')));
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
    final branches = ref.watch(myBranchesProvider).valueOrNull ?? [];
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
        TextField(
          controller: _attendeesCtrl,
          decoration: const InputDecoration(
            labelText: '참석자 (자유 입력)',
            border: OutlineInputBorder(),
            hintText: '예: 정인재, 김근희, 트레이너 3명',
          ),
        ),
        const SizedBox(height: Tokens.s16),

        // 회의 음성 → 본문 자동 입력 (Web Speech API, 무료)
        AudioRecorderPanel(
          onTranscriptChunk: _handleTranscript,
          disabled: _saving || _aiCleaning,
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

        TextField(
          controller: _contentCtrl,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '회의 내용 (어젠다 단계에선 비워도 OK)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _actionsCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '후속 조치 (선택)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
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
