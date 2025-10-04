# Autonomous Web Search with Function Calling

## Overview

The AI model (Buddy) can now **autonomously** use web search when it needs current information, without requiring manual user interaction. This is implemented using OpenRouter's function calling (tool use) capability.

## How It Works

### 1. **Tool Definition**
The model is provided with a `web_search` tool definition that describes:
- What the tool does (search the web)
- When to use it (for current information, news, facts)
- Parameters it accepts (query, count)

### 2. **Autonomous Decision Making**
When you ask the model a question, it decides automatically whether it needs to search the web:

```
User: "What's the latest news about SpaceX?"
Model: 🤔 I need current information → calls web_search tool
      🔍 Searches "latest SpaceX news"
      📝 Reads results
      💬 Responds with synthesized answer
```

### 3. **Iterative Tool Calling**
The model can:
- Call multiple tools in sequence
- Use search results to formulate better queries
- Make up to 5 tool calls per conversation turn (safety limit)

## Example Conversations

### Weather Query
```
You: "What's the weather like in New York today?"

Model (internal):
1. Detects need for current info
2. Calls: web_search(query="New York weather today")
3. Receives search results
4. Synthesizes answer: "Based on current reports, New York is..."
```

### News Query
```
You: "Tell me about the latest AI developments"

Model (internal):
1. Calls: web_search(query="latest AI developments 2025")
2. Reads multiple results
3. Responds: "Recent AI developments include..."
```

### Multi-Step Search
```
You: "Who won the last NBA championship and who was MVP?"

Model (internal):
1. Calls: web_search(query="NBA championship winner 2024")
2. Gets team name
3. Calls: web_search(query="NBA finals 2024 MVP")
4. Combines both results
5. Responds: "The [team] won, and [player] was MVP..."
```

## Technical Implementation

### File Modified
- `lib/services/openrouter_service.dart`

### Key Components

#### 1. Tool Definition
```dart
List<Map<String, dynamic>> get _tools => [
  {
    'type': 'function',
    'function': {
      'name': 'web_search',
      'description': 'Search the web for current information...',
      'parameters': { /* ... */ }
    }
  }
];
```

#### 2. Tool Execution
```dart
Future<String> _executeTool(String toolName, Map<String, dynamic> arguments) async {
  if (toolName == 'web_search') {
    final query = arguments['query'] as String;
    final results = await _webSearchService.search(query: query);
    return formattedResults;
  }
}
```

#### 3. Iterative Loop
```dart
// In generateResponse method:
for (int i = 0; i < maxIterations; i++) {
  final response = await _dio.post('/chat/completions', data: {
    'model': model,
    'messages': messages,
    'tools': _tools,  // ← Tools available to model
  });
  
  if (hasSToolCalls) {
    // Execute tools and continue loop
  } else {
    // Return final answer
  }
}
```

## Configuration

### Prerequisites
1. **Google Search API Key** - Already configured in `.env`
2. **Google Search Engine ID** - You need to add this:

```env
GOOGLE_SEARCH_API_KEY=AIzaSyAUww4hOIcRT5pjA399RRu9RWcvJxW9LVU
GOOGLE_SEARCH_ENGINE_ID=your_engine_id_here  # ← Add this!
```

To get your Search Engine ID:
1. Go to https://programmablesearchengine.google.com/
2. Create a search engine
3. Enable "Search the entire web"
4. Copy the Search Engine ID

### Model Compatibility
Function calling works with models that support it:
- ✅ GPT-4, GPT-4 Turbo, GPT-3.5 Turbo
- ✅ Claude 3 (Opus, Sonnet, Haiku)
- ✅ Gemini Pro
- ❌ Older models may not support function calling

Check your current model in `lib/config/app_config.dart`.

## Monitoring Tool Calls

The service prints debug info when searching:
```
🔍 Web Search Tool: Searching for "latest AI news"
```

Watch your console/logs to see when the model uses search.

## Usage Examples

### No Code Changes Required!
Just talk to Buddy naturally:

```dart
// Your existing code works as-is:
final response = await openRouterService.generateResponse(
  'What are the latest developments in quantum computing?',
  conversationHistory: history,
);

// Model automatically:
// 1. Recognizes need for current info
// 2. Searches the web
// 3. Returns informed answer
```

### Questions That Trigger Search
- "What's the latest news about..."
- "What's the weather in..."
- "Who won the..."
- "What's the current price of..."
- "Tell me about recent..."
- Any question requiring real-time data

### Questions That Don't Trigger Search
- "What is photosynthesis?" (general knowledge)
- "Write me a poem" (creative task)
- "Explain how airplanes work" (established facts)
- Personal questions about the user

## Benefits

### 1. **Always Current**
The model has access to real-time information without being retrained.

### 2. **Autonomous**
No UI buttons or manual search required - the model decides when to search.

### 3. **Transparent**
You can see in the logs when searches happen.

### 4. **Natural**
The model seamlessly integrates search results into conversational responses.

### 5. **Efficient**
Only searches when actually needed, not on every request.

## Limitations

### API Quotas
- Google Custom Search: 100 free queries/day
- Can increase with paid plan

### Latency
- Web search adds 1-3 seconds to response time
- Model needs to make 2 API calls (one to decide, one after search)

### Accuracy
- Model relies on search result quality
- May occasionally misinterpret search results

### Max Iterations
- Limited to 5 tool calls per turn to prevent loops
- Should be sufficient for most queries

## Troubleshooting

### Model Not Using Search
**Problem**: Model answers without searching when it should.

**Solutions**:
- Make your query more explicit: "Search for..."
- Check model supports function calling
- Verify tools are being sent in API request

### Search Errors
**Problem**: "Google Search Engine ID not found"

**Solution**: Add `GOOGLE_SEARCH_ENGINE_ID` to `.env` file

### Too Many Tool Calls
**Problem**: "Max tool call iterations reached"

**Solution**: 
- Model is stuck in loop (rare)
- Check logs to see what it's searching
- May need to rephrase question

## Advanced: Adding More Tools

You can add more tools following the same pattern:

```dart
List<Map<String, dynamic>> get _tools => [
  {
    'type': 'function',
    'function': {
      'name': 'calculator',
      'description': 'Perform mathematical calculations',
      'parameters': { /* ... */ }
    }
  },
  {
    'type': 'function',
    'function': {
      'name': 'get_weather',
      'description': 'Get weather for a location',
      'parameters': { /* ... */ }
    }
  },
  // ... web_search ...
];
```

Then handle them in `_executeTool`:
```dart
Future<String> _executeTool(String toolName, Map<String, dynamic> arguments) async {
  switch (toolName) {
    case 'web_search':
      return await _handleWebSearch(arguments);
    case 'calculator':
      return await _handleCalculator(arguments);
    case 'get_weather':
      return await _handleWeather(arguments);
    default:
      return 'Unknown tool: $toolName';
  }
}
```

## Summary

The AI model can now:
- ✅ Search the web autonomously when needed
- ✅ Make decisions about when to search
- ✅ Use search results to provide informed answers
- ✅ Work transparently with no code changes required
- ✅ Handle multiple searches in one conversation

Just make sure to add your **Google Search Engine ID** to the `.env` file and you're ready to go! 🚀
