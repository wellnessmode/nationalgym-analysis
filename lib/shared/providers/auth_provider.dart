import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/user_repository.dart';
import '../../services/supabase_client.dart';
import '../models/app_user.dart';
import '../models/branch.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

/// 현재 로그인 사용자 (public.users row).
/// 로그인/로그아웃 이벤트에만 재조회 (token refresh는 무시).
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final sub = supabase.auth.onAuthStateChange.listen((data) {
    // signedIn / signedOut / userUpdated 만 처리.
    // tokenRefreshed (10분마다 발생) 은 무시 — 안 그러면 UI가 자꾸 깜빡임.
    if (data.event == AuthChangeEvent.signedIn ||
        data.event == AuthChangeEvent.signedOut ||
        data.event == AuthChangeEvent.userUpdated) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(sub.cancel);
  return ref.read(userRepositoryProvider).getCurrent();
});

/// 본인이 접근 가능한 지점 목록
final myBranchesProvider = FutureProvider<List<Branch>>((ref) async {
  ref.watch(currentUserProvider);
  return ref.read(userRepositoryProvider).listMyBranches();
});

/// 모든 사용자
final allUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.read(userRepositoryProvider).listAll();
});

/// 모든 지점
final allBranchesProvider = FutureProvider<List<Branch>>((ref) async {
  return ref.read(userRepositoryProvider).listBranches();
});

/// 사용자 ID → 담당 지점 목록 맵 (admin이 매니저별 담당 지점 표시용)
final allUserBranchesProvider = FutureProvider<Map<String, List<Branch>>>((ref) async {
  final res = await supabase.from('user_branches').select('user_id, branches(*)');
  final map = <String, List<Branch>>{};
  for (final row in res as List) {
    final r = row as Map<String, dynamic>;
    final uid = r['user_id'] as String;
    final b = r['branches'] as Map<String, dynamic>?;
    if (b != null) {
      map.putIfAbsent(uid, () => []).add(Branch.fromJson(b));
    }
  }
  return map;
});
