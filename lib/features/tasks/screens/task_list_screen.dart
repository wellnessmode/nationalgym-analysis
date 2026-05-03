import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../providers/task_providers.dart';
import '../widgets/filter_bar.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(filteredTasksProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      body: Column(children: [
        const FilterBar(),
        Expanded(
          child: tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return const Center(
                  child: Text('표시할 업무가 없습니다', style: TextStyle(color: Colors.grey)),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(filteredTasksProvider);
                  await ref.read(filteredTasksProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 80),
                  itemCount: tasks.length,
                  itemBuilder: (_, i) => TaskCard(
                    task: tasks[i],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(taskId: tasks[i].id),
                    )),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('에러: $e')),
          ),
        ),
      ]),
      floatingActionButton: me == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TaskFormScreen(),
              )),
              icon: const Icon(Icons.add),
              label: Text(me.isAdmin ? '지시 작성' : '업무 추가'),
            ),
    );
  }
}
