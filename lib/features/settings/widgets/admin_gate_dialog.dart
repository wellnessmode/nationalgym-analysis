import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/tokens.dart';
import '../data/admin_gate_repository.dart';
import '../screens/admin_gate_setup_screen.dart';

/// 메모 체크 / 로그 체크 진입 전 게이트 비밀번호 묻는 모달.
/// 통과하면 [adminGateUnlockedProvider] 를 true 로 + true 반환.
/// 게이트 미설정이면 설정 화면으로 안내 후 false 반환.
Future<bool> ensureAdminGateUnlocked(BuildContext context, WidgetRef ref) async {
  // 이미 이번 세션에서 통과했으면 통과
  if (ref.read(adminGateUnlockedProvider)) return true;

  final repo = ref.read(adminGateRepositoryProvider);
  bool isSet;
  try {
    isSet = await repo.isSet();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('확인 실패: $e')));
    }
    return false;
  }

  if (!isSet) {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('비밀번호 미설정'),
        content: const Text('메모/로그 체크 비밀번호가 아직 설정되지 않았어요. 지금 설정할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('아니오')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('설정하러 가기')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const AdminGateSetupScreen(),
      ));
    }
    return false;
  }

  // 설정돼 있음 → 입력 모달
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AdminGatePromptDialog(),
  );
  return ok == true;
}

class _AdminGatePromptDialog extends ConsumerStatefulWidget {
  const _AdminGatePromptDialog();

  @override
  ConsumerState<_AdminGatePromptDialog> createState() => _AdminGatePromptDialogState();
}

class _AdminGatePromptDialogState extends ConsumerState<_AdminGatePromptDialog> {
  final _ctrl = TextEditingController();
  bool _checking = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _ctrl.text;
    if (input.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final ok = await ref.read(adminGateRepositoryProvider).verify(input);
      if (!mounted) return;
      if (ok) {
        ref.read(adminGateUnlockedProvider.notifier).state = true;
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = '비밀번호가 일치하지 않습니다');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '확인 실패: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('비밀번호 입력'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '메모/로그 체크 메뉴는 추가 비밀번호가 필요합니다',
          style: Tokens.ts12.copyWith(color: Tokens.textMuted, height: 1.5),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          obscureText: !_show,
          autofocus: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, size: 18),
            suffixIcon: IconButton(
              icon: Icon(_show ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: Tokens.ts12.copyWith(color: Tokens.danger)),
        ],
      ]),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          child: _checking
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('확인'),
        ),
      ],
    );
  }
}
