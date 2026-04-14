class AppConfig {
  // Задай API URL при сборке:
  // flutter build apk --dart-define=API_URL=https://your-backend.railway.app
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://your-backend.railway.app',
  );

  static String get wsUrl {
    final base = apiUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$base/ws';
  }
}
