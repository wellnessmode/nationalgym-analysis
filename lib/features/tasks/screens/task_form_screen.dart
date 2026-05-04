import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/branch.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/utils/branch_label.dart';
import '../providers/task_providers.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key});
  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  Branch? _branch;
  AppUser? _assignee;
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.normal;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('제목을 입력해주세요');
      return;
    }
    if (me.isAdmin && (_branch == null || _assignee == null)) {
      _snack('지점과 담당자를 모두 선택해주세요');
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(taskRepositoryProvider);
    try {
      if (me.isAdmin) {
        await repo.createDirective(
          branchId: _branch!.id,
          assigneeId: _assignee!.id,
          requesterId: me.id,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
        );
      } else {
        final branches = ref.read(myBranchesProvider).valueOrNull ?? [];
        final selectedBranch = _branch ?? (branches.isNotEmpty ? branches.first : null);
        if (selectedBranch == null) throw Exception('지점이 없습니다');
        await repo.createManagerTask(
          branchId: selectedBranch.id,
          selfUserId: me.id,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim().isEmpty ? null : _contentCtrl.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
        );
      }
      if (!mounted) return;
      ref.invalidate(filteredTasksProvider);
      Navigator.of(context).pop();
      _snack('업무가 추가되었습니다');
    } catch (e) {
      _snack('에러: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isAdmin = me.isAdmin;
    final branches = isAdmin
        ? (ref.watch(allBranchesProvider).valueOrNull ?? [])
        : (ref.watch(myBranchesProvider).valueOrNull ?? []);
    final allManagers = (ref.watch(allUsersProvider).valueOrNull ?? [])
        .where((u) => u.isManager)
        .toList();
    final userBranches = ref.watch(allUserBranchesProvider).valueOrNull ?? {};
    // 선택된 지점에 배정된 매니저만 노출 (대표가 업무 전달할 때)
    final managers = isAdmin && _branch != null
        ? allManagers.where((u) {
            final bs = userBranches[u.id] ?? [];
            return bs.any((b) => b.id == _branch!.id);
          }).toList()
        : allManagers;
    final showBranch = isAdmin || branches.length > 1;

    return Scaffold(
      appBar: AppBar(title: Text(isAdmin ? '업무 전달' : '업무 추가')),
      body: ListView(padding: const EdgeInsets.all(Tokens.s16), children: [
        _Label('제목'),
        TextField(
          controller: _titleCtrl,
          style: Tokens.ts15,
          decoration: const InputDecoration(hintText: '예: 용산점 청소 점검'),
        ),
        const SizedBox(height: Tokens.s16),

        _Label('내용 (선택)'),
        TextField(
          controller: _contentCtrl,
          maxLines: 4,
          style: Tokens.ts14,
          decoration: const InputDecoration(hintText: '상세 내용...'),
        ),
        const SizedBox(height: Tokens.s16),

        if (showBranch) ...[
          _Label('지점'),
          DropdownButtonFormField<Branch>(
            value: _branch,
            items: branches.map((b) => DropdownMenuItem(value: b, child: Text(b.name, style: Tokens.ts14))).toList(),
            onChanged: (v) => setState(() {
              _branch = v;
              // 새 지점에서 자격 없는 담당자는 초기화
              if (isAdmin && _assignee != null) {
                final bs = userBranches[_assignee!.id] ?? [];
                final stillEligible = v == null || bs.any((b) => b.id == v.id);
                if (!stillEligible) _assignee = null;
              }
            }),
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: Tokens.s16),
        ],

        if (isAdmin) ...[
          _Label('담당자'),
          DropdownButtonFormField<AppUser>(
            value: _assignee,
            items: managers.map((u) {
              final myBs = userBranches[u.id] ?? [];
              final branchLabel = myBs.map((b) => shortBranchLabel(b.name)).join(' · ');
              return DropdownMenuItem(
                value: u,
                child: Row(children: [
                  Text(u.name, style: Tokens.ts14.copyWith(fontWeight: FontWeight.w600)),
                  if (branchLabel.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      branchLabel,
                      style: Tokens.ts12.copyWith(color: Tokens.textMuted),
                    ),
                  ],
                ]),
              );
            }).toList(),
            onChanged: (v) => setState(() => _assignee = v),
            decoration: InputDecoration(
              hintText: _branch == null ? '지점을 먼저 선택하세요' : '매니저 선택',
            ),
          ),
          if (_branch != null && managers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Tokens.s6, left: Tokens.s4),
              child: Text(
                '이 지점을 담당하는 매니저가 없습니다',
                style: Tokens.ts11.copyWith(color: Tokens.textMuted),
              ),
            ),
          const SizedBox(height: Tokens.s16),
        ],

        _Label('우선순위'),
        Row(children: [
          for (final p in TaskPriority.values) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _priority = p),
                child: Container(
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _priority == p ? Tokens.navy900 : Tokens.surface,
                    borderRadius: BorderRadius.circular(Tokens.r8),
                    border: Border.all(
                      color: _priority == p ? Tokens.navy900 : Tokens.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    p.label,
                    style: TextStyle(
                      color: _priority == p ? Colors.white : Tokens.text,
                      fontSize: 13,
                      fontWeight: _priority == p ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: Tokens.s16),

        _Label('마감일'),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(Tokens.r12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s14),
            decoration: BoxDecoration(
              color: Tokens.surface,
              borderRadius: BorderRadius.circular(Tokens.r12),
              border: Border.all(color: Tokens.border),
            ),
            child: Row(children: [
              const Icon(Icons.event, size: 18, color: Tokens.textMuted),
              const SizedBox(width: Tokens.s12),
              Expanded(
                child: Text(
                  _dueDate == null
                      ? '없음'
                      : DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(_dueDate!),
                  style: Tokens.ts14.copyWith(
                    color: _dueDate == null ? Tokens.textFaint : Tokens.text,
                  ),
                ),
              ),
              if (_dueDate != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _dueDate = null),
                  visualDensity: VisualDensity.compact,
                ),
            ]),
          ),
        ),
        const SizedBox(height: Tokens.s32),

        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isAdmin ? '업무 전달하기' : '업무 추가하기'),
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s6, left: Tokens.s4),
      child: Text(
        text,
        style: Tokens.ts12.copyWith(color: Tokens.textMuted, fontWeight: FontWeight.w600),
      ),
    );
  }
}
