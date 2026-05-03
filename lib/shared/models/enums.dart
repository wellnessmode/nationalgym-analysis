// 도메인 enum 모음. DB enum과 1:1 대응.

enum UserRole { admin, manager }

enum TaskType { directive, managerTask }

enum TaskPriority { low, normal, high, urgent }

enum TaskStatus { todo, inProgress, done, onHold }

enum MeetingStatus { draft, completed }

enum NotificationRefType { task, taskComment, meetingNote, meetingComment }

enum NotificationType {
  assigned,
  dueSoon,
  overdue,
  commented,
  completed,
  newMeetingAgenda,
  meetingCompleted,
}

/// snake_case ↔ camelCase 변환 (DB는 snake_case 문자열)
extension TaskTypeX on TaskType {
  String get dbValue => switch (this) {
        TaskType.directive => 'directive',
        TaskType.managerTask => 'manager_task',
      };
  static TaskType fromDb(String s) => switch (s) {
        'directive' => TaskType.directive,
        'manager_task' => TaskType.managerTask,
        _ => throw ArgumentError('unknown task_type: $s'),
      };
  String get label => switch (this) {
        TaskType.directive => '지시',
        TaskType.managerTask => '자체',
      };
}

extension TaskPriorityX on TaskPriority {
  String get dbValue => name; // low/normal/high/urgent — 그대로
  static TaskPriority fromDb(String s) =>
      TaskPriority.values.firstWhere((e) => e.name == s);
  String get label => switch (this) {
        TaskPriority.low => '낮음',
        TaskPriority.normal => '보통',
        TaskPriority.high => '높음',
        TaskPriority.urgent => '긴급',
      };
}

extension TaskStatusX on TaskStatus {
  String get dbValue => switch (this) {
        TaskStatus.todo => 'todo',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.done => 'done',
        TaskStatus.onHold => 'on_hold',
      };
  static TaskStatus fromDb(String s) => switch (s) {
        'todo' => TaskStatus.todo,
        'in_progress' => TaskStatus.inProgress,
        'done' => TaskStatus.done,
        'on_hold' => TaskStatus.onHold,
        _ => throw ArgumentError('unknown task_status: $s'),
      };
  String get label => switch (this) {
        TaskStatus.todo => '대기',
        TaskStatus.inProgress => '진행 중',
        TaskStatus.done => '완료',
        TaskStatus.onHold => '보류',
      };
}

extension UserRoleX on UserRole {
  String get dbValue => name;
  static UserRole fromDb(String s) =>
      UserRole.values.firstWhere((e) => e.name == s);
}

extension MeetingStatusX on MeetingStatus {
  String get dbValue => name;
  static MeetingStatus fromDb(String s) =>
      MeetingStatus.values.firstWhere((e) => e.name == s);
  String get label => switch (this) {
        MeetingStatus.draft => '어젠다',
        MeetingStatus.completed => '완료',
      };
}

extension NotificationRefTypeX on NotificationRefType {
  String get dbValue => switch (this) {
        NotificationRefType.task => 'task',
        NotificationRefType.taskComment => 'task_comment',
        NotificationRefType.meetingNote => 'meeting_note',
        NotificationRefType.meetingComment => 'meeting_comment',
      };
  static NotificationRefType fromDb(String s) => switch (s) {
        'task' => NotificationRefType.task,
        'task_comment' => NotificationRefType.taskComment,
        'meeting_note' => NotificationRefType.meetingNote,
        'meeting_comment' => NotificationRefType.meetingComment,
        _ => throw ArgumentError('unknown ref_type: $s'),
      };
}

extension NotificationTypeX on NotificationType {
  String get dbValue => switch (this) {
        NotificationType.assigned => 'assigned',
        NotificationType.dueSoon => 'due_soon',
        NotificationType.overdue => 'overdue',
        NotificationType.commented => 'commented',
        NotificationType.completed => 'completed',
        NotificationType.newMeetingAgenda => 'new_meeting_agenda',
        NotificationType.meetingCompleted => 'meeting_completed',
      };
  static NotificationType fromDb(String s) => switch (s) {
        'assigned' => NotificationType.assigned,
        'due_soon' => NotificationType.dueSoon,
        'overdue' => NotificationType.overdue,
        'commented' => NotificationType.commented,
        'completed' => NotificationType.completed,
        'new_meeting_agenda' => NotificationType.newMeetingAgenda,
        'meeting_completed' => NotificationType.meetingCompleted,
        _ => throw ArgumentError('unknown notification_type: $s'),
      };
}
