/// Static, compile-time app configuration.
abstract final class AppConstants {
  static const String appName = 'KumbhSathi AI';
  static const String appVersion = '1.0.0';

  /// Base URL of the FastAPI backend. Override at build time with:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  /// (10.0.2.2 = host loopback from an Android emulator.)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:8000',
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Responsive breakpoints (dp)
  static const double mobileBreakpoint = 600;
  static const double desktopBreakpoint = 1200;

  // Map defaults — centered on the Kumbh Mela (Nashik/Trimbak) region per CSV data.
  static const double defaultMapLat = 19.9975;
  static const double defaultMapLng = 73.7898;
  static const double defaultMapZoom = 12;

  // Supported language codes (from CSV + design system).
  static const List<String> supportedLanguages = [
    'en', 'hi', 'mr', 'gu', 'ta', 'bn', 'kn', 'te', 'mai', 'bho', 'awa',
  ];

  // Secure storage keys
  static const String kAccessToken = 'access_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kUserJson = 'user_json';
}
