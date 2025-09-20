import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:buddy/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class TtsService {
  final Dio _dio;
  final AudioPlayer _player;

  bool _isSpeaking = false;

  TtsService({Dio? dio, AudioPlayer? player}) : _dio = dio ?? Dio(BaseOptions(baseUrl: 'https://api.elevenlabs.io/v1')), _player = player ?? AudioPlayer();

  bool get isSpeaking => _isSpeaking;

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    // Build request
    final voiceId = AppConfig.elevenLabsVoiceId;
    final modelId = AppConfig.elevenLabsModelId;
    final outputFormat = AppConfig.elevenLabsOutputFormat; // mp3_44100_128

    final url = '/text-to-speech/$voiceId';
    final apiKey = AppConfig.elevenLabsApiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception('ElevenLabs API key is missing. Provide ELEVENLABS_API_KEY via --dart-define or .env');
    }
    final headers = {'xi-api-key': apiKey, 'Content-Type': 'application/json'};

    // ElevenLabs returns audio bytes. Request as bytes.
    final response = await _dio.post<List<int>>(
      '$url?output_format=$outputFormat',
      data: jsonEncode({
        'text': text,
        'model_id': modelId,
        'voice_settings': {'stability': 0.4, 'similarity_boost': 0.8},
      }),
      options: Options(responseType: ResponseType.bytes, headers: headers),
    );

    // Save to temp file
    final dir = await _tempDir();
    final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
    await file.writeAsBytes(response.data ?? []);

    // Play via audioplayers
    _isSpeaking = true;
    await _player.play(DeviceFileSource(file.path));
    await _player.onPlayerComplete.first;
    _isSpeaking = false;
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      await _player.stop();
      _isSpeaking = false;
    }
  }

  Future<Directory> _tempDir() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      // Fallback to system temp
      return Directory.systemTemp;
    }
  }
}
