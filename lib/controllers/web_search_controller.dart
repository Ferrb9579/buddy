import 'package:get/get.dart';
import '../services/web_search_service.dart';

/// Controller for managing web search functionality
/// Demonstrates how to use the WebSearchService in your app
class WebSearchController extends GetxController {
  final WebSearchService _webSearchService = WebSearchService();

  // Observable state
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
  final RxString currentQuery = ''.obs;

  /// Perform a web search
  Future<void> performSearch(String query) async {
    if (query.trim().isEmpty) {
      errorMessage.value = 'Please enter a search query';
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      currentQuery.value = query;

      final results = await _webSearchService.search(query: query, count: 10);

      searchResults.value = List<Map<String, dynamic>>.from(results['results'] ?? []);

      if (searchResults.isEmpty) {
        errorMessage.value = 'No results found for "$query"';
      }
    } catch (e) {
      errorMessage.value = 'Search error: ${e.toString()}';
      searchResults.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// Get a summarized answer for a query
  Future<String> getSummary(String query) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final summary = await _webSearchService.getSummarizedAnswer(query);
      return summary;
    } catch (e) {
      errorMessage.value = 'Error getting summary: ${e.toString()}';
      return '';
    } finally {
      isLoading.value = false;
    }
  }

  /// Perform an image search
  Future<void> performImageSearch(String query) async {
    if (query.trim().isEmpty) {
      errorMessage.value = 'Please enter a search query';
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      currentQuery.value = query;

      final results = await _webSearchService.imageSearch(query: query, count: 10);

      searchResults.value = List<Map<String, dynamic>>.from(results['results'] ?? []);

      if (searchResults.isEmpty) {
        errorMessage.value = 'No image results found for "$query"';
      }
    } catch (e) {
      errorMessage.value = 'Image search error: ${e.toString()}';
      searchResults.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// Clear search results
  void clearResults() {
    searchResults.clear();
    errorMessage.value = '';
    currentQuery.value = '';
  }

  /// Load more results (pagination)
  /// Note: Google Custom Search API uses startIndex (1-based) instead of offset
  Future<void> loadMoreResults({int startIndex = 1}) async {
    if (currentQuery.value.isEmpty) return;

    try {
      final results = await _webSearchService.search(query: currentQuery.value, count: 10, startIndex: startIndex);

      final newResults = List<Map<String, dynamic>>.from(results['results'] ?? []);

      searchResults.addAll(newResults);
    } catch (e) {
      errorMessage.value = 'Error loading more results: ${e.toString()}';
    }
  }

  @override
  void onClose() {
    clearResults();
    super.onClose();
  }
}
