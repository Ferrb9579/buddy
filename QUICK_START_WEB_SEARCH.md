# Quick Start: Autonomous Web Search

## ✅ Setup Complete!

Your AI model can now automatically search the web when needed. **No UI changes required** - it works with your existing Buddy interface!

## 🚀 How to Use

### Just talk to Buddy normally!

The model will **automatically decide** when to search the web. Examples:

1. **Ask about current events:**
   ```
   "What's the latest news about AI?"
   "Tell me about today's headlines"
   ```

2. **Ask about weather:**
   ```
   "What's the weather in Tokyo?"
   "Will it rain today?"
   ```

3. **Ask about recent events:**
   ```
   "Who won the last Super Bowl?"
   "What happened with SpaceX recently?"
   ```

4. **Ask about prices/stocks:**
   ```
   "What's the current price of Bitcoin?"
   "How is Tesla stock doing?"
   ```

## 🔍 How to Know It's Working

Watch your console/terminal for this message:
```
🔍 Web Search Tool: Searching for "..."
```

This means the model decided to search the web autonomously!

## ⚙️ Final Setup Step

**Important:** You need to add your Google Search Engine ID to `.env`:

1. Go to https://programmablesearchengine.google.com/
2. Click "Add" to create a new search engine
3. Configure:
   - Sites: Turn on "Search the entire web"
   - Name: "Buddy Search" (or any name)
4. Copy the **Search Engine ID** (looks like: `017576662512468239146:omuauf_lfve`)
5. Add to your `.env` file:
   ```env
   GOOGLE_SEARCH_API_KEY=AIzaSyAUww4hOIcRT5pjA399RRu9RWcvJxW9LVU
   GOOGLE_SEARCH_ENGINE_ID=your_engine_id_here  # ← ADD THIS!
   ```

## 📱 Using in Your App

### Voice Interaction (Existing)
Just speak to Buddy as usual. If you ask about current events, the model will:
1. Detect it needs web search
2. Search automatically
3. Synthesize the results
4. Speak the answer back to you

### Text Input (Existing)
Use the existing `processTypedInput` method:
```dart
await buddyController.processTypedInput('What are the latest AI developments?');
```

The model handles everything automatically!

## 🎯 What Changed

### Modified File
- `lib/services/openrouter_service.dart`
  - Added `WebSearchService` integration
  - Added tool definitions for function calling
  - Updated `generateResponse()` to support iterative tool calls
  - Added `_executeTool()` method to execute web searches

### How It Works Internally
```
User: "What's the latest news?"
  ↓
generateResponse() sends request with tools available
  ↓
Model: "I need current info, let me search"
  ↓
Model calls: web_search(query="latest news")
  ↓
_executeTool() executes the search
  ↓
Search results sent back to model
  ↓
Model synthesizes answer from results
  ↓
Final response returned to user
```

## 🧪 Test It

### Quick Test
1. Open your app
2. Say or type: **"What's the weather in Paris?"**
3. Watch console for: `🔍 Web Search Tool: Searching for "Paris weather"`
4. Get the answer!

### More Test Queries
- "What are people saying about the new iPhone?"
- "Tell me about recent developments in quantum computing"
- "What's trending on social media today?"
- "Who won the latest Formula 1 race?"

## ⚠️ Important Notes

### API Limits
- Free tier: **100 searches per day**
- If you exceed the limit, searches will fail
- Model will still respond but without web data

### Response Time
- Web searches add 2-4 seconds to response time
- This is normal and expected
- Model makes 2 API calls: one to decide, one after search

### When Model Won't Search
The model won't search for:
- General knowledge questions ("What is gravity?")
- Creative tasks ("Write me a poem")
- Personal questions ("What's my name?")
- Historical facts that are well-established

### When Model Will Search
The model will search for:
- Current events and news
- Real-time data (weather, stocks, sports scores)
- Recent developments
- Anything requiring up-to-date information

## 🐛 Troubleshooting

### "Google Search Engine ID not found"
**Fix:** Add `GOOGLE_SEARCH_ENGINE_ID` to your `.env` file (see setup step above)

### Model Not Searching
**Possible reasons:**
1. Model doesn't think search is needed
2. Try being more explicit: "Search for..." or "What's the latest..."
3. Check your model supports function calling (most modern models do)

### Search Errors in Console
**Check:**
1. API key is correct in `.env`
2. Search Engine ID is correct
3. You haven't exceeded daily quota (100/day on free tier)
4. Search engine is set to "Search the entire web"

## 📚 More Information

For detailed technical documentation, see:
- `AUTONOMOUS_WEB_SEARCH.md` - Full technical guide
- `WEB_SEARCH_SETUP.md` - Google Search API setup

## ✨ That's It!

Your AI can now:
- ✅ Search the web autonomously
- ✅ Decide when to search
- ✅ Provide informed, up-to-date answers
- ✅ Work seamlessly with existing voice/text interface

Just add your Search Engine ID and start asking questions! 🚀
