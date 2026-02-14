import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech service for Korean voice output.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  final _speakCompleter = <Completer<void>>[];

  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.2); // Slightly higher pitch for cute character

    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      for (final c in _speakCompleter) {
        if (!c.isCompleted) c.complete();
      }
      _speakCompleter.clear();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      for (final c in _speakCompleter) {
        if (!c.isCompleted) c.complete();
      }
      _speakCompleter.clear();
    });

    _isInitialized = true;
  }

  /// Speak the given text and wait for completion.
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();

    // Stop any current speech
    if (_isSpeaking) {
      await _tts.stop();
    }

    final completer = Completer<void>();
    _speakCompleter.add(completer);

    await _tts.speak(text);
    return completer.future;
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
