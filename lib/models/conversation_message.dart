class ConversationMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ConversationMessage({required this.role, required this.content, required this.timestamp});

  Map<String, dynamic> toJson() {
    return {'role': role, 'content': content, 'timestamp': timestamp.toIso8601String()};
  }

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(role: json['role'], content: json['content'], timestamp: DateTime.parse(json['timestamp']));
  }

  // Convert to OpenRouter API format
  Map<String, String> toOpenRouterFormat() {
    return {'role': role, 'content': content};
  }
}
