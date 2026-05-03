import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../providers/task_providers.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(taskFilterProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final branches = ref.watch(allBranchesProvider).valueOrNull ?? [];
    final selectedBranch = ref.watch(taskBranchFilterProvider);

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final f in TaskFilter.values) ...[
                ChoiceChip(
                  label: Text(f.label),
                  selected: selected == f,
                  onSelected: (v) {
                    if (v) ref.read(taskFilterProvider.notifier).state = f;
                  },
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        if (me?.isAdmin == true && branches.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ChoiceChip(
                  label: const Text('전체 지점'),
                  selected: selectedBranch == null,
                  onSelected: (v) {
                    if (v) ref.read(taskBranchFilterProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 6),
                for (final b in branches) ...[
                  ChoiceChip(
                    label: Text(_shortBranchName(b.name)),
                    selected: selectedBranch == b.id,
                    onSelected: (v) {
                      if (v) ref.read(taskBranchFilterProvider.notifier).state = b.id;
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// "내셔널짐 PT 용산점" → "용산점" 으로 짧게
  String _shortBranchName(String full) {
    final parts = full.split(' ');
    return parts.last;
  }
}
