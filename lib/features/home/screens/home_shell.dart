import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../services/supabase_client.dart';
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
      _Placeholder(title: '회의록', icon: Icons.note_alt),
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

class _Placeholder extends StatelessWidget {
  final String title;
  final IconData icon;
  const _Placeholder({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('$title 화면 — 다음 단계에서 구현', style: const TextStyle(fontSize: 16, color: Colors.grey)),
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
