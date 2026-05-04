import '../../../services/supabase_client.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/task.dart';

class TaskRepository {
  /// 모든 task 조회 (RLS가 자동으로 본인 권한 범위로 필터)
  /// 마감 임박순 정렬: due_date asc nulls last, then priority desc
  Future<List<Task>> list({TaskStatus? status}) async {
    var q = supabase.from('tasks').select();
    if (status != null) {
      q = q.eq('status', status.dbValue);
    }
    final res = await q.order('due_date', ascending: true, nullsFirst: false)
        .order('created_at', ascending: false);
    return (res as List).map((j) => Task.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Task> getById(String id) async {
    final res = await supabase.from('tasks').select().eq('id', id).single();
    return Task.fromJson(res);
  }

  /// admin이 directive 생성
  Future<Task> createDirective({
    required String branchId,
    required String assigneeId,
    required String requesterId,
    required String title,
    String? content,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.normal,
  }) async {
    final res = await supabase.from('tasks').insert({
      'branch_id': branchId,
      'task_type': TaskType.directive.dbValue,
      'title': title,
      'content': content,
      'requester_id': requesterId,
      'assignee_id': assigneeId,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'priority': priority.dbValue,
      'status': TaskStatus.todo.dbValue,
    }).select().single();
    return Task.fromJson(res);
  }

  /// manager가 본인 manager_task 생성
  Future<Task> createManagerTask({
    required String branchId,
    required String selfUserId,
    required String title,
    String? content,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.normal,
  }) async {
    final res = await supabase.from('tasks').insert({
      'branch_id': branchId,
      'task_type': TaskType.managerTask.dbValue,
      'title': title,
      'content': content,
      'requester_id': selfUserId,
      'assignee_id': selfUserId,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'priority': priority.dbValue,
      'status': TaskStatus.todo.dbValue,
    }).select().single();
    return Task.fromJson(res);
  }

  Future<Task> updateStatus(String id, TaskStatus status) async {
    final patch = <String, dynamic>{'status': status.dbValue};
    if (status == TaskStatus.done) {
      patch['completed_at'] = DateTime.now().toIso8601String();
    } else {
      patch['completed_at'] = null;
    }
    final res = await supabase.from('tasks').update(patch).eq('id', id).select().single();
    return Task.fromJson(res);
  }

  Future<Task> updateMemo(String id, String memo) async {
    final res = await supabase.from('tasks').update({'memo': memo}).eq('id', id).select().single();
    return Task.fromJson(res);
  }

  // ── Comments ─────────────────────────────────────────────────

  Future<List<TaskComment>> listComments(String taskId) async {
    final res = await supabase
        .from('task_comments')
        .select()
        .eq('task_id', taskId)
        .order('created_at', ascending: true);
    return (res as List).map((j) => TaskComment.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<TaskComment> addComment({
    required String taskId,
    required String userId,
    required String content,
  }) async {
    final res = await supabase.from('task_comments').insert({
      'task_id': taskId,
      'user_id': userId,
      'content': content,
    }).select().single();
    return TaskComment.fromJson(res);
  }

  Future<void> delete(String id) async {
    await supabase.from('tasks').delete().eq('id', id);
  }
}
