/// 빌드 시점에 주입되는 환경변수 (--dart-define 또는 --dart-define-from-file)
///
/// 로컬 개발: `flutter run -d chrome --dart-define-from-file=env.json`
/// CI 빌드:    GitHub Actions가 secrets에서 읽어 --dart-define 으로 전달
///
/// 누락 시 빌드는 되지만 런타임에 init 실패 → 즉시 명확한 에러
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseVapidKey = String.fromEnvironment('FIREBASE_VAPID_PUBLIC_KEY');

  /// 빌드 시점 (KST). CI 가 --dart-define=BUILD_TIME=... 으로 주입.
  static const buildTime = String.fromEnvironment('BUILD_TIME', defaultValue: '로컬');
  /// 빌드된 git commit 짧은 SHA (7자).
  static const buildSha = String.fromEnvironment('BUILD_SHA', defaultValue: 'dev');

  static void assertConfigured() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (firebaseApiKey.isEmpty) missing.add('FIREBASE_API_KEY');
    if (firebaseProjectId.isEmpty) missing.add('FIREBASE_PROJECT_ID');
    if (firebaseAppId.isEmpty) missing.add('FIREBASE_APP_ID');
    if (firebaseMessagingSenderId.isEmpty) missing.add('FIREBASE_MESSAGING_SENDER_ID');
    if (firebaseVapidKey.isEmpty) missing.add('FIREBASE_VAPID_PUBLIC_KEY');
    if (missing.isNotEmpty) {
      throw StateError('환경변수 미설정: ${missing.join(", ")}');
    }
  }
}
