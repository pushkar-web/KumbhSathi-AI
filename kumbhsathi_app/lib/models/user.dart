import '../core/constants/enums.dart';

/// Authenticated user, as returned by the backend auth endpoints.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.email,
    this.languageCode = 'en',
  });

  final String id;
  final String fullName;
  final UserRole role;
  final String? phone;
  final String? email;
  final String languageCode;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        role: UserRole.fromString(json['role'] as String?),
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        languageCode: json['language_code'] as String? ?? 'en',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'role': role.name,
        'phone': phone,
        'email': email,
        'language_code': languageCode,
      };
}
