import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/web_search_controller.dart';

/// Example page demonstrating Google Custom Search integration
class WebSearchPage extends StatelessWidget {
  WebSearchPage({super.key});

  final WebSearchController controller = Get.put(WebSearchController());
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Search'), elevation: 2),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Enter search query...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (query) {
                      if (query.isNotEmpty) {
                        controller.performSearch(query);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final query = searchController.text.trim();
                    if (query.isNotEmpty) {
                      controller.performSearch(query);
                    }
                  },
                  child: const Text('Search'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.image),
                  tooltip: 'Image Search',
                  onPressed: () {
                    final query = searchController.text.trim();
                    if (query.isNotEmpty) {
                      controller.performImageSearch(query);
                    }
                  },
                ),
              ],
            ),
          ),

          // Error message
          Obx(() {
            if (controller.errorMessage.value.isNotEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(controller.errorMessage.value, style: TextStyle(color: Colors.red.shade700)),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),

          const SizedBox(height: 8),

          // Loading indicator
          Obx(() {
            if (controller.isLoading.value) {
              return const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator());
            }
            return const SizedBox.shrink();
          }),

          // Search results
          Expanded(
            child: Obx(() {
              if (controller.searchResults.isEmpty && !controller.isLoading.value && controller.errorMessage.value.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Enter a search query to get started', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.searchResults.length,
                itemBuilder: (context, index) {
                  final result = controller.searchResults[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        // You can open the URL here using url_launcher package
                        debugPrint('Opening: ${result['url']}');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              result['title'] ?? '',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            const SizedBox(height: 4),

                            // Display URL
                            Text(result['displayUrl'] ?? result['url'] ?? '', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                            const SizedBox(height: 8),

                            // Description
                            Text(
                              result['description'] ?? '',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),

          // Load more button
          Obx(() {
            if (controller.searchResults.isNotEmpty && !controller.isLoading.value) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final nextIndex = controller.searchResults.length + 1;
                    controller.loadMoreResults(startIndex: nextIndex);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Load More'),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}
