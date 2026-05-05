/// 로그인/계정 관련 상수
class AuthConstants {
  AuthConstants._();

  /// 모든 매니저·대표 계정의 이메일 도메인. 사용자는 ID만 입력하고
  /// 시스템이 이 도메인을 자동으로 붙여 Supabase에 전달.
  static const String emailDomain = '@nationalgym.kr';

  /// 사용자가 입력한 ID (또는 전체 이메일)을 정규화된 이메일로 변환.
  /// - "ceo" → "ceo@nationalgym.kr"
  /// - "ceo@nationalgym.kr" → "ceo@nationalgym.kr"
  /// - "ceo@other.com" → "ceo@other.com" (다른 도메인 입력 시 그대로 사용)
  static String resolveEmail(String input) {
    final t = input.trim().toLowerCase();
    if (t.isEmpty) return t;
    if (t.contains('@')) return t;
    return '$t$emailDomain';
  }

  /// 이메일에서 ID 부분 추출 ("ceo@nationalgym.kr" → "ceo")
  static String localPart(String email) {
    final at = email.indexOf('@');
    if (at < 0) return email;
    return email.substring(0, at);
  }
}
