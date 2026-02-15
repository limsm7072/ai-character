import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'edge_tts_service.dart';

/// Edge TTS voice definition.
class VoicePreset {
  final String id;
  final String label;
  final String description;
  final String voiceName;
  final String gender;
  final String rate;
  final String pitch;

  const VoicePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.voiceName,
    required this.gender,
    this.rate = '+0%',
    this.pitch = '+0Hz',
  });
}

/// Available Korean Edge TTS voices.
const voicePresets = [
  VoicePreset(
    id: 'sunhi',
    label: '선희',
    description: '여자 - 밝고 친근한',
    voiceName: 'ko-KR-SunHiNeural',
    gender: 'female',
  ),
  VoicePreset(
    id: 'injoon',
    label: '인준',
    description: '남자 - 차분한',
    voiceName: 'ko-KR-InJoonNeural',
    gender: 'male',
  ),
  VoicePreset(
    id: 'hyunsu',
    label: '현수',
    description: '남자 - 중후한',
    voiceName: 'ko-KR-HyunsuNeural',
    gender: 'male',
  ),
  VoicePreset(
    id: 'bongjin',
    label: '봉진',
    description: '남자 - 나이든',
    voiceName: 'ko-KR-BongJinNeural',
    gender: 'male',
  ),
  VoicePreset(
    id: 'gookmin',
    label: '국민',
    description: '남자 - 힘있는',
    voiceName: 'ko-KR-GookMinNeural',
    gender: 'male',
  ),
  VoicePreset(
    id: 'jimin',
    label: '지민',
    description: '여자 - 상냥한',
    voiceName: 'ko-KR-JiMinNeural',
    gender: 'female',
  ),
  VoicePreset(
    id: 'seohyeon',
    label: '서현',
    description: '여자 - 차분한',
    voiceName: 'ko-KR-SeoHyeonNeural',
    gender: 'female',
  ),
  VoicePreset(
    id: 'soonbok',
    label: '순복',
    description: '여자 - 따뜻한',
    voiceName: 'ko-KR-SoonBokNeural',
    gender: 'female',
  ),
  VoicePreset(
    id: 'yujin',
    label: '유진',
    description: '여자 - 활발한',
    voiceName: 'ko-KR-YuJinNeural',
    gender: 'female',
  ),
];

/// TTS service using Edge TTS (primary) with flutter_tts fallback.
class TtsService {
  static const _audioChannel =
      MethodChannel('com.aicharacter.ai_character/audio');

  final EdgeTtsService _edgeTts = EdgeTtsService();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isSpeaking = false;
  bool _flutterTtsInitialized = false;

  String _currentVoice = 'ko-KR-SunHiNeural';
  String _currentRate = '+0%';
  String _currentPitch = '+0Hz';

  /// Whether last speak used Edge TTS (true) or fallback (false).
  bool lastUsedEdgeTts = false;

  /// Last error from Edge TTS (for debugging).
  String? lastEdgeError;

  bool get isSpeaking => _isSpeaking;

  /// Initialize (kept for backward compatibility).
  Future<void> initialize() async {}

  /// Apply a voice preset by ID.
  Future<void> applyPreset(String presetId) async {
    final preset = voicePresets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => voicePresets.first,
    );
    _currentVoice = preset.voiceName;
    _currentRate = preset.rate;
    _currentPitch = preset.pitch;
  }

  /// Speak text using Edge TTS, falling back to flutter_tts on failure.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    await stop();

    final cleaned = _cleanForTts(text);
    _isSpeaking = true;

    try {
      debugPrint('[TTS] Edge TTS: voice=$_currentVoice');
      final mp3Bytes = await _edgeTts.synthesize(
        cleaned,
        voice: _currentVoice,
        rate: _currentRate,
        pitch: _currentPitch,
      );

      if (mp3Bytes.isEmpty) throw Exception('Empty audio');

      debugPrint('[TTS] Edge TTS OK: ${mp3Bytes.length} bytes');

      // Write to app cache dir
      final cacheDir = Directory.systemTemp;
      final tempFile = File('${cacheDir.path}/edge_tts_output.mp3');
      await tempFile.writeAsBytes(mp3Bytes);

      await _audioChannel.invokeMethod('playFile', {
        'path': tempFile.path,
      });

      lastUsedEdgeTts = true;
      lastEdgeError = null;

      // Estimate playback duration from file size
      // MP3 at 48kbps: ~6000 bytes/sec
      final estimatedMs = (mp3Bytes.length / 6.0).round();
      await Future.delayed(Duration(milliseconds: estimatedMs));
      _isSpeaking = false;
    } catch (e) {
      debugPrint('[TTS] Edge TTS FAILED: $e');
      debugPrint('[TTS] Edge detail: ${_edgeTts.lastError}');
      lastUsedEdgeTts = false;
      lastEdgeError = '$e';
      // Fallback to flutter_tts
      await _speakWithFlutterTts(cleaned);
    }
  }

  Future<void> _speakWithFlutterTts(String text) async {
    if (!_flutterTtsInitialized) {
      await _flutterTts.setLanguage('ko-KR');
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.2);
      await _flutterTts.setSpeechRate(0.5);
      _flutterTtsInitialized = true;
    }

    final completer = Completer<void>();

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      if (!completer.isCompleted) completer.complete();
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      if (!completer.isCompleted) completer.complete();
    });

    await _flutterTts.speak(text);
    await completer.future;
  }

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
    _isSpeaking = false;
    try {
      await _audioChannel.invokeMethod('stop');
    } catch (_) {}
    await _flutterTts.stop();
  }

  Future<void> dispose() async {
    await stop();
  }
}
