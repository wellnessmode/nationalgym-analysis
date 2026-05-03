import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/task.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) => TaskRepository());

/// 업무 탭의 필터 옵션
enum TaskFilter { all, directives, mine, done }

extension TaskFilterX on TaskFilter {
  String get label => switch (this) {
        TaskFilter.all => '전체',
        TaskFilter.directives => '대표 지시',
        TaskFilter.mine => '내 업무',
        TaskFilter.done => '완료함',
      };
}

final taskFilterProvider = StateProvider<TaskFilter>((ref) => TaskFilter.all);

/// 지점 필터 (admin 전용. null = 전체)
final taskBranchFilterProvider = StateProvider<String?>((ref) => null);

/// 필터 적용된 task 리스트
final filteredTasksProvider = FutureProvider<List<Task>>((ref) async {
  final filter = ref.watch(taskFilterProvider);
  final branchFilter = ref.watch(taskBranchFilterProvider);
  // 'mine' 필터에서 사용. 로그인 안 된 상태에선 null
  final me = ref.watch(currentUserProvider).valueOrNull;

  // RLS가 본인 지점 범위로 1차 필터, 여기선 추가 카테고리 필터
  final allTasks = await ref.read(taskRepositoryProvider).list();

  return allTasks.where((t) {
    if (branchFilter != null && t.branchId != branchFilter) return false;
    return switch (filter) {
      TaskFilter.all => t.status != TaskStatus.done,
      TaskFilter.directives =>
        t.taskType == TaskType.directive && t.status != TaskStatus.done,
      TaskFilter.mine =>
        // 본인이 담당자 또는 요청자인 업무만
        (me != null && (t.assigneeId == me.id || t.requesterId == me.id)) &&
            t.status != TaskStatus.done,
      TaskFilter.done => t.status == TaskStatus.done,
    };
  }).toList();
});

/// 단일 task 조회 (상세 화면용)
final taskByIdProvider = FutureProvider.family<Task, String>((ref, id) async {
  return ref.read(taskRepositoryProvider).getById(id);
});

/// task 댓글 목록
final taskCommentsProvider = FutureProvider.family<List<TaskComment>, String>((ref, taskId) async {
  return ref.read(taskRepositoryProvider).listComments(taskId);
});
