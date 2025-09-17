import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buddy/models/memory_item.dart';

class MemoryService {
  static const String _memoryKey = 'buddy_memory_items';
  // Approximate token limit; we estimate ~4 chars per token for English.
  final int maxTokens;

  MemoryService({required this.maxTokens});

  Future<List<MemoryItem>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_memoryKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = (json.decode(jsonStr) as List).map((e) => MemoryItem.fromJson(e as Map<String, dynamic>)).toList();
      // Sort by timestamp asc to make trimming from the start easy
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveAll(List<MemoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_memoryKey, json.encode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_memoryKey);
  }

  Future<void> deleteById(String id) async {
    final all = await getAll();
    all.removeWhere((e) => e.id == id);
    await _saveAll(all);
  }

  Future<void> updateMemory({required String id, required String newContent}) async {
    var all = await getAll();
    final idx = all.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final updated = MemoryItem(id: id, content: newContent.trim(), timestamp: DateTime.now());
    all[idx] = updated;
    await _saveAll(all);
  }

  Future<String> addMemory(String content) async {
    final all = await getAll();
    final now = DateTime.now();
    final item = MemoryItem(id: '${now.microsecondsSinceEpoch}-${content.hashCode}', content: content.trim(), timestamp: now);
    all.add(item);
    while (_totalTokens(all) > maxTokens && all.isNotEmpty) {
      all.removeAt(0);
    }
    await _saveAll(all);
    return item.id;
  }

  // Rough token estimator: ~1 token ~ 4 chars (including spaces/punct). Use 3.5 to be conservative.
  int _estimateTokens(String text) {
    if (text.isEmpty) return 0;
    return (text.length / 3.5).ceil();
  }

  int _totalTokens(List<MemoryItem> items) {
    final joined = items.map((e) => e.content).join('\n');
    return _estimateTokens(joined);
  }

  Future<void> upsertMemoryLines(List<String> lines) async {
    if (lines.isEmpty) return;
    final cleaned = lines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    var all = await getAll();
    final now = DateTime.now();
    // Robust dedupe and simple update rules
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final existingNorm = all.map((e) => norm(e.content)).toSet();
    for (final l in cleaned) {
      final nl = norm(l);
      if (nl.isEmpty) continue;
      // If this looks like a name update, remove previous "name" facts
      if (RegExp(r'\bname\b', caseSensitive: false).hasMatch(l)) {
        all.removeWhere((e) => RegExp(r'\bname\b', caseSensitive: false).hasMatch(e.content));
        // refresh existingNorm since we removed entries
        existingNorm
          ..clear()
          ..addAll(all.map((e) => norm(e.content)));
      }
      if (existingNorm.contains(nl)) continue;
      all.add(MemoryItem(id: '${now.microsecondsSinceEpoch}-${l.hashCode}', content: l, timestamp: now));
      existingNorm.add(nl);
    }

    // Enforce token budget by trimming oldest items
    while (_totalTokens(all) > maxTokens && all.isNotEmpty) {
      all.removeAt(0);
    }

    await _saveAll(all);
  }

  // Return memory as a JSON array string for prompts
  Future<String> asMemoryJsonArray() async {
    final all = await getAll();
    final list = all.map((e) => e.content).toList();
    return json.encode(list);
  }

  Future<String> asSystemMemoryBlock() async {
    final all = await getAll();
    if (all.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('<MEMORY>');
    for (final m in all) {
      buffer.writeln(m.content);
    }
    buffer.write('</MEMORY>');
    return buffer.toString();
  }
}
