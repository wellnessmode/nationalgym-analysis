import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/user_repository.dart';
import '../../services/supabase_client.dart';
import '../models/app_user.dart';
import '../models/branch.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());

/// 현재 로그인 사용자 (public.users row).
/// auth 상태 변화 시 자동 재조회.
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  // auth 상태 변화 시 invalidate
  supabase.auth.onAuthStateChange.listen((_) {
    ref.invalidateSelf();
  });
  return ref.read(userRepositoryProvider).getCurrent();
});

/// 본인이 접근 가능한 지점 목록
final myBranchesProvider = FutureProvider<List<Branch>>((ref) async {
  // 현재 사용자 변화 시 invalidate
  ref.watch(currentUserProvider);
  return ref.read(userRepositoryProvider).listMyBranches();
});

/// 모든 사용자 (admin이 directive 만들 때 담당자 선택용)
final allUsersProvider = FutureProvider<List<AppUser>>((ref) async {
  return ref.read(userRepositoryProvider).listAll();
});

/// 모든 지점
final allBranchesProvider = FutureProvider<List<Branch>>((ref) async {
  return ref.read(userRepositoryProvider).listBranches();
});
