class AppConfig {
  // Задай API URL при сборке:
  // flutter build apk --dart-define=API_URL=https://your-backend.railway.app
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://mess2-mess2.up.railway.app',
  );

  static String get wsUrl {
    final base = apiUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$base/ws';
  }
}
