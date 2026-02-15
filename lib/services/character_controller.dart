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
        intensity: _settings.nagIntensity,
      );

      // Prepare initial state
      _updateState(CharacterState(
        emotion: response.emotion,
        gesture: 'crawling_in',
        text: response.text,
        characterId: _characterId,
      ));

      // Show overlay with initial data
      await _overlay.show(
        initialData: jsonEncode(_currentState.toJson()),
      );

      // Wait for entrance animation
      await Future.delayed(const Duration(milliseconds: 800));

      // Switch to response gesture
      _updateState(CharacterState(
        emotion: response.emotion,
        gesture: response.gesture,
        text: response.text,
        characterId: _characterId,
      ));

      // Send updated state to overlay
      await _overlay.sendToOverlay(jsonEncode(_currentState.toJson()));

      // Speak the text
      await _speak(response.text);

      // Stay visible for a moment after speaking
      await Future.delayed(const Duration(seconds: 2));

      // Hide overlay after distraction nag completes
      await _overlay.hide();
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
  /// Returns true if the prompt was actually shown, false if busy.
  Future<bool> onRoutineComplete(String routineId, String routineName) async {
    if (_isBusy) return false;
    _isBusy = true;
    _distractionCount = 0;

    try {
      final today = _completionService.todayStr();
      final alreadyCompleted =
          _completionService.isCompleted(routineId, today);

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
        // Not checked — ask via voice
        final askText = '$routineName 시간 끝났는데, 완료 체크 해줄까?';

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
        final accepted = voiceText != null && _isAffirmative(voiceText);

        if (accepted) {
          await _completionService.toggleCompletion(routineId, today);

          _updateState(CharacterState(
            emotion: 'happy',
            gesture: 'thumbs_up',
            text: '완료 체크했어! 수고했어~',
            characterId: _characterId,
          ));
          await _overlay.sendToOverlay(jsonEncode(_currentState.toJson()));
          await _speak('완료 체크했어! 수고했어~');
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

  void _updateState(CharacterState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    _stateController.close();
  }
}
