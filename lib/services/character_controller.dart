import 'dart:async';
import 'dart:convert';
import '../models/ai_response.dart';
import '../models/character_state.dart';
import 'gemini_service.dart';
import 'tts_service.dart';
import 'overlay_service.dart';
import 'settings_service.dart';

/// Orchestrates the character's behavior:
/// receives events, generates AI responses, controls animations and speech.
class CharacterController {
  final GeminiService _gemini;
  final TtsService _tts;
  final OverlayService _overlay;
  final SettingsService _settings;

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
  })  : _gemini = gemini,
        _tts = tts,
        _overlay = overlay,
        _settings = settings;

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

      // Generate AI response
      final response = await _gemini.generateNagging(
        currentApp: appLabel,
        routineName: routineName,
        distractionCount: _distractionCount,
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
      await _tts.speak(response.text);

      // Stay visible for a moment after speaking
      await Future.delayed(const Duration(seconds: 2));

      // Exit if user returned to routine (check will be done by monitor)
    } catch (e) {
      print('Character controller error: $e');
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

      await _tts.speak(response.text);
      await Future.delayed(const Duration(seconds: 2));
      await _overlay.hide();
    } catch (e) {
      print('Routine start error: $e');
    } finally {
      _isBusy = false;
    }
  }

  /// Handle routine complete event.
  Future<void> onRoutineComplete(String routineName) async {
    if (_isBusy) return;
    _isBusy = true;
    _distractionCount = 0;

    try {
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

      await _tts.speak(response.text);
      await Future.delayed(const Duration(seconds: 3));
      await _overlay.hide();
    } catch (e) {
      print('Routine complete error: $e');
    } finally {
      _isBusy = false;
    }
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
    await _tts.speak(response.text);
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
