import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/tokens.dart';
import '../data/admin_gate_repository.dart';

/// 메모 체크 / 로그 체크 진입 시 묻는 추가 비밀번호 설정.
class AdminGateSetupScreen extends ConsumerStatefulWidget {
  const AdminGateSetupScreen({super.key});

  @override
  ConsumerState<AdminGateSetupScreen> createState() => _AdminGateSetupScreenState();
}

class _AdminGateSetupScreenState extends ConsumerState<AdminGateSetupScreen> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool? _isSet; // null = 로딩 중

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final v = await ref.read(adminGateRepositoryProvider).isSet();
      if (mounted) setState(() => _isSet = v);
    } catch (_) {
      if (mounted) setState(() => _isSet = false);
    }
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _newCtrl.text.trim();
    final c = _confirmCtrl.text.trim();
    if (n.length < 4) {
      _snack('비밀번호는 4자 이상');
      return;
    }
    if (n != c) {
      _snack('비밀번호 확인 불일치');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminGateRepositoryProvider).setPassword(n);
      // 새로 설정했으므로 현재 세션 unlock 상태로 처리
      ref.read(adminGateUnlockedProvider.notifier).state = true;
      if (!mounted) return;
      _snack('비밀번호가 저장되었습니다');
      Navigator.of(context).pop();
    } catch (e) {
      _snack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메모/로그 체크 비밀번호')),
      body: ListView(padding: const EdgeInsets.all(Tokens.s16), children: [
        Container(
          padding: const EdgeInsets.all(Tokens.s14),
          decoration: BoxDecoration(
            color: Tokens.gold500.withOpacity(0.06),
            borderRadius: BorderRadius.circular(Tokens.r12),
            border: Border.all(color: Tokens.gold500.withOpacity(0.25)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_outlined, color: Tokens.gold600, size: 18),
            const SizedBox(width: Tokens.s10),
            Expanded(
              child: Text(
                _isSet == null
                    ? '확인 중...'
                    : (_isSet == true
                        ? '비밀번호 설정됨. 새 값으로 변경할 수 있습니다.'
                        : '아직 설정 안 됨. 처음 설정하면 메모 체크·로그 체크 진입 시 비밀번호 입력이 필요합니다.'),
                style: Tokens.ts13.copyWith(height: 1.5),
              ),
            ),
          ]),
        ),
        const SizedBox(height: Tokens.s20),
        _Label('새 비밀번호 (4자 이상)'),
        TextField(
          controller: _newCtrl,
          obscureText: !_showNew,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, size: 18),
            suffixIcon: IconButton(
              icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _showNew = !_showNew),
            ),
          ),
        ),
        const SizedBox(height: Tokens.s12),
        _Label('비밀번호 확인'),
        TextField(
          controller: _confirmCtrl,
          obscureText: !_showConfirm,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, size: 18),
            suffixIcon: IconButton(
              icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
              onPressed: () => setState(() => _showConfirm = !_showConfirm),
            ),
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: Tokens.s24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isSet == true ? '변경하기' : '설정하기'),
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(text, style: Tokens.ts12.copyWith(color: Tokens.textMuted, fontWeight: FontWeight.w600)),
    );
  }
}
