import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/task.dart';
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

  // RLS 가 알아서 본인 권한 범위로 필터링하므로, 여기선 클라이언트 사이드 필터만
  final allTasks = await ref.read(taskRepositoryProvider).list();

  return allTasks.where((t) {
    // 지점 필터
    if (branchFilter != null && t.branchId != branchFilter) return false;
    // 카테고리 필터
    return switch (filter) {
      TaskFilter.all => t.status != TaskStatus.done,
      TaskFilter.directives => t.taskType == TaskType.directive && t.status != TaskStatus.done,
      TaskFilter.mine => t.status != TaskStatus.done, // 'mine' 의미는 RLS 본인 지점 = 사실상 all과 동일. 추후 본인 직접 담당분만으로 좁힐 수 있음
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
