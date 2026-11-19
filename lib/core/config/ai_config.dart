class AIConfig {
  /// Base URL for the OASYRA FastAPI Backend Service
  /// Physical ADB Device (via `adb reverse tcp:8000 tcp:8000` or LAN): http://127.0.0.1:8000
  static const String backendBaseUrl = 'http://127.0.0.1:8000';

  /// Grok model identifier
  static const String grokModel = 'grok-4.7';
  static const String geminiModel = 'grok-4.7';

  /// Default generation parameters.
  static const double temperature = 0.7;
  static const int maxOutputTokens = 2048;

  /// Quick actions for the chatbot and dashboard.
  static const List<String> quickActions = [
    'What should I eat today?',
    'Analyze my nutrition',
    'Give me a workout',
    'Why is my health score low?',
    'Can I eat this?',
    'Help me reach my goal',
  ];
}
