import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:buddy/controllers/Buddy.controller.dart';
import 'package:intl/intl.dart';

class ConversationHistoryPage extends StatelessWidget {
  const ConversationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final BuddyController controller = Get.find<BuddyController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () {
              _showClearConfirmation(context, controller);
            },
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear All History',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: controller.getConversationHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Error loading history', style: TextStyle(fontSize: 18, color: Colors.red[600])),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            );
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No conversation history yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text(
                    'Start talking with Buddy to see your conversation history here',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final message = history[index];
              final isUser = message['role'] == 'user';
              final timestamp = DateTime.parse(message['timestamp']);
              final formattedTime = DateFormat('MMM dd, HH:mm').format(timestamp);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: isUser ? Colors.blue[100] : Colors.green[100], borderRadius: BorderRadius.circular(20)),
                      child: Icon(isUser ? Icons.person : Icons.smart_toy, color: isUser ? Colors.blue[600] : Colors.green[600], size: 24),
                    ),
                    const SizedBox(width: 12),

                    // Message content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with name and time
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isUser ? 'You' : 'Buddy',
                                style: TextStyle(fontWeight: FontWeight.bold, color: isUser ? Colors.blue[700] : Colors.green[700]),
                              ),
                              Text(formattedTime, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Message bubble
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.blue[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isUser ? Colors.blue[200]! : Colors.green[200]!, width: 1),
                            ),
                            child: Text(message['content'], style: const TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, BuddyController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear History'),
          content: const Text('Are you sure you want to clear all conversation history? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                controller.clearHistory();
                Navigator.of(context).pop();
                Get.back(); // Go back to main page
                // Toast removed per request
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }
}
