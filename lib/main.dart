import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/env.dart';
import 'core/firebase_options.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/tokens.dart';
import 'services/supabase_client.dart';
import 'shared/widgets/mobile_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();

  // 병렬 초기화 + 타임아웃 (네트워크 hang 시 앱이 멈추지 않도록).
  // Firebase / Supabase 초기화 실패 시에도 UI 는 뜨고 로그인 화면에서 에러 표시.
  await Future.wait([
    initializeDateFormatting('ko_KR', null),
    initSupabase().timeout(const Duration(seconds: 10), onTimeout: () {}),
    Firebase.initializeApp(options: DefaultFirebaseOptions.current)
        .timeout(const Duration(seconds: 10), onTimeout: () => Firebase.app()),
  ]).catchError((e) {
    // 부팅 단계 에러는 무시하고 UI 우선 띄움
    return <dynamic>[];
  });

  runApp(const ProviderScope(child: NgApp()));
}

class NgApp extends ConsumerWidget {
  const NgApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'National Gym Workspace',
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // PC/태블릿 와이드 뷰포트에서 모바일 폭으로 강제
      builder: (context, child) {
        return Container(
          color: Tokens.navy900,
          child: MobileContainer(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
