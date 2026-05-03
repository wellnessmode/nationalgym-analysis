import 'enums.dart';

class Task {
  final String id;
  final String branchId;
  final TaskType taskType;
  final String title;
  final String? content;
  final String requesterId;
  final String assigneeId;
  final DateTime? dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final String? memo;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.branchId,
    required this.taskType,
    required this.title,
    required this.content,
    required this.requesterId,
    required this.assigneeId,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.memo,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// D-day. 마감일 없음 → null. 음수: 경과 일수, 0: 오늘, 양수: 남은 일수.
  int? get dDay {
    if (dueDate == null) return null;
    final today = DateTime.now();
    final due = dueDate!;
    return DateTime(due.year, due.month, due.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  bool get isOverdue {
    final d = dDay;
    return d != null && d < 0 && status != TaskStatus.done;
  }

  bool get isDueSoon {
    final d = dDay;
    return d != null && d >= 0 && d <= 1 && status != TaskStatus.done;
  }

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        branchId: j['branch_id'] as String,
        taskType: TaskTypeX.fromDb(j['task_type'] as String),
        title: j['title'] as String,
        content: j['content'] as String?,
        requesterId: j['requester_id'] as String,
        assigneeId: j['assignee_id'] as String,
        dueDate: j['due_date'] == null ? null : DateTime.parse(j['due_date'] as String),
        priority: TaskPriorityX.fromDb(j['priority'] as String),
        status: TaskStatusX.fromDb(j['status'] as String),
        memo: j['memo'] as String?,
        completedAt: j['completed_at'] == null ? null : DateTime.parse(j['completed_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

class TaskComment {
  final String id;
  final String taskId;
  final String userId;
  final String content;
  final DateTime createdAt;

  TaskComment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory TaskComment.fromJson(Map<String, dynamic> j) => TaskComment(
        id: j['id'] as String,
        taskId: j['task_id'] as String,
        userId: j['user_id'] as String,
        content: j['content'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
