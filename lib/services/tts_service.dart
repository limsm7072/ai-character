import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

/// Voice preset definition.
class VoicePreset {
  final String id;
  final String label;
  final String description;
  final double pitch;
  final double rate;

  const VoicePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.pitch,
    required this.rate,
  });
}

/// Available voice presets.
const voicePresets = [
  VoicePreset(
    id: 'cute',
    label: '귀여운',
    description: '높고 느린 목소리',
    pitch: 1.4,
    rate: 0.45,
  ),
  VoicePreset(
    id: 'calm',
    label: '차분한',
    description: '낮고 천천히',
    pitch: 1.0,
    rate: 0.4,
  ),
  VoicePreset(
    id: 'bright',
    label: '밝은',
    description: '밝고 또렷한 목소리',
    pitch: 1.2,
    rate: 0.5,
  ),
  VoicePreset(
    id: 'deep',
    label: '낮은',
    description: '낮고 차분한 목소리',
    pitch: 0.8,
    rate: 0.45,
  ),
  VoicePreset(
    id: 'fast',
    label: '빠른',
    description: '빠르고 경쾌한 목소리',
    pitch: 1.1,
    rate: 0.65,
  ),
];

/// Text-to-Speech service for Korean voice output.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  final _speakCompleter = <Completer<void>>[];

  /// Currently active pitch and rate, re-applied before every speak.
  double _currentPitch = 1.4;
  double _currentRate = 0.45;

  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setLanguage('ko-KR');
    await _tts.setVolume(1.0);

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

  /// Apply a voice preset by ID.
  Future<void> applyPreset(String presetId) async {
    final preset = voicePresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => voicePresets.first,
    );
    _currentPitch = preset.pitch;
    _currentRate = preset.rate;
    await _tts.setPitch(_currentPitch);
    await _tts.setSpeechRate(_currentRate);
  }

  /// Speak the given text and wait for completion.
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();

    // Stop any current speech
    if (_isSpeaking) {
      await _tts.stop();
    }

    // Re-apply pitch/rate every time (Android TTS can reset in background)
    await _tts.setPitch(_currentPitch);
    await _tts.setSpeechRate(_currentRate);

    final completer = Completer<void>();
    _speakCompleter.add(completer);

    await _tts.speak(_cleanForTts(text));
    return completer.future;
  }

  /// Remove special characters that TTS reads literally (e.g. ~ → "물결표").
  String _cleanForTts(String text) {
    return text
        .replaceAll(RegExp(r'[~～♥♡★☆♪♬◆◇●○■□▶▷△▲▽▼←→↑↓]'), '')
        .replaceAll(RegExp(r'[ㅋ]{2,}'), 'ㅋㅋ')
        .replaceAll(RegExp(r'[ㅎ]{2,}'), 'ㅎㅎ')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r'!{2,}'), '!')
        .replaceAll(RegExp(r'\?{2,}'), '?')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
