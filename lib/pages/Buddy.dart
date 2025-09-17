import 'package:buddy/controllers/Buddy.controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:buddy/routes/app_routes.dart';
import 'package:buddy/widgets/vector_face.dart';

class Buddy extends StatefulWidget {
  const Buddy({super.key});

  @override
  State<Buddy> createState() => _BuddyState();
}

class _BuddyState extends State<Buddy> {
  final BuddyController controller = Get.put(BuddyController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buddy - AI Voice Assistant'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Typed input
          IconButton(tooltip: 'Type a message', icon: const Icon(Icons.keyboard_alt_outlined), onPressed: _showTypedInputDialog),
          // Mute toggle
          Obx(() => IconButton(tooltip: controller.isMuted ? 'Unmute' : 'Mute', icon: Icon(controller.isMuted ? Icons.volume_off : Icons.volume_up), onPressed: () => controller.toggleMute())),
          // Memory page
          IconButton(tooltip: 'Memory', icon: const Icon(Icons.memory_outlined), onPressed: () => Get.toNamed(AppRoutes.MEMORY)),
          // Reminders page
          IconButton(tooltip: 'Reminders', icon: const Icon(Icons.notifications_active_outlined), onPressed: () => Get.toNamed(AppRoutes.REMINDERS)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Vector face animation
            Obx(() {
              final mood = controller.isSpeaking
                  ? VectorMood.speaking
                  : controller.isProcessing
                  ? VectorMood.thinking
                  : controller.isListening
                  ? VectorMood.listening
                  : controller.waitingForMore
                  ? VectorMood.listening
                  : VectorMood.idle;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VectorFace(mood: mood, height: 140),
              );
            }),

            // Removed status banner; using toast/snackbar notifications instead
            const SizedBox(height: 8),

            // User speech display
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text('You said:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Obx(
                          () => Text(
                            controller.lastWords.isEmpty ? 'Tap the microphone to start speaking...' : controller.lastWords,
                            style: TextStyle(fontSize: 16, color: controller.lastWords.isEmpty ? Colors.grey[600] : Colors.black87, fontStyle: controller.lastWords.isEmpty ? FontStyle.italic : FontStyle.normal),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // AI response display
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.smart_toy, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text('Buddy responds:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Obx(
                          () => Text(
                            controller.aiResponse.isEmpty ? 'AI response will appear here...' : controller.aiResponse,
                            style: TextStyle(fontSize: 16, color: controller.aiResponse.isEmpty ? Colors.grey[600] : Colors.black87, fontStyle: controller.aiResponse.isEmpty ? FontStyle.italic : FontStyle.normal),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Control buttons
            Obx(() => _buildControlButtons()),
          ],
        ),
      ),
    );
  }

  void _showTypedInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Type a message'),
          content: TextField(
            controller: textController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Enter your message...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final text = textController.text;
                Navigator.of(context).pop();
                await controller.processTypedInput(text);
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButtons() {
    // Show different button layout when speech is paused
    if (controller.waitingForMore && controller.isListening) {
      return Column(
        children: [
          // Process Now button when paused
          ElevatedButton.icon(
            onPressed: () => controller.processCurrentSpeech(),
            icon: const Icon(Icons.send),
            label: const Text('Process Now'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
          ),
          const SizedBox(height: 12),
          const Text('Continue speaking or tap "Process Now"', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          // Regular control buttons
          _buildRegularButtons(),
        ],
      );
    } else {
      return _buildRegularButtons();
    }
  }

  Widget _buildRegularButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Clear history button
        ElevatedButton.icon(
          onPressed: () => controller.clearHistory(),
          icon: const Icon(Icons.history),
          label: const Text('Clear'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[100], foregroundColor: Colors.grey[700]),
        ),

        // Stop speaking button
        ElevatedButton.icon(
          onPressed: controller.isSpeaking ? controller.stopSpeaking : null,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100], foregroundColor: Colors.red[700]),
        ),

        // Main microphone button
        SizedBox(
          width: 80,
          height: 80,
          child: FloatingActionButton(
            onPressed: controller.speechEnabled ? controller.toggleListening : null,
            backgroundColor: _getButtonColor(),
            child: Icon(_getButtonIcon(), size: 32, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Color _getButtonColor() {
    if (controller.isSpeaking) return Colors.blue;
    if (controller.isProcessing) return Colors.orange;
    if (controller.isListening) return Colors.red;
    if (!controller.speechEnabled) return Colors.grey;
    return Colors.green;
  }

  IconData _getButtonIcon() {
    if (controller.isSpeaking) return Icons.volume_up;
    if (controller.isProcessing) return Icons.hourglass_empty;
    if (controller.isListening) return Icons.stop;
    return Icons.mic;
  }
}
