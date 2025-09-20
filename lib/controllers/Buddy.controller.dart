import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
// Removed FlutterTts dependency in favor of ElevenLabs TTS service
import 'package:buddy/services/openrouter_service.dart';
import 'package:buddy/services/conversation_history_service.dart';
import 'package:buddy/services/memory_service.dart';
import 'package:buddy/models/memory_item.dart';
import 'package:buddy/config/app_config.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buddy/services/tts_service.dart';

class BuddyController extends GetxController {
  final SpeechToText _speechToText = SpeechToText();
  final TtsService _tts = TtsService();
  final OpenRouterService _openRouterService = OpenRouterService();
  final ConversationHistoryService _historyService = ConversationHistoryService();
  late final MemoryService _memoryService;

  final RxBool _speechEnabled = false.obs;
  final RxString _lastWords = ''.obs;
  final RxBool _isListening = false.obs;
  final RxBool _isProcessing = false.obs;
  final RxBool _isSpeaking = false.obs;
  final RxBool _isMuted = false.obs;
  final RxString _aiResponse = ''.obs;
  final RxString _statusMessage = 'Tap microphone to start'.obs;
  final RxBool _isPaused = false.obs; // New: Track if speech is paused
  final RxBool _waitingForMore = false.obs; // New: Waiting for user to continue

  Timer? _pauseTimer;
  Timer? _processingTimer;
  String _lastPartialText = '';

  // Getters
  SpeechToText get speechToText => _speechToText;
  bool get speechEnabled => _speechEnabled.value;
  String get lastWords => _lastWords.value;
  bool get isListening => _isListening.value;
  bool get isProcessing => _isProcessing.value;
  bool get isSpeaking => _isSpeaking.value;
  bool get isMuted => _isMuted.value;
  String get aiResponse => _aiResponse.value;
  String get statusMessage => _statusMessage.value;
  bool get isPaused => _isPaused.value;
  bool get waitingForMore => _waitingForMore.value;

  @override
  void onInit() {
    super.onInit();
    _memoryService = MemoryService(maxTokens: AppConfig.memoryMaxTokens);
    _initSpeech();
    // ElevenLabs TTS requires no runtime init beyond API key set in AppConfig
    _loadMute();
  }

  /// Initialize speech-to-text
  void _initSpeech() async {
    try {
      _speechEnabled.value = await _speechToText.initialize();
      if (_speechEnabled.value) {
        _statusMessage.value = 'Ready to listen!';
        _toast('Ready to listen!');
      } else {
        _statusMessage.value = 'Speech recognition not available';
        _toast('Speech recognition not available');
      }
    } catch (e) {
      _statusMessage.value = 'Error initializing speech: $e';
      _toast('Error initializing speech');
      _speechEnabled.value = false;
    }
  }

  // FlutterTTS init removed; TtsService handles playback

  /// Start listening for speech input
  void startListening() async {
    if (!_speechEnabled.value || _isProcessing.value || _isSpeaking.value) return;

    try {
      await _tts.stop(); // Stop any ongoing TTS
      _lastWords.value = '';
      _aiResponse.value = '';
      _isPaused.value = false;
      _waitingForMore.value = false;
      _lastPartialText = '';
      _statusMessage.value = 'Listening...';
      _toast('Listening...');

      // Cancel any existing timers
      _pauseTimer?.cancel();
      _processingTimer?.cancel();

      await _speechToText.listen(onResult: _onSpeechResult, listenFor: AppConfig.speechTimeout, pauseFor: AppConfig.speechPause, partialResults: true, localeId: 'en_US', cancelOnError: true);
      _isListening.value = true;
    } catch (e) {
      _statusMessage.value = 'Error starting speech recognition: $e';
      _toast('Error starting speech');
      _isListening.value = false;
    }
  }

  /// Stop listening for speech input
  void stopListening() async {
    try {
      await _speechToText.stop();
      _isListening.value = false;
      _isPaused.value = false;
      _waitingForMore.value = false;

      // Cancel timers
      _pauseTimer?.cancel();
      _processingTimer?.cancel();

      if (_lastWords.value.isNotEmpty) {
        _statusMessage.value = 'Processing...';
        _toast('Processing...');
        await _processUserInput(_lastWords.value);
      } else {
        _statusMessage.value = 'No speech detected. Try again.';
        _toast('No speech detected.');
      }
    } catch (e) {
      _statusMessage.value = 'Error stopping speech recognition: $e';
      _toast('Error stopping speech');
      _isListening.value = false;
      _isPaused.value = false;
      _waitingForMore.value = false;
    }
  }

