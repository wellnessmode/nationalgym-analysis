import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/env.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'services/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();
  await initializeDateFormatting('ko_KR', null);
  await initSupabase();
  runApp(const ProviderScope(child: NgApp()));
}

class NgApp extends ConsumerWidget {
  const NgApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '내셔널짐 업무',
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
