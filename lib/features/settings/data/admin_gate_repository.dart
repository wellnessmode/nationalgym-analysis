import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_client.dart';

/// 대표 전용 메뉴 (메모 체크 / 로그 체크) 의 추가 비밀번호 게이트.
class AdminGateRepository {
  Future<void> setPassword(String newPassword) async {
    await supabase.rpc('set_admin_gate_password', params: {'new_password': newPassword});
  }

  Future<bool> verify(String input) async {
    final res = await supabase.rpc('verify_admin_gate', params: {'input': input});
    return res == true;
  }

  Future<bool> isSet() async {
    final res = await supabase.rpc('admin_gate_is_set');
    return res == true;
  }
}

final adminGateRepositoryProvider = Provider<AdminGateRepository>((ref) => AdminGateRepository());

/// 현재 세션 동안 게이트 통과 여부 캐시. 로그아웃 / 앱 재시작 시 초기화.
final adminGateUnlockedProvider = StateProvider<bool>((_) => false);
