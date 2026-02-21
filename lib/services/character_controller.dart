import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/ai_response.dart';
import '../models/character_state.dart';
import 'gemini_service.dart';
import 'tts_service.dart';
import 'overlay_service.dart';
import 'settings_service.dart';
import 'routine_completion_service.dart';
import 'growth_service.dart';
import '../service_locator.dart';

/// Orchestrates the character's behavior:
/// receives events, generates AI responses, controls animations and speech.
class CharacterController {
  final GeminiService _gemini;
  final TtsService _tts;
  final OverlayService _overlay;
  final SettingsService _settings;
  final RoutineCompletionService _completionService;

  static const _speechChannel =
      MethodChannel('com.aicharacter.ai_character/speech');

  final _stateController = StreamController<CharacterState>.broadcast();
  Stream<CharacterState> get onStateChanged => _stateController.stream;

  CharacterState _currentState = const CharacterState();
  CharacterState get currentState => _currentState;

  int _distractionCount = 0;
  String _lastDistractedApp = '';
  bool _isBusy = false;

  String get _characterId => _settings.selectedCharacter;

  CharacterController({
    required GeminiService gemini,
    required TtsService tts,
    required OverlayService overlay,
    required SettingsService settings,
    required RoutineCompletionService completionService,
  })  : _gemini = gemini,
        _tts = tts,
        _overlay = overlay,
        _settings = settings,
        _completionService = completionService;

  /// Speak text with the saved voice preset and ttsEnabled check.
  Future<void> _speak(String text) async {
    if (!_settings.ttsEnabled) return;
    await _tts.applyPreset(_settings.voicePreset);
    await _tts.speak(text);
  }

  /// Handle distraction detected event.
  Future<void> onDistraction({
    required String appPackageName,
    required String appLabel,
    required String routineName,
    int? nagIntensity,
    bool showOverlay = true,
  }) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      // Track distraction count
      if (appPackageName == _lastDistractedApp) {
        _distractionCount++;
      } else {
        _distractionCount = 1;
        _lastDistractedApp = appPackageName;
      }

      // Generate AI response with intensity setting
      final response = await _gemini.generateNagging(
        currentApp: appLabel,
        routineName: routineName,
        distractionCount: _distractionCount,
        intensity: nagIntensity ?? _settings.nagIntensity,
      );

