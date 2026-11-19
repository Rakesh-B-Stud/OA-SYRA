class AIConfig {
  /// Production Cloud Backend Base URL deployed on Render
  static const String backendBaseUrl = 'https://oasyra-backend-6fjr.onrender.com';

  /// Groq model identifier
  static const String grokModel = 'openai/gpt-oss-120b';
  static const String geminiModel = 'openai/gpt-oss-120b';

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
