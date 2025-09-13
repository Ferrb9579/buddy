import 'package:dio/dio.dart';
import 'package:buddy/config/app_config.dart';
import 'package:buddy/models/conversation_message.dart';

class OpenRouterService {
  final Dio _dio = Dio();

  OpenRouterService() {
    _dio.options.baseUrl = AppConfig.openRouterBaseUrl;
    _dio.options.headers = {'Authorization': 'Bearer ${AppConfig.openRouterApiKey}', 'HTTP-Referer': AppConfig.appUrl, 'X-Title': AppConfig.appName, 'Content-Type': 'application/json'};
    _dio.options.connectTimeout = AppConfig.networkTimeout;
    _dio.options.receiveTimeout = AppConfig.networkTimeout;
  }

  Future<String> generateResponse(String userMessage, {List<ConversationMessage>? conversationHistory, Map<String, String>? userInfo, String memoryBlock = ''}) async {
    try {
      // Build the messages array with conversation history
      final messages = <Map<String, String>>[];

      // Add system message with user context if available
      String systemMessage = 'You are Buddy, a helpful and friendly AI assistant. Keep your responses concise and conversational, suitable for voice interaction.';

      // Provide real-time info (date/time and timezone) to the model
      final now = DateTime.now();
      final tzOffset = now.timeZoneOffset;
      final offsetSign = tzOffset.isNegative ? '-' : '+';
      final offsetH = tzOffset.inHours.abs().toString().padLeft(2, '0');
      final offsetM = (tzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final offsetStr = 'UTC$offsetSign$offsetH:$offsetM';
      systemMessage += '\nCurrent local date/time: ${now.toLocal().toIso8601String()} (${now.weekday}) | Timezone: ${now.timeZoneName} ($offsetStr)';

      if (userInfo != null && userInfo.isNotEmpty) {
        systemMessage += ' Here\'s what I know about the user: ';
        userInfo.forEach((key, value) {
          systemMessage += '$key: $value. ';
        });
      }

      // Include long-term memory (JSON array) if available
      if (memoryBlock.trim().isNotEmpty) {
        systemMessage += '\nLong-term memory (as JSON array of facts):\n$memoryBlock';
      }

      messages.add({'role': 'system', 'content': systemMessage});

      // Add conversation history (recent context)
      if (conversationHistory != null) {
        for (final message in conversationHistory) {
          messages.add(message.toOpenRouterFormat());
        }
      }

      // Add current user message
      messages.add({'role': 'user', 'content': userMessage});

      final response = await _dio.post('/chat/completions', data: {'model': AppConfig.defaultModel, 'messages': messages, 'max_tokens': AppConfig.maxTokens, 'temperature': AppConfig.temperature});

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content']?.toString().trim() ?? 'Sorry, I couldn\'t generate a response.';
        }
      }

      throw Exception('Invalid response format');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Invalid API key. Please check your OpenRouter API key.');
      } else if (e.response?.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout. Please check your internet connection.');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to generate response: $e');
    }
  }
}

extension OpenRouterMemory on OpenRouterService {
  // Ask the model to extract durable memory lines given the last user + assistant messages.
  Future<List<String>> extractMemory({required String userTurn, required String assistantTurn, String? userName}) async {
    try {
      final messages = <Map<String, String>>[];
      final sys = AppConfig.memoryExtractionPrompt;
      messages.add({'role': 'system', 'content': sys});

      final convo = StringBuffer();
      convo.writeln('User: $userTurn');
      convo.writeln('Assistant: $assistantTurn');

      messages.add({'role': 'user', 'content': convo.toString()});

      final response = await _dio.post('/chat/completions', data: {'model': AppConfig.defaultModel, 'messages': messages, 'max_tokens': 120, 'temperature': 0.2});

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        String text = '';
        final choices = data['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map && first['message'] is Map) {
            text = (first['message']['content'] ?? '').toString();
          }
        }
        // Split into lines, trim empties
        final lines = text.split(RegExp(r'\r?\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

        // Remove numbering/bullets if present
        return lines.map((l) => l.replaceFirst(RegExp(r'^[-*\d+.\)\s]+'), '')).where((l) => l.isNotEmpty).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
