import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/tokens.dart';
import '../../../services/auth_storage.dart';
import '../../../services/supabase_client.dart';

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});
  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _newCtrl.text;
    final c = _confirmCtrl.text;
    if (n.length < 8) {
      _snack('비밀번호는 8자 이상이어야 합니다');
      return;
    }
    if (n != c) {
      _snack('비밀번호 확인이 일치하지 않습니다');
      return;
    }
    setState(() => _saving = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: n));
      // 자동 로그인이 켜져 있다면 저장된 비밀번호도 새 값으로 갱신
      if (await AuthStorage.getAutoLogin()) {
        await AuthStorage.setPassword(n);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack('비밀번호가 변경되었습니다');
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('에러: $e');
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
      appBar: AppBar(title: const Text('비밀번호 변경')),
      body: ListView(padding: const EdgeInsets.all(Tokens.s16), children: [
        Container(
          padding: const EdgeInsets.all(Tokens.s14),
          decoration: BoxDecoration(
            color: Tokens.info.withOpacity(0.08),
            borderRadius: BorderRadius.circular(Tokens.r12),
            border: Border.all(color: Tokens.info.withOpacity(0.25)),
          ),
          child: Row(children: const [
            Icon(Icons.info_outline, color: Tokens.info, size: 18),
            SizedBox(width: Tokens.s8),
            Expanded(child: Text('8자 이상. 영문·숫자·기호 조합 권장.', style: TextStyle(fontSize: 13))),
          ]),
        ),
        const SizedBox(height: Tokens.s20),
        _Label('새 비밀번호'),
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
        const SizedBox(height: Tokens.s16),
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
        const SizedBox(height: Tokens.s32),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('변경하기'),
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
      padding: const EdgeInsets.only(bottom: Tokens.s6, left: Tokens.s4),
      child: Text(text, style: Tokens.ts12.copyWith(color: Tokens.textMuted, fontWeight: FontWeight.w600)),
    );
  }
}
