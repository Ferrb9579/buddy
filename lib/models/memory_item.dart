class MemoryItem {
  final String id;
  final String content;
  final DateTime timestamp;

  MemoryItem({required this.id, required this.content, required this.timestamp});

  Map<String, dynamic> toJson() => {'id': id, 'content': content, 'timestamp': timestamp.toIso8601String()};

  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(id: json['id'] as String, content: json['content'] as String, timestamp: DateTime.parse(json['timestamp'] as String));
}