  /// Handle speech recognition results with intelligent pause detection
  void _onSpeechResult(SpeechRecognitionResult result) {
    final currentText = result.recognizedWords;
    _lastWords.value = currentText;

    if (currentText.isNotEmpty) {
      // Check if new words were added (user is still speaking)
      if (currentText.length > _lastPartialText.length) {
        _lastPartialText = currentText;
        _isPaused.value = false;
        _waitingForMore.value = false;
        _statusMessage.value = 'Listening...';

        // Cancel existing pause timer since user is still speaking
        _pauseTimer?.cancel();

        // Start intelligent pause detection
        _startPauseDetection();
      }
    }

    // Only auto-process on final result if it's been long enough
    if (result.finalResult) {
      _pauseTimer?.cancel();
      _processingTimer?.cancel();
      _isListening.value = false;
      _isPaused.value = false;
      _waitingForMore.value = false;

      if (_lastWords.value.isNotEmpty) {
        _statusMessage.value = 'Processing...';
        _toast('Processing...');
        _processUserInput(_lastWords.value);
      }
    }
  }

  /// Start intelligent pause detection
  void _startPauseDetection() {
    _pauseTimer?.cancel();

    _pauseTimer = Timer(AppConfig.intelligentPause, () {
      if (_isListening.value && _lastWords.value.isNotEmpty) {
        _isPaused.value = true;
        _waitingForMore.value = true;
        _statusMessage.value = 'Paused... Continue speaking or tap to process';

        // Start longer timer for auto-processing
        _startAutoProcessTimer();
      }
    });
  }

  /// Start auto-process timer after longer pause
  void _startAutoProcessTimer() {
    _processingTimer?.cancel();

    _processingTimer = Timer(Duration(seconds: AppConfig.speechPause.inSeconds - AppConfig.intelligentPause.inSeconds), () {
      if (_isListening.value && _lastWords.value.isNotEmpty) {
        // Auto-process after extended pause
        stopListening();
      }
    });
  }

  /// Force process current speech (for manual processing)
  void processCurrentSpeech() {
    if (_lastWords.value.isNotEmpty && _isListening.value) {
      stopListening();
    }
  }

  /// Process user input and get AI response
  Future<void> _processUserInput(String userInput) async {
    if (userInput.trim().isEmpty) return;

    _isProcessing.value = true;

    try {
      _statusMessage.value = 'Getting AI response...';
      _toast('Getting AI response...');

      // Save user message to history
      await _historyService.addUserMessage(userInput);

      // Get conversation history and user info for context
      final conversationHistory = await _historyService.getRecentContext(limit: 8);
      final userInfo = await _historyService.extractUserInfo();
      // Use memory as JSON array for the model to reason about
      final memoryJson = await _memoryService.asMemoryJsonArray();

      // Generate AI response with context
      final response = await _openRouterService.generateResponse(userInput, conversationHistory: conversationHistory, userInfo: userInfo, memoryBlock: memoryJson);

      _aiResponse.value = response;

      // Save AI response to history
      await _historyService.addAssistantMessage(response);

      // Background: extract and update memory
      unawaited(_updateMemory(userInput, response, null));

      // Convert AI response to speech
      await _speakResponse(response);
    } catch (e) {
      _statusMessage.value = 'Error: $e';
      _toast('Error occurred');
      await _speakResponse('Sorry, I encountered an error processing your request.');
    } finally {
      _isProcessing.value = false;
    }
  }

  Future<void> _updateMemory(String userTurn, String assistantTurn, String? userName) async {
    final lines = await _openRouterService.extractMemory(userTurn: userTurn, assistantTurn: assistantTurn, userName: userName);
    if (lines.isEmpty) return;
    await _memoryService.upsertMemoryLines(lines);
  }

  /// Convert text to speech
  Future<void> _speakResponse(String text) async {
    if (text.isEmpty) return;

    try {
      if (_isMuted.value) {
        // When muted, don't speak but still show the response.
        _isSpeaking.value = false;
        _statusMessage.value = 'Muted';
        return;
      }
      _isSpeaking.value = true;
      _statusMessage.value = 'Speaking...';
      final cleaned = _stripEmojis(text);
      await _tts.speak(cleaned);
      _isSpeaking.value = false;
      _statusMessage.value = 'Ready to listen!';
    } catch (e) {
      _isSpeaking.value = false;
      _statusMessage.value = 'Error speaking response: $e';
    }
  }