      if (showOverlay) {
        // Show character overlay + voice
        _updateState(CharacterState(
          emotion: response.emotion,
          gesture: 'crawling_in',
          text: response.text,
          characterId: _characterId,
        ));
        await _overlay.show(initialData: jsonEncode(_currentState.toJson()));
        await Future.delayed(const Duration(milliseconds: 800));

        _updateState(CharacterState(
          emotion: response.emotion,
          gesture: response.gesture,
          text: response.text,
          characterId: _characterId,
        ));
        await _overlay.sendToOverlay(jsonEncode(_currentState.toJson()));
        await _speak(response.text);
        await Future.delayed(const Duration(seconds: 2));
        await _overlay.hide();
      } else {
        // Voice only — no overlay
        await _speak(response.text);
      }
    } catch (e) {
      print('Character controller error: $e');
      // Ensure overlay is hidden on error
      await _overlay.hide();
    } finally {
      _isBusy = false;
    }
  }

  /// Handle routine start event.
  Future<void> onRoutineStart(String routineName) async {
    if (_isBusy) return;
    _isBusy = true;
    _distractionCount = 0;

    try {
      final response = await _gemini.generateEncouragement(routineName);

      _updateState(CharacterState(
        emotion: response.emotion,
        gesture: 'waving',
        text: response.text,
        characterId: _characterId,
      ));
      await _overlay.show(
        initialData: jsonEncode(_currentState.toJson()),
      );

      await _speak(response.text);
      await Future.delayed(const Duration(seconds: 2));
      await _overlay.hide();
    } catch (e) {
      print('Routine start error: $e');
    } finally {
      _isBusy = false;
    }
  }

  /// Handle routine complete event.
  /// If the routine is not yet checked as completed, prompt the user via voice.
  /// [date] is the yyyy-MM-dd string for the target date.
  /// [daysAgo] indicates how many days in the past (0=today, 1=yesterday, etc.)
  /// Returns true if the prompt was actually shown, false if busy.
  Future<bool> onRoutineComplete(
    String routineId, String routineName, String date, int daysAgo,
  ) async {
    if (_isBusy) return false;
    _isBusy = true;
    _distractionCount = 0;

    try {
      final alreadyCompleted =
          _completionService.isCompleted(routineId, date);

      if (alreadyCompleted) {
        // Already checked — just praise
        final response = await _gemini.generatePraise(routineName);
        _updateState(CharacterState(
          emotion: response.emotion,
          gesture: 'clapping',
          text: response.text,
          characterId: _characterId,
        ));
        await _overlay.show(
          initialData: jsonEncode(_currentState.toJson()),
        );
        await _speak(response.text);
        await Future.delayed(const Duration(seconds: 3));
        await _overlay.hide();
      } else {
        // Build question text based on daysAgo
        final friendlyName = _friendlyRoutineName(routineName);
        String askText;
        if (daysAgo == 0) {
          askText = '$friendlyName 끝났는데, 잘 했어?';
        } else if (daysAgo == 1) {
          askText = '어제 $friendlyName 했어?';
        } else {
          askText = '$daysAgo일 전 $friendlyName 했어?';
        }

        _updateState(CharacterState(
          emotion: 'happy',
          gesture: 'beckoning',
          text: askText,
          characterId: _characterId,
        ));
        await _overlay.show(
          initialData: jsonEncode(_currentState.toJson()),
        );

        // Speak the question
        await _speak(askText);

        // Listen for voice response (races with overlay dismissal)
        final voiceText = await _listenForCompletionVoice();

        if (voiceText != null && _isNegative(voiceText)) {
          await _completionService.markSkipped(routineId, date);

          _updateState(CharacterState(
            emotion: 'sad',
            gesture: 'disappointed',
            text: '알겠어, 다음엔 꼭 하자!',
            characterId: _characterId,
          ));
          await _overlay.sendToOverlay(jsonEncode(_currentState.toJson()));
          await _speak('알겠어, 다음엔 꼭 하자!');
          await Future.delayed(const Duration(seconds: 2));
        } else if (voiceText != null && _isAffirmative(voiceText)) {
          await _completionService.toggleCompletion(routineId, date);

          // XP 보상
          final growth = getIt<GrowthService>();
          await growth.onRoutineCompleted(routineId);
          final xpMsg = growth.didLevelUp
              ? '완료! 레벨 ${growth.currentData.level} 달성!'
              : '완료 체크했어! 수고했어~';

          _updateState(CharacterState(
            emotion: growth.didLevelUp ? 'proud' : 'happy',
            gesture: growth.didLevelUp ? 'clapping' : 'thumbs_up',
            text: xpMsg,
            characterId: _characterId,
          ));
          await _overlay.sendToOverlay(jsonEncode(_currentState.toJson()));
          await _speak(xpMsg);
          await Future.delayed(const Duration(seconds: 2));
        }

        await _overlay.hide();
      }
      return true;
    } catch (e) {
      print('Routine complete error: $e');
      return false;
    } finally {
      _isBusy = false;
    }
  }

  /// Listen for voice response, racing with overlay dismissal.
  /// Returns recognized text or null (dismissed/timeout/error).
  Future<String?> _listenForCompletionVoice() async {
    final completer = Completer<String?>();

    // Start voice recognition
    _startVoiceRecognition().then((text) {
      if (!completer.isCompleted) completer.complete(text);
    });

    // Monitor overlay dismissal (user tap)
    final timer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (completer.isCompleted) return;
      final active = await _overlay.isOverlayActive();
      if (!active && !completer.isCompleted) {
        completer.complete(null);
      }
    });

    // Timeout safety net (20 seconds)
    final timeout = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    final result = await completer.future;
    timer.cancel();
    timeout.cancel();
    return result;
  }

  /// Start native speech recognition via method channel.
  Future<String?> _startVoiceRecognition() async {
    try {
      final result = await _speechChannel
          .invokeMethod<String>('startListening')
          .timeout(const Duration(seconds: 15));
      return result;
    } catch (e) {
      print('Voice recognition error: $e');
      return null;
    }
  }

  /// Check if user's voice response is affirmative.
  bool _isAffirmative(String text) {
    final t = text.trim();
    const affirmatives = [
      '응', '네', '해줘', '해', '좋아', '체크', '완료', '그래',
      '웅', '어', '맞아', '부탁', '당연', '했어', '끝났어', '다했어',
    ];
    return affirmatives.any((a) => t.contains(a));
  }

  /// Check if user's voice response is negative (didn't do it).
  bool _isNegative(String text) {
    final t = text.trim();
    const negatives = [
      '아니', '안했', '못했', '안 했', '못 했', '노', '싫',
      '아직', '안해', '못해', '패스', '건너뛰', '스킵', '미완',
    ];
    return negatives.any((a) => t.contains(a));
  }

  /// User returned to allowed app during routine.
  Future<void> onReturnToRoutine() async {
    _distractionCount = 0;
    _updateState(CharacterState(
      emotion: 'happy',
      gesture: 'thumbs_up',
      text: '',
      characterId: _characterId,
    ));

    // Hide overlay after brief delay
    await Future.delayed(const Duration(seconds: 1));
    await _overlay.hide();
  }

  /// Handle user tapping the character.
  Future<AiResponse> onCharacterTapped(String message) async {
    final response = await _gemini.chat(message);
    _updateState(CharacterState(
      emotion: response.emotion,
      gesture: response.gesture,
      text: response.text,
      characterId: _characterId,
    ));
    await _speak(response.text);
    return response;
  }

  /// 루틴 이름을 자연스러운 표현으로 변환
  String _friendlyRoutineName(String routineName) {
    final name = routineName.toLowerCase();
    if (_containsAny(name, ['취침', '수면', '잠', '자기'])) return '잘 시간';
    if (_containsAny(name, ['운동', '헬스', '근력', '홈트'])) return '운동';
    if (_containsAny(name, ['약', '복용', '복약', '영양제', '비타민'])) return '약 먹기';
    if (_containsAny(name, ['공부', '학습', '독서', '스터디'])) return '공부';
    if (_containsAny(name, ['명상', '휴식', '릴렉스'])) return '쉬는 시간';
    if (_containsAny(name, ['청소', '정리', '빨래', '설거지'])) return '청소';
    if (_containsAny(name, ['스킨케어', '피부', '세안', '양치', '샤워'])) return '씻기';
    if (_containsAny(name, ['식사', '밥', '브런치'])) return '밥 먹기';
    if (_containsAny(name, ['일기', '다이어리', '저널'])) return '일기 쓰기';
    if (_containsAny(name, ['물', '수분'])) return '물 마시기';
    if (_containsAny(name, ['스트레칭', '요가'])) return '스트레칭';
    if (_containsAny(name, ['달리기', '러닝', '조깅', '산책', '걷기'])) return '산책';
    return routineName;
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  void _updateState(CharacterState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    _stateController.close();
  }
}
