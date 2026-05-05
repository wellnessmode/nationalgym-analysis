import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 편의를 위한 로컬 영속 저장소.
/// - SharedPreferences: 비민감 정보 (username, 체크박스 상태)
/// - FlutterSecureStorage: 민감 정보 (password) — 웹은 암호화 localStorage,
///   네이티브는 Keychain / EncryptedSharedPreferences 사용
class AuthStorage {
  static const _kUsername = 'auth.username';     // ID 부분만 (도메인 제외)
  static const _kRememberId = 'auth.rememberId'; // 체크박스 상태
  static const _kAutoLogin = 'auth.autoLogin';   // 자동 로그인 체크
  static const _kPassword = 'auth.password';     // secure storage key

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── 일반 (SharedPreferences) ──────────────────────────────────

  static Future<String?> getUsername() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kUsername);
  }

  static Future<void> setUsername(String? v) async {
    final p = await SharedPreferences.getInstance();
    if (v == null || v.isEmpty) {
      await p.remove(_kUsername);
    } else {
      await p.setString(_kUsername, v);
    }
  }

  static Future<bool> getRememberId() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kRememberId) ?? false;
  }

  static Future<void> setRememberId(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRememberId, v);
  }

  static Future<bool> getAutoLogin() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAutoLogin) ?? false;
  }

  static Future<void> setAutoLogin(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAutoLogin, v);
  }

  // ── 민감 (Secure Storage) ─────────────────────────────────────

  static Future<String?> getPassword() async {
    try {
      return await _secure.read(key: _kPassword);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setPassword(String? v) async {
    try {
      if (v == null || v.isEmpty) {
        await _secure.delete(key: _kPassword);
      } else {
        await _secure.write(key: _kPassword, value: v);
      }
    } catch (_) {
      // Storage 접근 실패 (e.g. 일부 인앱 브라우저) — 무시
    }
  }

  /// 로그아웃·계정 전환 시 호출. ID 기억은 유지하고 password와 자동 로그인만 정리.
  static Future<void> clearSensitive() async {
    await setPassword(null);
    await setAutoLogin(false);
  }

  /// 완전 초기화 (테스트 / "기기 정리" 용)
  static Future<void> clearAll() async {
    await setUsername(null);
    await setRememberId(false);
    await setAutoLogin(false);
    await setPassword(null);
  }
}
