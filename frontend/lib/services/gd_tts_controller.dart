import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;
import 'dart:async';

class GDTTSController {
  static final GDTTSController _instance = GDTTSController._internal();
  final FlutterTts _flutterTts = FlutterTts();
  final Completer<void> _initCompleter = Completer<void>();

  // Queue so messages are spoken one at a time
  final List<Map<String, String>> _queue = [];
  bool _isSpeaking = false;
  Function? onQueueEmpty;

  factory GDTTSController() => _instance;

  GDTTSController._internal() {
    _initTTS();
  }

  void _initTTS() async {
    try {
      final engines = await _flutterTts.getEngines;
      print("TTS: Available Engines: $engines");

      final languages = await _flutterTts.getLanguages;
      print("TTS: Available Languages: $languages");

      // Try to set a good English language
      bool langSet = false;
      for (final lang in ["en-IN", "en-GB", "en-US", "en"]) {
        if (languages.contains(lang) ||
            languages.contains(lang.replaceAll('-', '_'))) {
          try {
            await _flutterTts.setLanguage(lang);
            print("TTS: Successfully set language to $lang");
            langSet = true;
            break;
          } catch (_) {}
        }
      }
      if (!langSet && languages.isNotEmpty) {
        await _flutterTts.setLanguage(languages.first);
        print("TTS: Fallback to first available: ${languages.first}");
      }

      try { await _flutterTts.setSpeechRate(0.65); } catch (_) {}
      try { await _flutterTts.setVolume(1.0);     } catch (_) {}

      // On Windows, awaitSpeakCompletion(true) can cause severe threading crashes
      // We will remove it and use a custom delay based on text length instead.
      try { await _flutterTts.awaitSpeakCompletion(false); } catch (_) {}

      // Removed unreliable setCompletionHandler
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      print("TTS: Controller Initialized Successfully");
    } catch (e) {
      print("TTS Error: Initialization failed: $e");
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    }
  }

  /// Adds a message to the queue and starts processing if idle
  Future<void> speak(String text, String speaker) async {
    _queue.add({'text': text, 'speaker': speaker});
    print("TTS: Queued message for '$speaker'. Queue size: ${_queue.length}");
    if (!_isSpeaking) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isSpeaking) return;
    _isSpeaking = true;

    await _initCompleter.future;

    while (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      final text = next['text']!;
      final speaker = next['speaker']!;

      print("TTS: Bot '$speaker' is speaking: $text");

      try {
        if (speaker == "Bot_Mod") {
          await _flutterTts.setPitch(1.0);
        } else if (speaker == "Bot_A") {
          await _flutterTts.setPitch(0.85);
        } else if (speaker == "Bot_B") {
          await _flutterTts.setPitch(0.8);
        }

        await _flutterTts.speak(text);

        // Word-count based delay: at speech rate 0.65, ~130 WPM → ~462ms per word.
        // Add a fixed 900ms tail buffer to ensure the last word finishes before
        // TTS_COMPLETED is sent to the backend.
        final wordCount = text.trim().split(RegExp(r'\s+')).length;
        final delayMs = (wordCount * 462) + 900;
        await Future.delayed(Duration(milliseconds: delayMs));
        
      } catch (e) {
        print("TTS Error during speak: $e");
      }
    }
    
    _isSpeaking = false;
    onQueueEmpty?.call();
  }

  Future<void> stop() async {
    try {
      _queue.clear();
      _isSpeaking = false;
      await _flutterTts.stop();
    } catch (e) {
      print("TTS Error during stop: $e");
    }
  }
}



