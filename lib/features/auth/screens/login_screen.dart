import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/tokens.dart';
import '../../../services/supabase_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _passwordVisible = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = _humanize(e.message));
    } catch (e) {
      setState(() => _error = '로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanize(String s) {
    if (s.toLowerCase().contains('invalid login')) return '이메일 또는 비밀번호가 올바르지 않습니다';
    if (s.toLowerCase().contains('email not confirmed')) return '이메일 인증이 필요합니다';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.navy900,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.s24, vertical: Tokens.s32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo lockup
                  const _LogoLockup(),
                  const SizedBox(height: Tokens.s48),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(Tokens.s24),
                    decoration: BoxDecoration(
                      color: Tokens.surface,
                      borderRadius: BorderRadius.circular(Tokens.r20),
                      boxShadow: Tokens.shadowLg,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('로그인', style: Tokens.ts22.copyWith(color: Tokens.text)),
                      const SizedBox(height: Tokens.s4),
                      Text(
                        '내셔널짐 PT 매니저 전용',
                        style: Tokens.ts13.copyWith(color: Tokens.textMuted),
                      ),
                      const SizedBox(height: Tokens.s24),

                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: '이메일',
                          prefixIcon: Icon(Icons.alternate_email, size: 18),
                        ),
                      ),
                      const SizedBox(height: Tokens.s12),
                      TextField(
                        controller: _passwordCtrl,
                        focusNode: _passwordFocus,
                        obscureText: !_passwordVisible,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _signIn(),
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _passwordVisible ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Tokens.s12),
                        Container(
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
                              child: Text(_error!, style: Tokens.ts13.copyWith(color: Tokens.danger)),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: Tokens.s20),
                      FilledButton(
                        onPressed: _loading ? null : _signIn,
                        child: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('로그인'),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoLockup extends StatelessWidget {
  const _LogoLockup();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // 누끼 처리된 NATIONAL GYM 엠블럼 (투명 배경)
      Image.asset(
        'assets/brand_logo_transparent.png',
        width: 120,
        height: 120,
        fit: BoxFit.contain,
      ),
      const SizedBox(height: Tokens.s12),
      const Text(
        '내셔널짐 업무',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    ]);
  }
}
