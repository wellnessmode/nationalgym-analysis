import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SignOutScope;
import '../../../core/tokens.dart';
import '../../../services/auth_storage.dart';
import '../../../services/fcm_service.dart';
import '../../../services/supabase_client.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/section.dart';
import 'help_screen.dart';
import 'manager_notes_audit_screen.dart';
import 'staff_activity_screen.dart';
import 'password_change_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _enabling = false;

  Future<void> _enableNotifications() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    setState(() => _enabling = true);
    try {
      final token = await FcmService.requestPermissionAndGetToken();
      if (token == null) throw Exception('알림 권한이 거부되었습니다');
      await ref.read(userRepositoryProvider).updateFcmToken(me.id, token);
      ref.invalidate(currentUserProvider);
      _snack('알림 활성화 완료');
    } catch (e) {
      _snack('실패: $e');
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  Future<void> _logout() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me != null && me.fcmToken != null && me.fcmToken!.isNotEmpty) {
      try {
        await ref.read(userRepositoryProvider).updateFcmToken(me.id, null);
      } catch (_) {}
    }
    // 자동 로그인 해제: 다음 사람이 이 기기로 들어왔을 때 이 사용자 비밀번호로
    // 자동 진입되지 않도록 password + autoLogin 플래그 제거. 아이디 기억은 유지.
    await AuthStorage.clearSensitive();
    // global scope: 모든 기기·세션 무효화. 캐시된 세션도 확실히 정리.
    await supabase.auth.signOut(scope: SignOutScope.global);
    ref.invalidate(currentUserProvider);
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(currentUserProvider);
    final me = meAsync.valueOrNull;
    final hasToken = me?.fcmToken != null && me!.fcmToken!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.only(bottom: Tokens.s32),
      children: [
        // Profile hero (또는 로딩 스켈레톤)
        Container(
          margin: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s24, Tokens.s16, 0),
          padding: const EdgeInsets.all(Tokens.s20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.r20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Tokens.navy900, Tokens.navy700],
            ),
          ),
          child: me == null
              ? Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Tokens.s16),
                  const Expanded(
                    child: SizedBox(
                      height: 18,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation(Colors.white54),
                      ),
                    ),
                  ),
                ])
              : Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.20)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      me.name.isNotEmpty ? me.name.characters.first : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: Tokens.s16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            me.name,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Tokens.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: me.isAdmin ? Tokens.gold500 : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(Tokens.r4),
                          ),
                          child: Text(
                            me.isAdmin ? '대표' : '매니저',
                            style: TextStyle(color: me.isAdmin ? Tokens.navy900 : Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        me.email,
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                ]),
        ),

        Section(title: '알림', children: [
          ListTile(
            leading: Icon(
              hasToken ? Icons.notifications_active : Icons.notifications_off_outlined,
              color: hasToken ? Tokens.success : Tokens.textMuted,
            ),
            title: const Text('푸시 알림', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              hasToken ? '활성화됨' : 'iOS는 홈 화면 추가 후 활성화',
              style: Tokens.ts12.copyWith(color: Tokens.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: hasToken
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Tokens.success.withOpacity(0.10), borderRadius: BorderRadius.circular(Tokens.r999)),
                    child: const Text('ON', style: TextStyle(color: Tokens.success, fontSize: 11, fontWeight: FontWeight.w800)),
                  )
                : SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: _enabling ? null : _enableNotifications,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(72, 32),
                        padding: const EdgeInsets.symmetric(horizontal: Tokens.s12),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      child: _enabling
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('활성화'),
                    ),
                  ),
          ),
        ]),

        Section(title: '도움말', children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('사용법', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '업무·회의록·메모장·알림 기본 사용 안내',
              style: Tokens.ts12.copyWith(color: Tokens.textMuted),
            ),
            trailing: const Icon(Icons.chevron_right, color: Tokens.textFaint),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const HelpScreen(),
            )),
          ),
        ]),

        if (me?.isAdmin == true)
          Section(title: '대표 전용', children: [
            ListTile(
              leading: const Icon(Icons.fact_check_outlined, color: Tokens.gold600),
              title: const Text('매니저 기록 열람', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '매니저들의 메모를 모아보기',
                style: Tokens.ts12.copyWith(color: Tokens.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right, color: Tokens.textFaint),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ManagerNotesAuditScreen(),
              )),
            ),
            // 직원 활동 로그 — ceo@nationalgym.kr 만
            if (me?.email == 'ceo@nationalgym.kr')
              ListTile(
                leading: const Icon(Icons.timeline, color: Tokens.gold600),
                title: const Text('직원 활동 로그', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '로그인 / 메모 / 업무 / 회의록 활동 통계',
                  style: Tokens.ts12.copyWith(color: Tokens.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right, color: Tokens.textFaint),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const StaffActivityScreen(),
                )),
              ),
          ]),

        Section(title: '계정', children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('비밀번호 변경', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: Tokens.textFaint),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PasswordChangeScreen(),
            )),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Tokens.danger),
            title: const Text('로그아웃', style: TextStyle(color: Tokens.danger, fontWeight: FontWeight.w600)),
            onTap: _logout,
          ),
        ]),

        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s32, Tokens.s16, 0),
          child: Center(
            child: Text(
              'NG · v0.1.0',
              style: Tokens.ts11.copyWith(color: Tokens.textFaint),
            ),
          ),
        ),
      ],
    );
  }
}
