import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/env.dart';

/// Supabase 클라이언트 초기화. main()에서 한 번만 호출.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

/// 어디서든 접근 가능한 Supabase 인스턴스
SupabaseClient get supabase => Supabase.instance.client;
