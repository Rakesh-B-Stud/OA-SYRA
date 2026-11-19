class ApiConfig {
  /// Base URL for the ML inference service (Development: ADB reversed 127.0.0.1 or Emulator 10.0.2.2).
  static const String mlBaseUrl = 'http://127.0.0.1:8000';

  /// Endpoint for meal image prediction.
  static const String predictMealEndpoint = '$mlBaseUrl/predict_meal';

  /// Endpoint for health check.
  static const String healthEndpoint = '$mlBaseUrl/health';

  /// Request timeout in seconds.
  static const int requestTimeoutSeconds = 15;
}
