import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth_constants.dart';
import '../../../core/tokens.dart';
import '../../../services/supabase_client.dart';

/// 비밀번호 찾기 — Supabase resetPasswordForEmail 호출.
/// 실제 메일 수신은 사내 메일 인프라가 없을 수 있으므로
/// 사용자에게 "대표에게 초기화 요청" 우회 가이드도 함께 안내한다.
class ForgotPasswordScreen extends StatefulWidget {
  /// 로그인 화면에서 입력 중이던 ID prefill용
  final String? initialUsername;
  const ForgotPasswordScreen({super.key, this.initialUsername});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _idCtrl;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: widget.initialUsername ?? '');
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      setState(() => _error = '아이디를 입력해주세요');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final email = AuthConstants.resolveEmail(id);
      await supabase.auth.resetPasswordForEmail(email);
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '요청 실패: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 찾기')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Tokens.s24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _sent ? _buildSent() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        '아이디를 입력하시면\n등록된 이메일로 비밀번호 재설정 링크를 보내드려요',
        style: Tokens.ts14.copyWith(color: Tokens.textMuted, height: 1.5),
      ),
      const SizedBox(height: Tokens.s20),

      TextField(
        controller: _idCtrl,
        keyboardType: TextInputType.text,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _send(),
        decoration: InputDecoration(
          labelText: '아이디',
          prefixIcon: const Icon(Icons.person_outline, size: 18),
          suffixText: AuthConstants.emailDomain,
          suffixStyle: Tokens.ts13.copyWith(color: Tokens.textMuted),
        ),
      ),

      if (_error != null) ...[
        const SizedBox(height: Tokens.s12),
        _ErrorBox(message: _error!),
      ],

      const SizedBox(height: Tokens.s24),
      FilledButton(
        onPressed: _sending ? null : _send,
        child: _sending
            ? const SizedBox(
                height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('재설정 링크 받기'),
      ),

      const SizedBox(height: Tokens.s20),
      Container(
        padding: const EdgeInsets.all(Tokens.s12),
        decoration: BoxDecoration(
          color: Tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(Tokens.r8),
          border: Border.all(color: Tokens.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 14, color: Tokens.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '메일 수신이 불가하면 대표에게 직접 비밀번호 초기화를 요청해주세요. '
              '대표는 설정 → 매니저 관리에서 임시 비밀번호로 재발급할 수 있습니다.',
              style: Tokens.ts11.copyWith(color: Tokens.textMuted, height: 1.55),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildSent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const SizedBox(height: Tokens.s24),
      const Icon(Icons.mark_email_read_outlined, size: 56, color: Tokens.success),
      const SizedBox(height: Tokens.s12),
      Text('재설정 메일 발송됨',
          style: Tokens.ts18.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: Tokens.s8),
      Text(
        '"${AuthConstants.resolveEmail(_idCtrl.text)}" 로 보낸 메일에서\n링크를 눌러 새 비밀번호를 설정하세요.',
        textAlign: TextAlign.center,
        style: Tokens.ts13.copyWith(color: Tokens.textMuted, height: 1.5),
      ),
      const SizedBox(height: Tokens.s24),
      FilledButton.tonal(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('로그인 화면으로'),
      ),
    ]);
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tokens.s12),
      decoration: BoxDecoration(
        color: Tokens.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(Tokens.r8),
        border: Border.all(color: Tokens.danger.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Tokens.danger, size: 16),
        const SizedBox(width: Tokens.s8),
        Expanded(
          child: Text(message, style: Tokens.ts13.copyWith(color: Tokens.danger)),
        ),
      ]),
    );
  }
}
