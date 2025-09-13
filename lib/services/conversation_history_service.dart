import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buddy/models/conversation_message.dart';

class ConversationHistoryService {
  static const String _historyKey = 'conversation_history';
  static const int _maxHistoryLength = 20; // Keep last 20 messages for context

  Future<List<ConversationMessage>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);

      if (historyJson == null) return [];

      final List<dynamic> historyList = json.decode(historyJson);
      return historyList.map((item) => ConversationMessage.fromJson(item)).toList();
    } catch (e) {
      print('Error loading conversation history: $e');
      return [];
    }
  }

  Future<void> addMessage(ConversationMessage message) async {
    try {
      final history = await getHistory();
      history.add(message);

      // Keep only the last N messages to prevent unlimited growth
      if (history.length > _maxHistoryLength) {
        history.removeRange(0, history.length - _maxHistoryLength);
      }

      await _saveHistory(history);
    } catch (e) {
      print('Error adding message to history: $e');
    }
  }

  Future<void> addUserMessage(String content) async {
    final message = ConversationMessage(role: 'user', content: content, timestamp: DateTime.now());
    await addMessage(message);
  }

  Future<void> addAssistantMessage(String content) async {
    final message = ConversationMessage(role: 'assistant', content: content, timestamp: DateTime.now());
    await addMessage(message);
  }

  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      print('Error clearing conversation history: $e');
    }
  }

  Future<void> _saveHistory(List<ConversationMessage> history) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = json.encode(history.map((message) => message.toJson()).toList());
    await prefs.setString(_historyKey, historyJson);
  }

  // Get recent context for AI (last few messages)
  Future<List<ConversationMessage>> getRecentContext({int limit = 10}) async {
    final history = await getHistory();
    if (history.length <= limit) return history;
    return history.sublist(history.length - limit);
  }

  // Extract user information from conversation history
  Future<Map<String, String>> extractUserInfo() async {
    final history = await getHistory();
    final userInfo = <String, String>{};

    for (final message in history) {
      if (message.role == 'user') {
        final content = message.content.toLowerCase();

        // Simple pattern matching for name extraction
        final namePatterns = [RegExp(r'\bi am ([a-zA-Z]+)', caseSensitive: false), RegExp(r'\bmy name is ([a-zA-Z]+)', caseSensitive: false), RegExp(r'\bcall me ([a-zA-Z]+)', caseSensitive: false), RegExp(r"\bi'm ([a-zA-Z]+)", caseSensitive: false)];

        for (final pattern in namePatterns) {
          final match = pattern.firstMatch(content);
          if (match != null) {
            userInfo['name'] = match.group(1)!;
            break;
          }
        }

        // You can add more patterns for extracting other information
        // like location, preferences, etc.
      }
    }

    return userInfo;
  }
}
