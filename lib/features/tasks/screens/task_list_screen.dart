import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/tokens.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
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
    final isAdmin = me?.isAdmin == true;
    final addLabel = isAdmin ? '지시 작성' : '업무 추가';

    void openForm() => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const TaskFormScreen(),
        ));

    return Scaffold(
      body: Column(children: [
        const FilterBar(),
        Expanded(
          child: tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return EmptyState(
                  icon: Icons.inbox_outlined,
                  title: '표시할 업무가 없습니다',
                  subtitle: isAdmin
                      ? '아래 버튼으로 매니저에게 지시를 발행하세요'
                      : '아래 버튼으로 새 업무를 추가하세요',
                  action: FilledButton.icon(
                    onPressed: me == null ? null : openForm,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(addLabel),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(filteredTasksProvider);
                  await ref.read(filteredTasksProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: Tokens.s8, bottom: 100),
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
            loading: () => ListView(
              padding: const EdgeInsets.only(top: Tokens.s8),
              children: const [
                TaskCardSkeleton(),
                TaskCardSkeleton(),
                TaskCardSkeleton(),
              ],
            ),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline,
              title: '불러오기 실패',
              subtitle: '$e',
              action: TextButton(
                onPressed: () => ref.invalidate(filteredTasksProvider),
                child: const Text('다시 시도'),
              ),
            ),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: me == null ? null : openForm,
        icon: const Icon(Icons.add, size: 20),
        label: Text(addLabel),
      ),
    );
  }
}
