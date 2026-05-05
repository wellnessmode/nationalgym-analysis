import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// 지문 / Face ID 인증 래퍼.
/// - Native (iOS / Android): local_auth 사용
/// - Web (PWA): 현재 안정 지원 X → 항상 false 반환 (자동 로그인 fallback)
class BiometricService {
  static final _auth = LocalAuthentication();

  /// 이 기기에서 생체인식이 사용 가능한지 (등록된 얼굴/지문 포함)
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final list = await _auth.getAvailableBiometrics();
      return list.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 사람이 읽을 수 있는 종류 ("Face ID", "지문", "홍채" 중 첫 번째)
  static Future<String> describe() async {
    if (kIsWeb) return '생체인식';
    try {
      final list = await _auth.getAvailableBiometrics();
      if (list.contains(BiometricType.face)) return 'Face ID';
      if (list.contains(BiometricType.iris)) return '홍채';
      if (list.contains(BiometricType.fingerprint) ||
          list.contains(BiometricType.strong) ||
          list.contains(BiometricType.weak)) return '지문';
      return '생체인식';
    } catch (_) {
      return '생체인식';
    }
  }

  /// 사용자에게 생체인식 프롬프트 표시. 성공 true / 취소·실패 false.
  static Future<bool> authenticate({String reason = '본인 확인'}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // PIN/패턴 fallback 허용
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
