/// Centralized REST endpoint paths (relative to API base + /api/v1).
abstract final class ApiEndpoints {
  static const String prefix = '/api/v1';

  // Auth
  static const String register = '$prefix/auth/register';
  static const String login = '$prefix/auth/login';
  static const String refresh = '$prefix/auth/refresh';
  static const String otpSend = '$prefix/auth/otp/send';
  static const String otpVerify = '$prefix/auth/otp/verify';
  static const String me = '$prefix/auth/me';

  // Cases
  static const String cases = '$prefix/cases';
  static String caseDetail(String caseId) => '$prefix/cases/$caseId';
  static String caseStatus(String caseId) => '$prefix/cases/$caseId/status';
  static String caseTimeline(String caseId) => '$prefix/cases/$caseId/timeline';
  static String caseDuplicates(String caseId) => '$prefix/cases/$caseId/duplicates';

  // Volunteers
  static const String volunteers = '$prefix/volunteers';
  static const String volunteerAssignments = '$prefix/volunteers/assignments';

  // Zones & map data
  static const String zones = '$prefix/zones';
  static const String mapCctv = '$prefix/map/cctv';
  static const String mapPoliceStations = '$prefix/map/police-stations';
  static const String mapChokepoints = '$prefix/map/chokepoints';

  // Analytics & notifications
  static const String analytics = '$prefix/analytics';
  static const String notifications = '$prefix/notifications';

  // Face recognition
  static const String faceEncode = '$prefix/face/encode';
  static const String faceMatch = '$prefix/face/match';
  static String faceMatchesForCase(String caseId) => '$prefix/face/matches/$caseId';

  // Aadhaar
  static const String aadhaarExtract = '$prefix/aadhaar/extract';
  static const String aadhaarMatch = '$prefix/aadhaar/match';
  static String aadhaarRecords(String caseId) => '$prefix/aadhaar/records/$caseId';

  // Admin
  static const String users = '$prefix/users';
  static const String admin = '$prefix/admin';
}
