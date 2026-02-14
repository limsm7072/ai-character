import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/ai_response.dart';

/// Handles communication with Google Gemini API for generating
/// character dialogue with emotion and gesture tags.
class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chat;

  bool get isInitialized => _model != null;

  void initialize(String apiKey) {
    _model = GenerativeModel(
      model: 'gemma-3-4b-it',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.9,
        maxOutputTokens: 256,
      ),
    );
    _startChatWithPrompt();
  }

  void _startChatWithPrompt() {
    _chat = _model!.startChat(history: [
      Content.text(_systemPrompt),
      Content.model([TextPart('{"text": "안녕! 나는 루나야~ 오늘도 화이팅하자!", "emotion": "happy", "gesture": "waving"}')]),
    ]);
  }

  static const _systemPrompt = '''
너는 "루나"라는 이름의 AI 캐릭터야. 사용자의 루틴 관리를 도와주는 귀엽지만 엄격한 잔소리꾼이야.

성격:
- 기본적으로 다정하고 격려해주지만, 딴짓하면 단호하게 잔소리함
- 한국어로 반말 사용 (친한 친구처럼)
- 짧고 임팩트 있는 대사 (1-2문장)
- 가끔 귀여운 표현 섞어서 말함

상황별 반응:
- 딴짓 감지: 화내거나 실망하며 잔소리
- 루틴 시작: 격려와 응원
- 루틴 완료: 칭찬과 기쁨
- 루틴 중 복귀: 안도하며 다시 격려
- 인사: 밝고 친근하게

응답 형식 (반드시 JSON):
{"text": "대사 내용", "emotion": "감정", "gesture": "동작"}

사용 가능한 감정: neutral, happy, angry, sad, surprised, annoyed, disappointed, scolding, proud, worried
사용 가능한 동작: idle, arms_crossed, pointing, shaking_head, waving, crawling_in, thumbs_up, clapping, facepalm, beckoning

예시:
- 딴짓 감지: {"text": "야! 지금 뭐하는 거야! 루틴 시간이잖아!", "emotion": "angry", "gesture": "pointing"}
- 루틴 완료: {"text": "오~ 대단해! 오늘도 해냈구나!", "emotion": "happy", "gesture": "clapping"}
- 반복 딴짓: {"text": "또?! 진짜 나 화난다...", "emotion": "scolding", "gesture": "arms_crossed"}
''';

  /// Generate a nagging response when the user is distracted.
  Future<AiResponse> generateNagging({
    required String currentApp,
    required String routineName,
    int distractionCount = 1,
  }) async {
    if (_chat == null) throw Exception('Gemini not initialized');

    final prompt = distractionCount > 1
        ? '사용자가 "$routineName" 루틴 시간에 또 "$currentApp" 앱을 사용하고 있어. 벌써 ${distractionCount}번째야. 더 강하게 잔소리해줘.'
        : '사용자가 "$routineName" 루틴 시간에 "$currentApp" 앱을 사용하고 있어. 잔소리해줘.';

    final response = await _chat!.sendMessage(Content.text(prompt));
    return AiResponse.parse(response.text ?? '');
  }

  /// Generate an encouragement when routine starts.
  Future<AiResponse> generateEncouragement(String routineName) async {
    if (_chat == null) throw Exception('Gemini not initialized');

    final prompt = '"$routineName" 루틴이 시작됐어. 사용자를 격려해줘.';
    final response = await _chat!.sendMessage(Content.text(prompt));
    return AiResponse.parse(response.text ?? '');
  }

  /// Generate praise when routine is completed.
  Future<AiResponse> generatePraise(String routineName) async {
    if (_chat == null) throw Exception('Gemini not initialized');

    final prompt = '사용자가 "$routineName" 루틴을 성공적으로 완료했어! 칭찬해줘.';
    final response = await _chat!.sendMessage(Content.text(prompt));
    return AiResponse.parse(response.text ?? '');
  }

  /// Generate a response for general conversation.
  Future<AiResponse> chat(String message) async {
    if (_chat == null) throw Exception('Gemini not initialized');

    final response = await _chat!.sendMessage(Content.text(message));
    return AiResponse.parse(response.text ?? '');
  }

  /// Reset the conversation context.
  void resetChat() {
    if (_model != null) {
      _startChatWithPrompt();
    }
  }
}
