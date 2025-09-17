import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:buddy/controllers/Buddy.controller.dart';
import 'package:buddy/models/memory_item.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late Future<List<MemoryItem>> _future;
  final BuddyController controller = Get.find<BuddyController>();
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = controller.getAllMemory();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = controller.getAllMemory();
    });
  }

  Future<void> _showMemoryDialog({required String title, String initial = '', required Future<void> Function(String value) onSubmit}) async {
    _textController.text = initial;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: _textController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Memory fact', hintText: 'e.g., I prefer green tea'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      final value = _textController.text.trim();
      if (value.isEmpty) {
        // Silent fail per request (no toast)
        return;
      }
      await onSubmit(value);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Long-term Memory'),
        actions: [
          IconButton(
            tooltip: 'Clear All',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear all memory?'),
                  content: const Text('This will remove all long-term memory entries.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (confirm == true) {
                await controller.clearAllMemory();
                await _refresh();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<MemoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.memory, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No memories yet', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _showMemoryDialog(
                        title: 'Add memory',
                        onSubmit: (value) async {
                          await controller.addMemory(value);
                        },
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Memory'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final m = items[index];
                final time = DateFormat('MMM dd, HH:mm').format(m.timestamp);
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.fact_check_outlined),
                    title: Text(m.content),
                    subtitle: Text(time),
                    onTap: () async {
                      await _showMemoryDialog(
                        title: 'Edit memory',
                        initial: m.content,
                        onSubmit: (value) async {
                          await controller.updateMemory(id: m.id, newContent: value);
                        },
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            await _showMemoryDialog(
                              title: 'Edit memory',
                              initial: m.content,
                              onSubmit: (value) async {
                                await controller.updateMemory(id: m.id, newContent: value);
                              },
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await controller.deleteMemoryById(m.id);
                            await _refresh();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _showMemoryDialog(
            title: 'Add memory',
            onSubmit: (value) async {
              await controller.addMemory(value);
              Get.snackbar('Memory', 'Added');
            },
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}
