/// Build-time configuration. Override with:
///   flutter run --dart-define=API_BASE_URL=https://api.example.sch.id
class AppConfig {
  const AppConfig._();

  // 10.0.2.2 is the host machine as seen from the Android emulator; use localhost for web/desktop/iOS sim.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');
}
