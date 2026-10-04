class ApiConstants {
  const ApiConstants._();

  static const String androidEmulator = 'http://10.0.2.2:8000';
  static const String iosSimulator = 'http://localhost:8000';
  static const String physicalDevice = 'http://52.90.0.234/api';

  // Override with: flutter run --dart-define=API_BASE_URL=http://...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: physicalDevice,
  );
}
