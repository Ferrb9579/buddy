import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:buddy/config/app_config.dart';
import 'package:buddy/models/conversation_message.dart';
import 'package:buddy/services/web_search_service.dart';

class OpenRouterService {
  final Dio _dio = Dio();
  final WebSearchService _webSearchService = WebSearchService();

  OpenRouterService() {
    _dio.options.baseUrl = AppConfig.openRouterBaseUrl;
    _dio.options.headers = {
      // Authorization header is applied per-call to pick up late-loaded env
      'HTTP-Referer': AppConfig.appUrl,
      'X-Title': AppConfig.appName,
      'Content-Type': 'application/json',
    };
    _dio.options.connectTimeout = AppConfig.networkTimeout;
    _dio.options.receiveTimeout = AppConfig.networkTimeout;
  }

  // Tool definitions for function calling
  List<Map<String, dynamic>> get _tools => [
    {
      'type': 'function',
      'function': {
        'name': 'web_search',
        'description': 'Search the web for current information, news, facts, or any topic. Use this when you need up-to-date information or when the user asks about current events, recent news, or factual information you might not have.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': 'The search query to look up on the web'},
            'count': {'type': 'integer', 'description': 'Number of results to return (1-10, default: 5)', 'default': 5},
          },
          'required': ['query'],
        },
      },
    },
  ];

  void _applyAuth() {
    final key = AppConfig.openRouterApiKey.trim();
    if (key.isEmpty) {
      throw Exception('OpenRouter API key is missing. Provide OPENROUTER_API_KEY via --dart-define or .env');
    }
    _dio.options.headers['Authorization'] = 'Bearer $key';
  }

  // Execute a tool call
  Future<String> _executeTool(String toolName, Map<String, dynamic> arguments) async {
    try {
      if (toolName == 'web_search') {
        final query = arguments['query'] as String;
        final count = (arguments['count'] as int?) ?? 5;

        print('🔍 Web Search Tool: Searching for "$query"');

        final results = await _webSearchService.search(query: query, count: count);

        print('✅ Web Search completed: ${results['total']} results');

        final searchResults = results['results'] as List<dynamic>;

        if (searchResults.isEmpty) {
          return 'No results found for: $query';
        }

        // Format results for the model
        final formattedResults = StringBuffer();
        formattedResults.writeln('Search results for "$query":');
        formattedResults.writeln();

        for (var i = 0; i < searchResults.length && i < count; i++) {
          final result = searchResults[i] as Map<String, dynamic>;
          formattedResults.writeln('${i + 1}. ${result['title']}');
          formattedResults.writeln('   URL: ${result['url']}');
          formattedResults.writeln('   ${result['description']}');
          formattedResults.writeln();
        }

        return formattedResults.toString();
      }

      return 'Unknown tool: $toolName';
    } catch (e, stackTrace) {
      print('❌ Error executing tool $toolName: $e');
      print('Stack trace: $stackTrace');
      return 'Error executing $toolName: $e';
    }
  }

  Future<String> generateResponse(String userMessage, {List<ConversationMessage>? conversationHistory, Map<String, String>? userInfo, String memoryBlock = ''}) async {
    try {
      _applyAuth();
      // Build the messages array with conversation history
      final messages = <Map<String, dynamic>>[];

      // Add system message with user context if available
      String systemMessage = 'You are Buddy, a helpful and friendly AI assistant. Keep your responses concise and conversational, suitable for voice interaction. When you need current information or facts you don\'t know, use the web_search tool.';

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

      // Iterative tool calling loop (max 5 iterations to prevent infinite loops)
      int maxIterations = 5;
      for (int i = 0; i < maxIterations; i++) {
        final requestData = {'model': AppConfig.defaultModel, 'messages': messages, 'max_tokens': AppConfig.maxTokens, 'temperature': AppConfig.temperature, 'tools': _tools};

        // Add delay between requests to avoid rate limits (especially after tool execution)
        if (i > 0) {
          print('⏳ Waiting 2 seconds before next request to avoid rate limit...');
          await Future.delayed(const Duration(seconds: 2));
        }

        final response = await _dio.post('/chat/completions', data: requestData);

        if (response.statusCode == 200) {
          final data = response.data;
          print('🔍 API Response: ${json.encode(data)}');

          if (data['choices'] != null && data['choices'].isNotEmpty) {
            final choice = data['choices'][0];
            final message = choice['message'];

            print('📩 Message: ${json.encode(message)}');

            // Check if model wants to call a tool
            final toolCalls = message['tool_calls'];

            // Fallback: Check if model put tool call in content (some models do this)
            final content = message['content']?.toString() ?? '';
            if ((toolCalls == null || (toolCalls is List && toolCalls.isEmpty)) && content.contains('"name"') && content.contains('web_search')) {
              print('⚠️ Model returned tool call in content instead of tool_calls field');
              print('Content: $content');

              // Try to parse and execute the tool call from content
              try {
                // Extract JSON from content
                final jsonMatch = RegExp(r'\{[^}]*"name"[^}]*\}').firstMatch(content);
                if (jsonMatch != null) {
                  final toolCallJson = json.decode(jsonMatch.group(0)!);
                  final functionName = toolCallJson['name'] as String?;
                  final parameters = toolCallJson['parameters'] as Map<String, dynamic>?;

                  if (functionName != null && functionName == 'web_search' && parameters != null) {
                    print('🔧 Executing tool from content: $functionName');
                    final toolResult = await _executeTool(functionName, parameters);

                    // Add tool result and ask model to respond with the info
                    messages.add({'role': 'assistant', 'content': 'I will search for that information.'});
                    messages.add({'role': 'user', 'content': 'Here are the search results:\n$toolResult\n\nPlease provide a natural response based on these results.'});
                    continue;
                  }
                }
              } catch (e) {
                print('❌ Failed to parse tool call from content: $e');
              }
            }

            if (toolCalls != null && toolCalls is List && toolCalls.isNotEmpty) {
              // Add the assistant's message with tool calls to conversation
              // Note: content can be null when tool_calls is present
              messages.add({'role': 'assistant', 'content': message['content'] ?? '', 'tool_calls': toolCalls});

              // Execute each tool call
              for (final toolCall in toolCalls) {
                try {
                  final toolId = toolCall['id'];
                  final function = toolCall['function'];
                  final functionName = function['name'];
                  final argumentsStr = function['arguments'] as String;

                  print('🔧 Tool call: $functionName with args: $argumentsStr');

                  final arguments = json.decode(argumentsStr) as Map<String, dynamic>;

                  // Execute the tool
                  final toolResult = await _executeTool(functionName, arguments);

                  // Add tool result to messages
                  messages.add({'role': 'tool', 'tool_call_id': toolId, 'content': toolResult});
                } catch (e, stackTrace) {
                  print('❌ Error processing tool call: $e');
                  print('Stack trace: $stackTrace');
                  // Add error result to messages so the model can try again
                  messages.add({'role': 'tool', 'tool_call_id': toolCall['id'], 'content': 'Error: $e'});
                }
              }

              // Continue loop to get final response from model
              continue;
            }

            // No tool calls, return the response
            return message['content']?.toString().trim() ?? 'Sorry, I couldn\'t generate a response.';
          }
        }

        throw Exception('Invalid response format');
      }

      throw Exception('Max tool call iterations reached');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Invalid API key. Please check your OpenRouter API key.');
      } else if (e.response?.statusCode == 429) {
        // Check if we can get retry-after header
        final retryAfter = e.response?.headers['retry-after']?.first;
        if (retryAfter != null) {
          throw Exception('Rate limit exceeded. Retry after $retryAfter seconds.');
        }
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
      _applyAuth();
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

extension OpenRouterNotificationClassifier on OpenRouterService {
  Future<Map<String, dynamic>?> classifyNotification({required String app, required String text}) async {
    try {
      _applyAuth();
      final now = DateTime.now();
      final tzOffset = now.timeZoneOffset;
      final offsetSign = tzOffset.isNegative ? '-' : '+';
      final offsetH = tzOffset.inHours.abs().toString().padLeft(2, '0');
      final offsetM = (tzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final offsetStr = 'UTC$offsetSign$offsetH:$offsetM';

      final messages = <Map<String, String>>[];
      final system = [
        'You classify phone notifications to decide if they should create a reminder.',
        'Return ONLY minified JSON with keys: {"action":"remind|ignore","when":"ISO8601 or empty","description":"short"}.',
        'Current local time: ${now.toLocal().toIso8601String()} ($offsetStr). Interpret dates/times relative to this.',
        'Be robust to typos and shorthand like: "tomorow", "tmrw", "11am", "11:00", "in 2 hours".',
        'If a specific time can be inferred, compute a future ISO8601 local datetime. If only a time is given, assume the next occurrence of that time.',
        'Always choose action="remind" when the text implies an upcoming event or task (meeting, call, pickup, appointment).',
        'Keep description under 80 chars. If no time can be inferred, set when to empty string.',
        '',
        'Examples:',
        'App: Messages\nNotification: Tomorow we have meeting at 11am -> {"action":"remind","when":"<ISO for tomorrow at 11:00 local>","description":"Meeting at 11am"}',
        'App: Gmail\nNotification: Dentist appointment 9/20 3pm -> {"action":"remind","when":"<ISO for 9/20 15:00 local>","description":"Dentist appointment"}',
        'App: Calendar\nNotification: Lunch at 1 -> {"action":"remind","when":"<ISO for next 13:00 local>","description":"Lunch at 1"}',
      ].join('\n');
      messages.add({'role': 'system', 'content': system});
      final user = 'App: $app\nNotification: $text';
      messages.add({'role': 'user', 'content': user});

      final response = await _dio.post('/chat/completions', data: {'model': AppConfig.defaultModel, 'messages': messages, 'max_tokens': 200, 'temperature': 0.1});

      if (response.statusCode == 200) {
        // toast
        print('Notification classification response: ${response.data}');
        final data = response.data;
        final choices = data['choices'];
        if (choices is List && choices.isNotEmpty) {
          final textOut = choices[0]['message']['content']?.toString().trim() ?? '';
          final jsonStart = textOut.indexOf('{');
          final jsonEnd = textOut.lastIndexOf('}');
          if (jsonStart >= 0 && jsonEnd > jsonStart) {
            final jsonStr = textOut.substring(jsonStart, jsonEnd + 1);
            final decoded = json.decode(jsonStr) as Map<String, dynamic>;
            return decoded;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
