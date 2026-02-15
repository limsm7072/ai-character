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

/// Available Korean Edge TTS voice presets.
/// Base voices: SunHi(여), InJoon(남), Hyunsu(남) — 피치/속도 변형으로 다양화.
const voicePresets = [
  // 여자 목소리 (SunHi 기반)
  VoicePreset(
    id: 'sunhi',
    label: '선희',
    description: '여자 - 밝고 친근한',
    voiceName: 'ko-KR-SunHiNeural',
    gender: 'female',
  ),
  VoicePreset(
    id: 'sunhi_gentle',
    label: '선희 (차분)',
    description: '여자 - 차분하고 부드러운',
    voiceName: 'ko-KR-SunHiNeural',
    gender: 'female',
    rate: '-15%',
    pitch: '-10Hz',
  ),
  VoicePreset(
    id: 'sunhi_bright',
    label: '선희 (활발)',
    description: '여자 - 밝고 활발한',
    voiceName: 'ko-KR-SunHiNeural',
    gender: 'female',
    rate: '+10%',
    pitch: '+15Hz',
  ),
  // 남자 목소리 (InJoon 기반)
  VoicePreset(
    id: 'injoon',
    label: '인준',
    description: '남자 - 차분한',
    voiceName: 'ko-KR-InJoonNeural',
    gender: 'male',
  ),
  VoicePreset(
    id: 'injoon_energetic',
    label: '인준 (활발)',
    description: '남자 - 밝고 에너지넘치는',
    voiceName: 'ko-KR-InJoonNeural',
    gender: 'male',
    rate: '+10%',
    pitch: '+10Hz',
  ),
  // 남자 목소리 (Hyunsu 기반)
  VoicePreset(
    id: 'hyunsu',
    label: '현수',
    description: '남자 - 중후한',
    voiceName: 'ko-KR-HyunsuMultilingualNeural',
    gender: 'male',
  ),
  VoicePreset(
    id: 'hyunsu_deep',
    label: '현수 (중저음)',
    description: '남자 - 깊고 낮은 목소리',
    voiceName: 'ko-KR-HyunsuMultilingualNeural',
    gender: 'male',
    rate: '-10%',
    pitch: '-15Hz',
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
