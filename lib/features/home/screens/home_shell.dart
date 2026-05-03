import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/fcm_service.dart';
import '../../../services/supabase_client.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../meeting_notes/screens/meeting_note_list_screen.dart';
import '../../tasks/screens/task_list_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    const pages = [
      TaskListScreen(),
      MeetingNoteListScreen(),
      _SettingsPage(),
    ];
    const titles = ['업무', '회의록', '설정'];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(titles[_index]),
          if (me != null) ...[
            const SizedBox(width: 8),
            Text(
              '· ${me.name}',
              style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.normal),
            ),
          ],
        ]),
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: '업무'),
          NavigationDestination(icon: Icon(Icons.note_alt_outlined), selectedIcon: Icon(Icons.note_alt), label: '회의록'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}

class _SettingsPage extends ConsumerStatefulWidget {
  const _SettingsPage();
  @override
  ConsumerState<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<_SettingsPage> {
  bool _enabling = false;

  Future<void> _enableNotifications() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    setState(() => _enabling = true);
    try {
      final token = await FcmService.requestPermissionAndGetToken();
      if (token == null) {
        throw Exception('알림 권한이 거부되었습니다');
      }
      await ref.read(userRepositoryProvider).updateFcmToken(me.id, token);
      ref.invalidate(currentUserProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 활성화 완료')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final hasToken = me?.fcmToken != null && me!.fcmToken!.isNotEmpty;

    return ListView(children: [
      if (me != null) ...[
        ListTile(
          leading: const Icon(Icons.person),
          title: Text(me.name),
          subtitle: Text('${me.email} · ${me.role.name}'),
        ),
        const Divider(height: 1),
      ],
      ListTile(
        leading: Icon(
          hasToken ? Icons.notifications_active : Icons.notifications_off,
          color: hasToken ? Colors.green : Colors.grey,
        ),
        title: const Text('푸시 알림'),
        subtitle: Text(
          hasToken
              ? '활성화됨 (이 기기로 알림 수신 중)'
              : 'iPhone Safari는 홈 화면에 추가 후 standalone 모드에서만 작동',
        ),
        trailing: hasToken
            ? const Text('ON', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
            : FilledButton(
                onPressed: _enabling ? null : _enableNotifications,
                child: _enabling
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('활성화'),
              ),
      ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('로그아웃'),
        onTap: () async {
          // 로그아웃 시 FCM 토큰 제거 (이 기기에서 더 이상 알림 안 받게)
          if (me != null && hasToken) {
            try {
              await ref.read(userRepositoryProvider).updateFcmToken(me.id, null);
            } catch (_) {}
          }
          await supabase.auth.signOut();
        },
      ),
    ]);
  }
}
