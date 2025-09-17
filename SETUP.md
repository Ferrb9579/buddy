# Buddy - AI Voice Assistant

A Flutter app that provides speech-to-text input, AI response generation via OpenRouter's Gemma 2 27B model, and text-to-speech output.

## Features

- 🎤 Speech-to-text input using `speech_to_text` package
- 🤖 AI responses powered by OpenRouter's Gemma 2 27B model
- 🔊 Text-to-speech output using `flutter_tts` package
- 📱 Clean, intuitive UI with real-time status updates
- ⚡ Built with GetX for state management

## Setup Instructions

### 1. Prerequisites
- Flutter SDK installed
- Android device or emulator for testing
- OpenRouter API key

### 2. Get OpenRouter API Key
1. Visit [OpenRouter.ai](https://openrouter.ai/)
2. Sign up for an account
3. Navigate to API Keys section
4. Create a new API key

### 3. Configure API Key
1. Open `lib/config/app_config.dart`
2. Replace `YOUR_OPENROUTER_API_KEY` with your actual API key:
   ```dart
   static const String openRouterApiKey = 'sk-or-v1-your-actual-key-here';
   ```

### 4. Install Dependencies
```bash
flutter pub get
```

### 5. Run the App
```bash
flutter run
```

## Permissions

The app requires the following permissions (already configured):

## Usage

1. **Start Conversation**: Tap the microphone button to start listening
2. **Speak**: Say your message clearly
3. **Processing**: The app will:
   - Convert your speech to text
   - Send the text to AI for processing
   - Convert the AI response back to speech
4. **Listen**: Buddy will speak the response
5. **Stop**: Use the stop button to interrupt speech playback

## UI Components

- **Status Bar**: Shows current app state (listening, processing, speaking)
- **User Speech Area**: Displays what you said
- **AI Response Area**: Shows Buddy's response
- **Control Buttons**: Microphone and stop controls

## Configuration

Customize the app behavior in `lib/config/app_config.dart`:
- AI model selection
- Response length and creativity
- Speech settings (rate, pitch, volume)
- Timeout durations

## Troubleshooting
- Test on a physical device (emulator microphone may not work)
- Check for background noise

### API Issues
- Verify your OpenRouter API key is correct
- Check internet connection
- Monitor API usage limits

### TTS Issues
- Ensure device volume is up
- Check TTS engine is installed on device
- Try different speech settings in config

## Architecture

```
lib/
├── config/
│   └── app_config.dart       # App configuration
├── controllers/
│   └── Buddy.controller.dart # GetX controller for state management
├── pages/
│   └── Buddy.dart           # Main UI page
├── routes/
│   ├── app_pages.dart       # Route definitions
│   └── app_routes.dart      # Route names
├── services/
│   └── openrouter_service.dart # OpenRouter API integration
└── main.dart                # App entry point
```

## Dependencies

- `get`: State management
- `speech_to_text`: Speech recognition
- `flutter_tts`: Text-to-speech
- `dio`: HTTP client for API calls

## Models Supported

Currently configured to use:
- `google/gemma-2-27b-it` (Gemma 2 27B Instruct)

You can change the model in `app_config.dart` to any OpenRouter supported model.
