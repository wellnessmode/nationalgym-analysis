import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());

final notificationsListProvider = FutureProvider<List<AppNotification>>((ref) async {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return [];
  return ref.read(notificationRepositoryProvider).list(myUserId: me.id);
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final me = ref.watch(currentUserProvider).valueOrNull;
  if (me == null) return 0;
  return ref.read(notificationRepositoryProvider).unreadCount(myUserId: me.id);
});
