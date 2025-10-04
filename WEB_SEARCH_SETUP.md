# Google Custom Search Integration

This document explains how to set up and use the Google Custom Search functionality in your Flutter app.

## Setup

### 1. Get Google Custom Search API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Custom Search API**:
   - Go to "APIs & Services" > "Library"
   - Search for "Custom Search API"
   - Click "Enable"
4. Create credentials:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Copy your API key

### 2. Create a Custom Search Engine

1. Go to [Programmable Search Engine](https://programmablesearchengine.google.com/)
2. Click "Add" to create a new search engine
3. Configure your search engine:
   - **Sites to search**: Enter `www.google.com` or specific sites
   - **Name**: Give it a descriptive name
4. After creation, click "Control Panel"
5. Go to "Setup" and note your **Search Engine ID** (cx parameter)
6. (Optional) To search the entire web:
   - Turn on "Search the entire web"
   - Under "Settings" > "Basics"

### 3. Configure Your App

Add your credentials to the `.env` file:

```env
GOOGLE_SEARCH_API_KEY=your_api_key_here
GOOGLE_SEARCH_ENGINE_ID=your_search_engine_id_here
```

**Note**: The API key provided in your project is already configured.

## Usage

### Basic Web Search

```dart
import 'package:get/get.dart';
import 'package:buddy/controllers/web_search_controller.dart';

// Initialize controller
final controller = Get.put(WebSearchController());

// Perform a search
await controller.performSearch('Flutter development');

// Access results
controller.searchResults.forEach((result) {
  print('Title: ${result['title']}');
  print('URL: ${result['url']}');
  print('Description: ${result['description']}');
});
```

### Image Search

```dart
await controller.performImageSearch('cats');
```

### Load More Results (Pagination)

```dart
// Load next page (starts at index 11)
await controller.loadMoreResults(startIndex: 11);

// Load third page (starts at index 21)
await controller.loadMoreResults(startIndex: 21);
```

### Get Summarized Answer

```dart
final summary = await controller.getSummary('What is Flutter?');
print(summary);
```

### Using the Example Page

Navigate to the web search page:

```dart
import 'package:buddy/pages/web_search_page.dart';

// Using GetX navigation
Get.to(() => WebSearchPage());

// Or using regular navigation
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => WebSearchPage()),
);
```

## API Limits

- **Free Tier**: 100 search queries per day
- **Paid Tier**: Up to 10,000 queries per day (requires billing setup)
- **Results per query**: Maximum 10 results per request
- **Daily quota**: Resets at midnight Pacific Time

## Search Result Structure

Each search result contains:

```dart
{
  'title': 'Page title',
  'url': 'https://example.com/page',
  'description': 'Page description/snippet',
  'displayUrl': 'example.com'
}
```

The full response also includes:

```dart
{
  'query': 'search query',
  'total': 10, // Number of results in this response
  'totalResults': '1234567', // Estimated total results available
  'searchTime': 0.45, // Time taken for search in seconds
  'results': [/* array of results */]
}
```

## Error Handling

The controller automatically handles common errors:

- **400**: Invalid search parameters
- **403**: Invalid API key or quota exceeded
- **429**: Rate limit exceeded

Check `controller.errorMessage.value` for error details.

## Troubleshooting

### "Invalid API key or quota exceeded"

- Verify your API key in `.env` file
- Check that Custom Search API is enabled in Google Cloud Console
- Verify you haven't exceeded daily quota

### "Search Engine ID not found"

- Make sure `GOOGLE_SEARCH_ENGINE_ID` is set in `.env` file
- Verify the search engine ID from Programmable Search Engine console

### No results found

- Try different search queries
- Make sure your Custom Search Engine is configured to "Search the entire web"
- Check that the search engine is active

## Direct API Usage (Without Controller)

```dart
import 'package:buddy/services/web_search_service.dart';

final searchService = WebSearchService();

// Perform search
final results = await searchService.search(
  query: 'Flutter',
  count: 10,
  startIndex: 1,
);

print(results['results']);
```

## Additional Resources

- [Google Custom Search JSON API Documentation](https://developers.google.com/custom-search/v1/overview)
- [Programmable Search Engine Help](https://support.google.com/programmable-search)
- [API Pricing](https://developers.google.com/custom-search/v1/overview#pricing)
