/// Domain enums shared across the app, mirroring backend vocabulary.
library;

enum UserRole {
  family,
  police,
  volunteer,
  admin;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.family,
    );
  }

  String get displayName => switch (this) {
        UserRole.family => 'Family / Reporter',
        UserRole.police => 'Police Officer',
        UserRole.volunteer => 'Volunteer',
        UserRole.admin => 'Command Center Admin',
      };

  /// Desktop-first portals render in a wide layout by default.
  bool get isDesktopPortal => this == UserRole.police || this == UserRole.admin;
}

enum CaseStatus {
  pending('Pending'),
  searching('Searching'),
  reunited('Reunited'),
  transferredToHospital('Transferred to hospital'),
  unresolved('Unresolved');

  const CaseStatus(this.label);
  final String label;

  static CaseStatus fromString(String? value) {
    return CaseStatus.values.firstWhere(
      (s) => s.label == value,
      orElse: () => CaseStatus.pending,
    );
  }
}

enum CasePriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  const CasePriority(this.label);
  final String label;

  static CasePriority fromString(String? value) {
    return CasePriority.values.firstWhere(
      (p) => p.label == value,
      orElse: () => CasePriority.medium,
    );
  }
}
