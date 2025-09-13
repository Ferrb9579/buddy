class AppConfig {
  // OpenRouter API Configuration
  static const String openRouterApiKey = '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'; // Replace with your actual API key
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  static const String appName = 'Buddy Speech Bot';
  static const String appUrl = 'https://buddy-app.com';

  // Model Configuration
  static const String defaultModel = 'google/gemma-2-27b-it';
  static const int maxTokens = 150;
  static const double temperature = 0.7;

  // Speech Configuration
  static const String speechLanguage = 'en-US';
  static const double speechRate = 0.6;
  static const double speechVolume = 1.0;
  static const double speechPitch = 0.7;

  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration speechTimeout = Duration(seconds: 60); // Extended timeout
  static const Duration speechPause = Duration(seconds: 6); // Longer pause before auto-processing
  static const Duration intelligentPause = Duration(seconds: 2); // Pause detection for UI feedback

  // Memory Configuration
  // Cap long-term memory to ~10k tokens.
  static const int memoryMaxTokens = 10000;

  // Prompt used to extract durable memories from a conversation turn.
  static const String memoryExtractionPrompt =
      'You are a memory extraction agent. From the latest user/assistant messages, extract up to 3 short, atomic facts that would be useful as long-term memory.\n'
      '- Each fact should be a single concise sentence in third person.\n'
      '- If a new fact updates an older one (e.g., name change), output only the most recent fact.\n'
      '- Do NOT include generic chitchat or transient states.\n'
      '- Output ONLY the facts as plain lines (no bullets/numbering). If none, output nothing.';
}
