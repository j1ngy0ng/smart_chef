class AppConfig {
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String geminiNutritionApiKey = String.fromEnvironment(
    'GEMINI_NUTRITION_API_KEY',
  );
  static const String pixabayApiKey = String.fromEnvironment('PIXABAY_API_KEY');
  static const String spoonacularApiKey = String.fromEnvironment(
    'SPOONACULAR_API_KEY',
  );
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static String require(String keyName, String value) {
    if (value.trim().isEmpty) {
      throw StateError(
        'Missing required configuration: $keyName. '
        'Provide it with --dart-define=$keyName=...',
      );
    }
    return value;
  }

  static String requireGeminiApiKey([String feature = 'Gemini feature']) {
    if (geminiApiKey.trim().isEmpty) {
      throw StateError(
        '$feature requires GEMINI_API_KEY. '
        'Provide it with --dart-define=GEMINI_API_KEY=...',
      );
    }
    return geminiApiKey;
  }

  static String requireGeminiNutritionApiKey() {
    if (geminiNutritionApiKey.trim().isNotEmpty) {
      return geminiNutritionApiKey;
    }
    if (geminiApiKey.trim().isNotEmpty) {
      return geminiApiKey;
    }
    throw StateError(
      'Nutrition AI requires GEMINI_NUTRITION_API_KEY (or GEMINI_API_KEY). '
      'Provide it with --dart-define.',
    );
  }
}
