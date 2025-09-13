import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:buddy/services/openrouter_service.dart';
import 'package:buddy/services/conversation_history_service.dart';
import 'package:buddy/services/memory_service.dart';
import 'package:buddy/models/memory_item.dart';
import 'package:buddy/config/app_config.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class BuddyController extends GetxController {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
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
    _initTts();
    _loadMute();
  }

  /// Initialize speech-to-text
  void _initSpeech() async {
    try {
      _speechEnabled.value = await _speechToText.initialize();
      if (_speechEnabled.value) {
        _statusMessage.value = 'Ready to listen!';
      } else {
        _statusMessage.value = 'Speech recognition not available';
      }
    } catch (e) {
      _statusMessage.value = 'Error initializing speech: $e';
      _speechEnabled.value = false;
    }
  }

  /// Initialize text-to-speech
  void _initTts() async {
    try {
      await _flutterTts.setLanguage(AppConfig.speechLanguage);
      await _flutterTts.setSpeechRate(AppConfig.speechRate);
      await _flutterTts.setVolume(AppConfig.speechVolume);
      await _flutterTts.setPitch(AppConfig.speechPitch);

      // Set up TTS completion handler
      _flutterTts.setCompletionHandler(() {
        _isSpeaking.value = false;
        _statusMessage.value = 'Ready to listen!';
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking.value = false;
        _statusMessage.value = 'TTS Error: $msg';
      });
    } catch (e) {
      _statusMessage.value = 'Error initializing TTS: $e';
    }
  }

  /// Start listening for speech input
  void startListening() async {
    if (!_speechEnabled.value || _isProcessing.value || _isSpeaking.value) return;

    try {
      await _flutterTts.stop(); // Stop any ongoing TTS
      _lastWords.value = '';
      _aiResponse.value = '';
      _isPaused.value = false;
      _waitingForMore.value = false;
      _lastPartialText = '';
      _statusMessage.value = 'Listening...';

      // Cancel any existing timers
      _pauseTimer?.cancel();
      _processingTimer?.cancel();

      await _speechToText.listen(onResult: _onSpeechResult, listenFor: AppConfig.speechTimeout, pauseFor: AppConfig.speechPause, partialResults: true, localeId: 'en_US', cancelOnError: true);
      _isListening.value = true;
    } catch (e) {
      _statusMessage.value = 'Error starting speech recognition: $e';
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
        await _processUserInput(_lastWords.value);
      } else {
        _statusMessage.value = 'No speech detected. Try again.';
      }
    } catch (e) {
      _statusMessage.value = 'Error stopping speech recognition: $e';
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
      await _flutterTts.speak(text);
    } catch (e) {
      _isSpeaking.value = false;
      _statusMessage.value = 'Error speaking response: $e';
    }
  }

  /// Stop current TTS playback
  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
      _isSpeaking.value = false;
      _statusMessage.value = 'Ready to listen!';
    } catch (e) {
      _statusMessage.value = 'Error stopping speech: $e';
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
    Get.snackbar('Memory Cleared', 'All long-term memory has been cleared');
  }

  Future<void> deleteMemoryById(String id) async {
    await _memoryService.deleteById(id);
  }

  Future<List<MemoryItem>> getAllMemory() async => _memoryService.getAll();

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
    _flutterTts.stop();
    super.onClose();
  }
}
