import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../services/supabase_client.dart';
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

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    return ListView(children: [
      if (me != null) ...[
        ListTile(
          leading: const Icon(Icons.person),
          title: Text(me.name),
          subtitle: Text('${me.email} · ${me.role.name}'),
        ),
        const Divider(),
      ],
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('로그아웃'),
        onTap: () => supabase.auth.signOut(),
      ),
    ]);
  }
}
