import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/user_repository.dart';
import '../../services/supabase_client.dart';
import '../models/app_user.dart';
import '../models/branch.dart';
import '../utils/branch_label.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

/// 현재 로그인 사용자 (public.users row).
/// auth user.id가 변경된 시점에만 재조회 (token refresh는 무시).
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  String? lastUserId = supabase.auth.currentUser?.id;

  final sub = supabase.auth.onAuthStateChange.listen((data) {
    final currentId = data.session?.user.id;
    // user.id가 바뀐 경우 (로그인/로그아웃/사용자 전환). token refresh 시엔 동일.
    if (currentId != lastUserId) {
      lastUserId = currentId;
      ref.invalidateSelf();
    }
  });
  ref.onDispose(sub.cancel);

  return ref.read(userRepositoryProvider).getCurrent();
});

/// 본인이 접근 가능한 지점 목록 (1·2·3호점 순)
final myBranchesProvider = FutureProvider<List<Branch>>((ref) async {
  ref.watch(currentUserProvider);
  final list = await ref.read(userRepositoryProvider).listMyBranches();
  list.sort((a, b) => branchOrder(a.name).compareTo(branchOrder(b.name)));
  return list;
});

/// 모든 사용자
final allUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.read(userRepositoryProvider).listAll();
});

/// 모든 지점 (1·2·3호점 순)
final allBranchesProvider = FutureProvider<List<Branch>>((ref) async {
  final list = await ref.read(userRepositoryProvider).listBranches();
  list.sort((a, b) => branchOrder(a.name).compareTo(branchOrder(b.name)));
  return list;
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