  // Remove emojis and related variation/ZWJ characters from TTS text
  String _stripEmojis(String input) {
    // Emoji ranges + variation selectors + ZWJ + regional indicators
    final emojiRegex = RegExp(
      r"[\u{1F600}-\u{1F64F}]|" // Emoticons
      r"[\u{1F300}-\u{1F5FF}]|" // Misc Symbols and Pictographs
      r"[\u{1F680}-\u{1F6FF}]|" // Transport & Map
      r"[\u{2600}-\u{26FF}]|" // Misc symbols
      r"[\u{2700}-\u{27BF}]|" // Dingbats
      r"[\u{1F1E6}-\u{1F1FF}]|" // Regional Indicator Symbols
      r"[\u{1F900}-\u{1F9FF}]|" // Supplemental Symbols and Pictographs
      r"[\u{1FA70}-\u{1FAFF}]|" // Symbols & Pictographs Extended-A
      r"[\u{200D}]|" // Zero Width Joiner
      r"[\u{2640}-\u{2642}]|" // Gender symbols
      r"[\u{FE0F}]", // Variation Selector-16
      unicode: true,
    );
    final withoutEmoji = input.replaceAll(emojiRegex, '');
    // Collapse multiple spaces created by removals
    return withoutEmoji.replaceAll(RegExp(r"\s+"), ' ').trim();
  }

  /// Stop current TTS playback
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
      _isSpeaking.value = false;
      _statusMessage.value = 'Ready to listen!';
      _toast('Ready to listen!');
    } catch (e) {
      _statusMessage.value = 'Error stopping speech: $e';
      _toast('Error stopping speech');
    }
  }

  /// Toggle between listening and stopping
  void toggleListening() {
    if (_isSpeaking.value) {
      stopSpeaking();
    } else if (_isListening.value) {
      stopListening();
    } else if (!_isProcessing.value) {
      startListening();
    }
  }

  /// Mute/unmute TTS and persist setting
  Future<void> toggleMute() async {
    _isMuted.value = !_isMuted.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('buddy_tts_muted', _isMuted.value);
    if (_isMuted.value && _isSpeaking.value) {
      await stopSpeaking();
    }
    _toast(_isMuted.value ? 'Muted' : 'Unmuted');
  }

  Future<void> _loadMute() async {
    final prefs = await SharedPreferences.getInstance();
    _isMuted.value = prefs.getBool('buddy_tts_muted') ?? false;
  }

  /// Allow typed message input (bypasses STT)
  Future<void> processTypedInput(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_isListening.value) {
      stopListening();
    }
    if (_isSpeaking.value) {
      await stopSpeaking();
    }
    _lastWords.value = trimmed;
    await _processUserInput(trimmed);
  }

  /// Get the appropriate icon for the current state
  String get currentIcon {
    if (_isSpeaking.value) return 'volume_up';
    if (_isProcessing.value) return 'hourglass_empty';
    if (_isListening.value) return 'mic';
    return 'mic_none';
  }

  /// Clear conversation history
  Future<void> clearHistory() async {
    try {
      await _historyService.clearHistory();
      _statusMessage.value = 'Conversation history cleared';
      _lastWords.value = '';
      _aiResponse.value = '';
    } catch (e) {
      _statusMessage.value = 'Error clearing history: $e';
    }
  }

  /// Memory controls
  Future<void> clearAllMemory() async {
    await _memoryService.clearAll();
    // Toasts removed per request
  }

  Future<void> deleteMemoryById(String id) async {
    await _memoryService.deleteById(id);
  }

  Future<List<MemoryItem>> getAllMemory() async => _memoryService.getAll();

  Future<void> updateMemory({required String id, required String newContent}) async {
    await _memoryService.updateMemory(id: id, newContent: newContent);
  }

  Future<String> addMemory(String content) async {
    return _memoryService.addMemory(content);
  }

  /// Get conversation history for display
  Future<List<Map<String, dynamic>>> getConversationHistory() async {
    try {
      final history = await _historyService.getHistory();
      return history.map((message) => {'role': message.role, 'content': message.content, 'timestamp': message.timestamp}).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  void onClose() {
    _pauseTimer?.cancel();
    _processingTimer?.cancel();
    _speechToText.stop();
    _tts.stop();
    super.onClose();
  }

  void _toast(String message) {
    if (message.trim().isEmpty) return;
    // Toasts removed per request
  }
}
