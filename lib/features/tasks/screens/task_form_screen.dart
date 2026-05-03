import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/branch.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/auth_provider.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목 입력 필요')));
      return;
    }
    if (me.isAdmin && (_branch == null || _assignee == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('지점·담당자 선택 필요')));
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
        // manager: 본인 지점 중 첫 번째 사용 (지점이 여러 개면 선택 UI 노출)
        final branches = ref.read(myBranchesProvider).valueOrNull ?? [];
        final selectedBranch = _branch ?? (branches.isNotEmpty ? branches.first : null);
        if (selectedBranch == null) {
          throw Exception('지점이 없습니다');
        }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('업무 추가됨')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final managers = (ref.watch(allUsersProvider).valueOrNull ?? [])
        .where((u) => u.isManager)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(isAdmin ? '지시 작성' : '업무 추가')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contentCtrl,
          maxLines: 4,
          decoration: const InputDecoration(labelText: '내용 (선택)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        if (isAdmin || branches.length > 1)
          DropdownButtonFormField<Branch>(
            value: _branch,
            decoration: const InputDecoration(labelText: '지점', border: OutlineInputBorder()),
            items: branches.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
            onChanged: (v) => setState(() => _branch = v),
          ),
        if (isAdmin) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<AppUser>(
            value: _assignee,
            decoration: const InputDecoration(labelText: '담당자 (매니저)', border: OutlineInputBorder()),
            items: managers.map((u) => DropdownMenuItem(value: u, child: Text(u.name))).toList(),
            onChanged: (v) => setState(() => _assignee = v),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<TaskPriority>(
          value: _priority,
          decoration: const InputDecoration(labelText: '우선순위', border: OutlineInputBorder()),
          items: TaskPriority.values
              .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
              .toList(),
          onChanged: (v) => setState(() => _priority = v ?? TaskPriority.normal),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(_dueDate == null ? '마감일 없음' : DateFormat('yyyy-MM-dd').format(_dueDate!)),
          trailing: TextButton(onPressed: _pickDate, child: const Text('선택')),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isAdmin ? '지시 발행' : '업무 추가'),
        ),
      ]),
    );
  }
}
