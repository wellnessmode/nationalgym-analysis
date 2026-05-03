import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/home/screens/home_shell.dart';
import '../services/supabase_client.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = supabase.auth.currentSession;
      final loggedIn = session != null;
      final loggingIn = state.matchedLocation == '/login';

      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/';
      return null;
    },
    refreshListenable: _AuthChangeNotifier(),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeShell()),
    ],
  );
});

/// Supabase auth 상태 변화를 GoRouter에 통지
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}
