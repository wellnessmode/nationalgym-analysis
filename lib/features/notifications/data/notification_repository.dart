import '../../../services/supabase_client.dart';
import '../../../shared/models/enums.dart';

class AppNotification {
  final String id;
  final String userId;
  final NotificationRefType refType;
  final String refId;
  final NotificationType type;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.refType,
    required this.refId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        refType: NotificationRefTypeX.fromDb(j['ref_type'] as String),
        refId: j['ref_id'] as String,
        type: NotificationTypeX.fromDb(j['type'] as String),
        message: j['message'] as String,
        isRead: j['is_read'] as bool,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class NotificationRepository {
  Future<List<AppNotification>> list({int limit = 50}) async {
    final res = await supabase
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List).map((j) => AppNotification.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<int> unreadCount() async {
    final res = await supabase
        .from('notifications')
        .select('id')
        .eq('is_read', false);
    return (res as List).length;
  }

  Future<void> markRead(String id) async {
    await supabase.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllRead() async {
    await supabase.from('notifications').update({'is_read': true}).eq('is_read', false);
  }
}
