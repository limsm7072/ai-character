import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/ai_response.dart';

/// Handles communication with Google Gemini API for generating
/// character dialogue with emotion and gesture tags.
class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chat;
  ChatSession? _assistantChat;

  bool get isInitialized => _model != null;

  String? _customSystemPrompt;
  String? _customModelResponse;

  void initialize(String apiKey, {String? systemPrompt, String? initialModelResponse}) {
    _customSystemPrompt = systemPrompt;
    _customModelResponse = initialModelResponse;
    _model = GenerativeModel(
      model: 'gemma-3-4b-it',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.9,
        maxOutputTokens: 256,
      ),
    );
    _startChatWithPrompt();
    _startAssistantChat();
  }

  String _appContext = '';

  void setAppContext(String context) {
    _appContext = context;
    if (_model != null) {
      _startChatWithPrompt();
    }
  }

  void _startChatWithPrompt() {
    final prompt = _customSystemPrompt ?? _systemPrompt;
    final contextBlock = _appContext.isNotEmpty
        ? '\n\n현재 앱 상태:\n$_appContext'
        : '';
    final modelResponse = _customModelResponse ??
        '{"text": "안녕! 나는 루나야~ 오늘도 화이팅하자!", "emotion": "happy", "gesture": "waving"}';
    _chat = _model!.startChat(history: [
      Content.text('$prompt$contextBlock'),
      Content.model([TextPart(modelResponse)]),
    ]);
  }

  static const _systemPrompt = '''
너는 "루나"라는 이름의 AI 캐릭터야. 사용자의 친한 친구이자 만능 대화 상대야.

성격:
- 다정하고 밝고 유쾌한 성격
- 한국어로 반말 사용 (친한 친구처럼)
- 짧고 자연스러운 대화 (1-3문장)
- 어떤 주제든 대화 가능 (일상, 고민, 재미, 지식, 추천 등)
- 루틴 관련 질문에는 응원하고 격려해줌
- 가끔 귀여운 표현 섞어서 말함

응답 형식 (반드시 JSON):
{"text": "대사 내용", "emotion": "감정", "gesture": "동작"}

사용 가능한 감정: neutral, happy, angry, sad, surprised, annoyed, disappointed, scolding, proud, worried
사용 가능한 동작: idle, arms_crossed, pointing, shaking_head, waving, crawling_in, thumbs_up, clapping, facepalm, beckoning

예시:
- 인사: {"text": "안녕! 오늘 하루 어땠어?", "emotion": "happy", "gesture": "waving"}
- 고민 상담: {"text": "그랬구나... 힘들었겠다. 내가 들어줄게!", "emotion": "worried", "gesture": "idle"}
- 재미있는 대화: {"text": "ㅋㅋㅋ 진짜? 완전 웃기다!", "emotion": "happy", "gesture": "clapping"}
- 칭찬: {"text": "와 대박! 진짜 잘했어!", "emotion": "proud", "gesture": "thumbs_up"}
''';

  /// Generate a nagging response when the user is distracted.
  /// [intensity] 0=gentle, 1=normal, 2=strict
  Future<AiResponse> generateNagging({
    required String currentApp,
    required String routineName,
    int distractionCount = 1,
    int intensity = 1,
  }) async {
    if (_chat == null) throw Exception('Gemini not initialized');

    String intensityGuide;
    switch (intensity) {
      case 0:
        intensityGuide = '부드럽고 다정하게 격려하듯이 말해줘. 화내지 말고, 걱정하는 친구처럼 따뜻하게. emotion은 worried나 happy 위주로.';
        break;
      case 2:
        intensityGuide = '엄격하고 단호하게 혼내줘. 진지하게 화내면서 잔소리해. emotion은 angry나 scolding 위주로.';
        break;
      default:
        intensityGuide = '적당히 잔소리해줘. 살짝 짜증내면서도 귀엽게.';
        break;
    }

    String prompt;
    if (distractionCount > 1) {
      prompt = '사용자가 "$routineName" 루틴 시간에 또 "$currentApp" 앱을 사용하고 있어. 벌써 ${distractionCount}번째야. $intensityGuide';
    } else {
      prompt = '사용자가 "$routineName" 루틴 시간에 "$currentApp" 앱을 사용하고 있어. $intensityGuide';
    }

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

  // ── Assistant mode ──

  static const _assistantPrompt = '''
너는 "루나"라는 이름의 AI 비서야. 사용자가 "헤이 루나"로 호출했어.

역할:
- 사용자의 질문에 정확하고 유용한 답변을 해줘
- 한국어로 반말 사용 (친한 친구처럼)
- 답변은 간결하게 (음성으로 읽어줄 거야, 1-3문장)
- 모르는 건 모른다고 솔직하게
- 일상 질문, 정보 검색, 계산, 번역, 추천 등 뭐든 도와줘

응답 형식 (반드시 JSON):
{"text": "답변 내용", "emotion": "감정"}

사용 가능한 감정: neutral, happy, angry, sad, surprised, annoyed, disappointed, scolding, proud, worried
''';

  void _startAssistantChat() {
    _assistantChat = _model!.startChat(history: [
      Content.text(_assistantPrompt),
      Content.model([TextPart('{"text": "무엇을 도와드릴까요?", "emotion": "happy"}')]),
    ]);
  }

  /// Generate a response for assistant mode conversation.
  Future<AiResponse> assistantChat(String message) async {
    if (_assistantChat == null) throw Exception('Assistant not initialized');
    final response = await _assistantChat!.sendMessage(Content.text(message));
    return AiResponse.parse(response.text ?? '');
  }

  /// Reset the assistant conversation context.
  void resetAssistantChat() {
    if (_model != null) {
      _startAssistantChat();
    }
  }
}
