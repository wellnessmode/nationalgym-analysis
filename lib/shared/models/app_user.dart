import 'enums.dart';

/// 앱 사용자 (public.users). Supabase auth.User와 다름 (혼동 방지 위해 AppUser).
class AppUser {
  final String id;
  final String? authUserId;
  final String email;
  final String name;
  final String? phone;
  final UserRole role;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    required this.authUserId,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    required this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        authUserId: j['auth_user_id'] as String?,
        email: j['email'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        role: UserRoleX.fromDb(j['role'] as String),
        fcmToken: j['fcm_token'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}
