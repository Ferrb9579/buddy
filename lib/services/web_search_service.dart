import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Web Search Service using Google Custom Search JSON API
/// This service provides web search capabilities for the mobile app
class WebSearchService {
  final String apiKey;
  final String searchEngineId;
  final Dio _dio;
  static const String _baseUrl = 'https://www.googleapis.com/customsearch/v1';

  WebSearchService({String? apiKey, String? searchEngineId}) : apiKey = apiKey ?? dotenv.env['GOOGLE_SEARCH_API_KEY'] ?? '', searchEngineId = searchEngineId ?? dotenv.env['GOOGLE_SEARCH_ENGINE_ID'] ?? '', _dio = Dio(BaseOptions(baseUrl: _baseUrl, connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)));

  /// Perform a web search using Google Custom Search JSON API
  ///
  /// [query] - The search query string
  /// [count] - Number of results to return (default: 10, max: 10)
  /// [startIndex] - Start index for pagination (default: 1)
  ///
  /// Returns a map containing search results with the following structure:
  /// - query: The original search query
  /// - results: List of search results, each containing:
  ///   - title: Page title
  ///   - url: Page URL
  ///   - description: Page description/snippet
  Future<Map<String, dynamic>> search({required String query, int count = 10, int startIndex = 1}) async {
    if (apiKey.isEmpty) {
      throw Exception('Google Search API key not found. Please set GOOGLE_SEARCH_API_KEY in .env file');
    }

    if (searchEngineId.isEmpty) {
      throw Exception('Google Search Engine ID not found. Please set GOOGLE_SEARCH_ENGINE_ID in .env file');
    }

    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          'key': apiKey,
          'cx': searchEngineId,
          'q': query,
          'num': count > 10 ? 10 : count, // Google API max is 10
          'start': startIndex,
        },
      );

      return _formatSearchResults(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Invalid search parameters');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Invalid Google Search API key or quota exceeded');
      } else if (e.response?.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later');
      } else {
        throw Exception('Search failed: ${e.response?.statusCode} - ${e.message}');
      }
    } catch (e) {
      throw Exception('Error performing web search: $e');
    }
  }

  /// Format search results into a simplified structure
  Map<String, dynamic> _formatSearchResults(Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>? ?? [];
    final searchInfo = data['searchInformation'] as Map<String, dynamic>? ?? {};

    return {
      'query': data['queries']?['request']?[0]?['searchTerms'] ?? '',
      'total': items.length,
      'totalResults': searchInfo['totalResults'] ?? '0',
      'searchTime': searchInfo['searchTime'] ?? 0.0,
      'results': items.map((item) {
        return {'title': item['title'] ?? '', 'url': item['link'] ?? '', 'description': item['snippet'] ?? '', 'displayUrl': item['displayLink'] ?? ''};
      }).toList(),
    };
  }

  /// Perform an image search
  Future<Map<String, dynamic>> imageSearch({required String query, int count = 10, int startIndex = 1}) async {
    if (apiKey.isEmpty || searchEngineId.isEmpty) {
      throw Exception('Google Search API credentials not configured');
    }

    try {
      final response = await _dio.get('', queryParameters: {'key': apiKey, 'cx': searchEngineId, 'q': query, 'num': count > 10 ? 10 : count, 'start': startIndex, 'searchType': 'image'});

      return _formatSearchResults(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Image search failed: ${e.response?.statusCode} - ${e.message}');
    } catch (e) {
      throw Exception('Error performing image search: $e');
    }
  }

  /// Get AI-generated summary for a query
  Future<String> getSummarizedAnswer(String query) async {
    try {
      final searchResults = await search(query: query, count: 5);
      final results = searchResults['results'] as List<dynamic>;

      if (results.isEmpty) {
        return 'No results found for: $query';
      }

      // Create a simple summary from top results
      final summary = StringBuffer();
      summary.writeln('Search results for "$query":\n');

      for (var i = 0; i < results.length && i < 3; i++) {
        final result = results[i] as Map<String, dynamic>;
        summary.writeln('${i + 1}. ${result['title']}');
        summary.writeln('   ${result['description']}\n');
      }

      return summary.toString();
    } catch (e) {
      throw Exception('Error getting summarized answer: $e');
    }
  }
}
