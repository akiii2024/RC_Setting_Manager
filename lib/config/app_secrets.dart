class AppSecrets {
  const AppSecrets._();

  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String openWeatherApiKey =
      String.fromEnvironment('OPENWEATHER_API_KEY');

  static bool get hasGeminiApiKey => geminiApiKey.isNotEmpty;
  static bool get hasOpenWeatherApiKey => openWeatherApiKey.isNotEmpty;

  static String missingKeyMessage(String keyName) {
    return '$keyName is not configured. Pass it with '
        '--dart-define=$keyName=your_key';
  }
}
