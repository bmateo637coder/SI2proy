class ApiConstants {
  const ApiConstants._();

  static const String androidEmulator = 'http://10.0.2.2:8000';
  static const String iosSimulator = 'http://localhost:8000';
  static const String physicalDevice = 'https://raices-backend-n1yy.onrender.com';

  // Override with: flutter run --dart-define=API_BASE_URL=http://...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: physicalDevice,
  );
}
