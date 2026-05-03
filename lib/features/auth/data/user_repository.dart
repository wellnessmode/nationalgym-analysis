import '../../../services/supabase_client.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/branch.dart';

class UserRepository {
  /// 현재 로그인된 사용자의 public.users row
  /// 트리거가 auth_user_id 채워놓았다는 가정.
  Future<AppUser?> getCurrent() async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) return null;
    final res = await supabase
        .from('users')
        .select()
        .eq('auth_user_id', authUser.id)
        .maybeSingle();
    if (res == null) return null;
    return AppUser.fromJson(res);
  }

  Future<List<AppUser>> listAll() async {
    final res = await supabase.from('users').select().order('role').order('name');
    return (res as List).map((j) => AppUser.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Branch>> listBranches() async {
    final res = await supabase.from('branches').select().order('name');
    return (res as List).map((j) => Branch.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// 본인이 접근 가능한 지점들 (admin → 전체, manager → user_branches 매핑)
  Future<List<Branch>> listMyBranches() async {
    final me = await getCurrent();
    if (me == null) return [];
    if (me.isAdmin) {
      return listBranches();
    }
    final res = await supabase
        .from('user_branches')
        .select('branches(*)')
        .eq('user_id', me.id);
    return (res as List)
        .map((row) => Branch.fromJson((row as Map<String, dynamic>)['branches'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateFcmToken(String userId, String? token) async {
    await supabase.from('users').update({'fcm_token': token}).eq('id', userId);
  }
}
