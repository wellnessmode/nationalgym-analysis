import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/env.dart';

/// FCM 푸시 토큰 발급·갱신·앱 내 메시지 핸들링.
class FcmService {
  static FirebaseMessaging get _msg => FirebaseMessaging.instance;

  /// iOS Safari 16.4+ 또는 Chrome 등에서 권한 요청 후 토큰 발급.
  /// 권한 거부 시 null.
  static Future<String?> requestPermissionAndGetToken() async {
    final settings = await _msg.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    return _msg.getToken(vapidKey: Env.firebaseVapidKey);
  }

  /// 현재 권한 상태만 조회 (토큰 발급 시도 안 함).
  static Future<AuthorizationStatus> currentAuthorizationStatus() async {
    final settings = await _msg.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// 포그라운드 메시지 스트림 (앱이 떠있을 때 도착).
  /// SnackBar 등으로 표시할 수 있음.
  static Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;
}
