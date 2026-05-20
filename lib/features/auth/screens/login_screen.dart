import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth_constants.dart';
import '../../../core/tokens.dart';
import '../../../services/auth_storage.dart';
import '../../../services/biometric_service.dart';
import '../../../services/fcm_service.dart';
import '../../../services/supabase_client.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _loading = false;
  bool _passwordVisible = false;
  bool _rememberId = false;
  bool _autoLogin = false;
  bool _biometricAvailable = false;
  String _biometricLabel = '생체인식';
  bool _bootstrapping = true; // 첫 진입 시 자동 로그인 시도 중
  String? _error;

  @override
  void initState() {
    super.initState();
    // 입력에 따라 admin 차단 토글 UI 갱신
    _idCtrl.addListener(_onIdChange);
    _bootstrap();
  }

  void _onIdChange() {
    if (mounted) setState(() {});
  }

  /// 저장된 ID/비번/체크 상태 로드 + 조건 충족 시 자동 로그인 시도
  Future<void> _bootstrap() async {
    final savedId = await AuthStorage.getUsername();
    final remember = await AuthStorage.getRememberId();
    final auto = await AuthStorage.getAutoLogin();
    final bioOk = await BiometricService.isAvailable();
    final bioLabel = await BiometricService.describe();

    if (!mounted) return;
    setState(() {
      if (savedId != null) _idCtrl.text = savedId;
      _rememberId = remember;
      _autoLogin = auto;
      _biometricAvailable = bioOk;
      _biometricLabel = bioLabel;
    });

    // 자동 로그인 시도: autoLogin + 저장된 password 둘 다 있을 때만.
    if (auto && (savedId?.isNotEmpty ?? false)) {
      final savedPw = await AuthStorage.getPassword();
      if (savedPw != null && savedPw.isNotEmpty && mounted) {
        _passwordCtrl.text = savedPw;
        bool proceed = true;
        if (bioOk) {
          proceed = await BiometricService.authenticate(
            reason: '$bioLabel(으)로 로그인',
          );
        }
        if (proceed && mounted) {
          await _signIn(savedAlreadyVerified: true);
          if (mounted) setState(() => _bootstrapping = false);
          return;
        }
      }
    }
    if (mounted) setState(() => _bootstrapping = false);
  }

  @override
  void dispose() {
    _idCtrl.removeListener(_onIdChange);
    _idCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn({bool savedAlreadyVerified = false}) async {
    if (_loading) return;
    final id = _idCtrl.text.trim();
    final pw = _passwordCtrl.text;
    if (id.isEmpty || pw.isEmpty) {
      setState(() => _error = '아이디와 비밀번호를 입력해주세요');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = AuthConstants.resolveEmail(id);
      // 네트워크 hang 방지 — 15초 timeout
      await supabase.auth
          .signInWithPassword(email: email, password: pw)
          .timeout(const Duration(seconds: 15));

      // 성공 → 체크 상태에 따라 저장
      if (_rememberId) {
        await AuthStorage.setUsername(AuthConstants.localPart(email));
      } else {
        await AuthStorage.setUsername(null);
      }
      await AuthStorage.setRememberId(_rememberId);
      await AuthStorage.setAutoLogin(_autoLogin);
      if (_autoLogin) {
        await AuthStorage.setPassword(pw);
      } else {
        await AuthStorage.setPassword(null);
      }

      // 로그인 성공 → FCM 토큰 자동 복원 (silent — 권한 이미 있으면 prompt X).
      // 로그아웃 시 토큰을 NULL 로 비웠으므로, 매 로그인마다 재연결 필요.
      unawaited(_silentRestoreFcm());
    } on AuthException catch (e) {
      // 자동 로그인 실패 → 저장된 비밀번호가 만료/변경됨. 정리.
      if (savedAlreadyVerified) {
        await AuthStorage.setPassword(null);
        await AuthStorage.setAutoLogin(false);
      }
      if (mounted) setState(() => _error = _humanize(e.message));
    } catch (e) {
      if (mounted) setState(() => _error = '로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 로그인 성공 직후 FCM 토큰 자동 복원 (silent).
  /// 권한 미허용이면 skip — 사용자가 설정에서 활성화하면 됨.
  /// claim_fcm_token RPC 가 current_user_id() 서버사이드로 찾으므로 userId 불필요.
  Future<void> _silentRestoreFcm() async {
    try {
      final token = await FcmService.getTokenIfAuthorized();
      if (token == null || token.isEmpty) return;
      await supabase.rpc('claim_fcm_token', params: {'token': token});
    } catch (_) {
      // 실패해도 로그인 자체엔 영향 X
    }
  }

  /// 저장된 비밀번호가 있으면 생체인식 후 로그인 — 수동 트리거 버튼용
  Future<void> _biometricLogin() async {
    final savedPw = await AuthStorage.getPassword();
    if (savedPw == null || savedPw.isEmpty) {
      _error = '저장된 비밀번호가 없습니다. 한 번 직접 로그인해주세요';
      setState(() {});
      return;
    }
    final ok = await BiometricService.authenticate(
      reason: '$_biometricLabel(으)로 로그인',
    );
    if (!ok) return;
    _passwordCtrl.text = savedPw;
    await _signIn(savedAlreadyVerified: true);
  }

  String _humanize(String s) {
    final l = s.toLowerCase();
    if (l.contains('invalid login') || l.contains('invalid_credentials')) {
      return '아이디 또는 비밀번호가 올바르지 않습니다';
    }
    if (l.contains('email not confirmed')) return '이메일 인증이 필요합니다';
    if (l.contains('too many')) return '잠시 후 다시 시도해주세요 (요청 과다)';
    return s;
  }

  void _openForgot() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ForgotPasswordScreen(initialUsername: _idCtrl.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.navy900,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: Tokens.s24, vertical: Tokens.s32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: AutofillGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LogoLockup(),
                    const SizedBox(height: Tokens.s32),
                    _buildCard(),
                    if (_bootstrapping) ...[
                      const SizedBox(height: Tokens.s12),
                      Text(
                        '자동 로그인 시도 중...',
                        textAlign: TextAlign.center,
                        style: Tokens.ts11.copyWith(
                          color: Colors.white.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
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
          '내셔널짐 직원 전용',
          style: Tokens.ts13.copyWith(color: Tokens.textMuted),
        ),
        const SizedBox(height: Tokens.s24),

        // ID 입력 (도메인 자동)
        TextField(
          controller: _idCtrl,
          keyboardType: TextInputType.text,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: InputDecoration(
            labelText: '아이디',
            prefixIcon: const Icon(Icons.person_outline, size: 18),
            suffixText: AuthConstants.emailDomain,
            suffixStyle: Tokens.ts13.copyWith(color: Tokens.textMuted),
          ),
        ),
        const SizedBox(height: Tokens.s12),

        // Password
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
              onPressed: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
            ),
          ),
        ),

        const SizedBox(height: Tokens.s8),

        // ── 옵션: 아이디 기억 / 자동 로그인 ──
        _CheckRow(
          label: '아이디 기억하기',
          value: _rememberId,
          onChanged: (v) => setState(() {
            _rememberId = v;
            if (!v) _autoLogin = false;
          }),
        ),
        _CheckRow(
          label: '자동 로그인 (기기에 비밀번호 저장)',
          value: _autoLogin,
          onChanged: (v) => setState(() {
            _autoLogin = v;
            if (v) _rememberId = true;
          }),
        ),

        if (_error != null) ...[
          const SizedBox(height: Tokens.s8),
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
                child: Text(_error!,
                    style: Tokens.ts13.copyWith(color: Tokens.danger)),
              ),
            ]),
          ),
        ],

        const SizedBox(height: Tokens.s16),

        FilledButton(
          onPressed: _loading ? null : () => _signIn(),
          child: _loading
              ? const SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('로그인'),
        ),

        // 생체인식 버튼 (네이티브 + 저장된 비번 있을 때 의미)
        if (_biometricAvailable) ...[
          const SizedBox(height: Tokens.s10),
          OutlinedButton.icon(
            onPressed: _loading ? null : _biometricLogin,
            icon: const Icon(Icons.fingerprint, size: 18),
            label: Text('$_biometricLabel(으)로 로그인'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Tokens.gold600,
              side: const BorderSide(color: Tokens.gold500),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],

        const SizedBox(height: Tokens.s12),
        Center(
          child: TextButton(
            onPressed: _openForgot,
            style: TextButton.styleFrom(
              foregroundColor: Tokens.textMuted,
              padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.s12, vertical: Tokens.s4),
            ),
            child: const Text('비밀번호 찾기'),
          ),
        ),
      ]),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(Tokens.r8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
            width: 24, height: 24,
            child: Checkbox(
              value: value,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: Tokens.s8),
          Expanded(
            child: Text(
              label,
              style: Tokens.ts13.copyWith(
                color: enabled ? Tokens.text : Tokens.textFaint,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _LogoLockup extends StatelessWidget {
  const _LogoLockup();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Image.asset(
        'assets/brand_logo.png',
        width: 140, height: 140,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
      const SizedBox(height: Tokens.s8),
      const Text(
        'WORKSPACE',
        style: TextStyle(
          color: Tokens.gold500,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'National Gym',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    ]);
  }
}
