import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/tokens.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/notification_repository.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림함'),
        actions: [
          notifsAsync.maybeWhen(
            data: (list) => list.any((n) => !n.isRead)
                ? TextButton(
                    onPressed: () async {
                      final me = ref.read(currentUserProvider).valueOrNull;
                      if (me == null) return;
                      await ref
                          .read(notificationRepositoryProvider)
                          .markAllRead(myUserId: me.id);
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('모두 읽음'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notifsAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: '알림이 없습니다',
              subtitle: '새 업무·댓글·회의록 알림이 여기 표시됩니다',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsListProvider);
              await ref.read(notificationsListProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: Tokens.s64, endIndent: Tokens.s16),
              itemBuilder: (_, i) => _Tile(
                notif: list[i],
                onTap: () async {
                  if (!list[i].isRead) {
                    await ref.read(notificationRepositoryProvider).markRead(list[i].id);
                    ref.invalidate(notificationsListProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  }
                },
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('에러: $e', style: Tokens.ts13)),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _Tile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (notif.type) {
      NotificationType.assigned => (Icons.assignment_outlined, Tokens.info),
      NotificationType.completed => (Icons.check_circle_outline, Tokens.success),
      NotificationType.commented => (Icons.chat_bubble_outline, Tokens.navy900),
      NotificationType.dueSoon => (Icons.timer_outlined, Tokens.warning),
      NotificationType.overdue => (Icons.warning_amber_rounded, Tokens.danger),
      NotificationType.newMeetingAgenda => (Icons.event_note_outlined, Tokens.gold600),
      NotificationType.meetingCompleted => (Icons.event_available_outlined, Tokens.success),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s12),
          color: notif.isRead ? null : Tokens.info.withOpacity(0.04),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(Tokens.r8)),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: Tokens.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(notif.message, style: Tokens.ts14.copyWith(
                  fontWeight: notif.isRead ? FontWeight.w400 : FontWeight.w600,
                )),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MM-dd HH:mm').format(notif.createdAt.toLocal()),
                  style: Tokens.ts11.copyWith(color: Tokens.textFaint),
                ),
              ]),
            ),
            if (!notif.isRead) Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Tokens.info, shape: BoxShape.circle),
            ),
          ]),
        ),
      ),
    );
  }
}
