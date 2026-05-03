import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/tokens.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/utils/branch_label.dart';
import '../providers/task_providers.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(taskFilterProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final branches = ref.watch(allBranchesProvider).valueOrNull ?? [];
    final selectedBranch = ref.watch(taskBranchFilterProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Tokens.surface,
        border: Border(bottom: BorderSide(color: Tokens.border)),
      ),
      padding: const EdgeInsets.only(top: Tokens.s8, bottom: Tokens.s4),
      child: Column(children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
            children: [
              for (final f in TaskFilter.values) ...[
                _FilterChipSm(
                  label: f.label,
                  selected: selected == f,
                  onTap: () => ref.read(taskFilterProvider.notifier).state = f,
                ),
                const SizedBox(width: Tokens.s6),
              ],
            ],
          ),
        ),
        // '내 업무' 선택 시 본인확인용 안내문구
        if (selected == TaskFilter.mine)
          Container(
            margin: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s4, Tokens.s16, 0),
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s10, vertical: Tokens.s6),
            decoration: BoxDecoration(
              color: Tokens.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(Tokens.r8),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 12, color: Tokens.info),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '본인확인용 — 본인이 담당자이거나 요청자인 업무만 표시',
                  style: Tokens.ts11.copyWith(color: Tokens.info, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        if (me?.isAdmin == true && branches.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
              children: [
                _FilterChipSm(
                  label: '전체 지점',
                  selected: selectedBranch == null,
                  onTap: () => ref.read(taskBranchFilterProvider.notifier).state = null,
                  small: true,
                ),
                const SizedBox(width: Tokens.s6),
                for (final b in branches) ...[
                  _FilterChipSm(
                    label: shortBranchLabel(b.name),
                    selected: selectedBranch == b.id,
                    onTap: () => ref.read(taskBranchFilterProvider.notifier).state = b.id,
                    small: true,
                  ),
                  const SizedBox(width: Tokens.s6),
                ],
              ],
            ),
          ),
      ]),
    );
  }

}

class _FilterChipSm extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool small;
  const _FilterChipSm({
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 12.0 : 13.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.r999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? Tokens.s12 : Tokens.s14,
            vertical: small ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: selected ? Tokens.navy900 : Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.r999),
            border: Border.all(
              color: selected ? Tokens.navy900 : Tokens.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Tokens.text,
              fontSize: fontSize,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}
