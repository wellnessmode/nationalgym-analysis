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
    final filter = ref.watch(taskFilterProvider);
    final isAdmin = me?.isAdmin == true;
    final addLabel = isAdmin ? '업무 할당' : '업무 추가';
    // 매니저는 '할당 업무' 필터에서 새 업무 생성 불가 (할당은 대표만 권한)
    final canCreate = me != null && !(!isAdmin && filter == TaskFilter.directives);

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
                  subtitle: !canCreate
                      ? '대표가 할당하면 여기에 표시됩니다'
                      : (isAdmin
                          ? '아래 버튼으로 매니저에게 업무를 할당하세요'
                          : '아래 버튼으로 새 업무를 추가하세요'),
                  action: canCreate
                      ? FilledButton.icon(
                          onPressed: openForm,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(addLabel),
                        )
                      : null,
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
      // 리스트가 있을 때만 FAB. 빈 상태일 땐 EmptyState 안의 가운데 버튼만 보임 (중복 방지).
      // 매니저가 '할당 업무' 필터에 있으면 FAB 숨김 (할당은 대표 권한).
      floatingActionButton: tasksAsync.value?.isNotEmpty == true && canCreate
          ? FloatingActionButton.extended(
              onPressed: openForm,
              icon: const Icon(Icons.add, size: 20),
              label: Text(addLabel),
            )
          : null,
    );
  }
}
