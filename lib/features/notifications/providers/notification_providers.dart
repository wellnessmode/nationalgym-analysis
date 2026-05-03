import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());

final notificationsListProvider = FutureProvider<List<AppNotification>>((ref) async {
  return ref.read(notificationRepositoryProvider).list();
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  return ref.read(notificationRepositoryProvider).unreadCount();
});
