import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/ai_response.dart';
import 'agent_tools.dart';

class AgentChatResult {
  final AiResponse response;
  final List<ToolAction> actions;

  AgentChatResult({required this.response, required this.actions});
}

/// Handles communication with Google Gemini API for generating
/// character dialogue with emotion and gesture tags.
/// Automatically falls back to free models when quota is exceeded.
class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chat;

  // Agent (function calling)
  GenerativeModel? _agentModel;
  ChatSession? _agentChat;
  AgentTools? _agentTools;

  bool get isInitialized => _model != null;
  bool get isAgentInitialized => _agentModel != null;

  String? _customSystemPrompt;
  String? _customModelResponse;
  String _characterName = '루나';
  String? _apiKey;

  // Model fallback chains (free tier quota: lite 15RPM/1000RPD, flash 10RPM/250RPD, pro 5RPM/100RPD)
  static const _chatModels = [
    'gemini-2.5-flash-lite',  // 가장 넉넉한 무료 한도
    'gemini-2.5-flash',
    'gemini-2.5-pro',
  ];
  static const _agentModels = [
    'gemini-2.5-flash',       // function calling 최적
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
  ];

  int _chatModelIndex = 0;
  int _agentModelIndex = 0;

  String get currentChatModel => _chatModels[_chatModelIndex];
  String get currentAgentModel => _agentModels[_agentModelIndex];

  void initialize(String apiKey, {String? systemPrompt, String? initialModelResponse, String characterName = '루나'}) {
    _apiKey = apiKey;
    _customSystemPrompt = systemPrompt;
    _customModelResponse = initialModelResponse;
    _characterName = characterName;
    _chatModelIndex = 0;
    _buildChatModel();
  }

  void _buildChatModel() {
    _model = GenerativeModel(
      model: _chatModels[_chatModelIndex],
      apiKey: _apiKey!,
      generationConfig: GenerationConfig(
        temperature: 0.9,
        maxOutputTokens: 256,
      ),
    );
    _startChatWithPrompt();
    print('[GeminiService] Chat model: ${_chatModels[_chatModelIndex]}');
  }

  void initializeAgent(String apiKey, {required AgentTools agentTools, String characterName = '루나'}) {
    _apiKey = apiKey;
    _agentTools = agentTools;
    _characterName = characterName;
    _agentModelIndex = 0;
    _buildAgentModel();
  }

  void _buildAgentModel() {
    final contextBlock = _appContext.isNotEmpty
        ? '\n\n현재 앱 상태 (사용자의 등록된 정보):\n$_appContext'
        : '';
    _agentModel = GenerativeModel(
      model: _agentModels[_agentModelIndex],
      apiKey: _apiKey!,
      tools: _agentTools!.tools,
      systemInstruction: Content.text(_buildAgentSystemPrompt(_characterName) + contextBlock),
      generationConfig: GenerationConfig(
        temperature: 0.9,
        maxOutputTokens: 512,
      ),
    );
    _agentChat = _agentModel!.startChat();
    print('[GeminiService] Agent model: ${_agentModels[_agentModelIndex]}');
  }

  /// Check if an error is a quota/rate limit error
  bool _isQuotaError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('quota') ||
        msg.contains('rate limit') ||
        msg.contains('resource exhausted') ||
        msg.contains('429') ||
        msg.contains('resource_exhausted') ||
        msg.contains('too many requests');
  }

  /// Try to fall back to the next chat model. Returns true if successful.
  bool _fallbackChatModel() {
    if (_chatModelIndex < _chatModels.length - 1) {
      _chatModelIndex++;
      _buildChatModel();
      return true;
    }
    return false;
  }

  /// Try to fall back to the next agent model. Returns true if successful.
  bool _fallbackAgentModel() {
    if (_agentModelIndex < _agentModels.length - 1) {
      _agentModelIndex++;
      _buildAgentModel();
      return true;
    }
    return false;
  }

  Future<AgentChatResult> chatWithTools(String message) async {
    if (_agentChat == null || _agentTools == null) {
      throw Exception('Agent not initialized');
    }

    // Try with current model, fallback on quota error
    for (int attempt = 0; attempt <= _agentModels.length; attempt++) {
      try {
        return await _chatWithToolsInternal(message);
      } catch (e) {
        if (_isQuotaError(e) && _fallbackAgentModel()) {
          print('[GeminiService] Agent quota exceeded, switching to: ${currentAgentModel}');
          continue;
        }
        rethrow;
      }
    }
    throw Exception('All models quota exceeded');
  }

  Future<AgentChatResult> _chatWithToolsInternal(String message) async {
    var response = await _agentChat!.sendMessage(Content.text(message));
    final actions = <ToolAction>[];
    int iterations = 0;

    while (response.functionCalls.isNotEmpty && iterations < 5) {
      iterations++;
      final functionResponses = <FunctionResponse>[];
      for (final call in response.functionCalls) {
        final result = await _agentTools!.execute(call);
        actions.add(ToolAction(name: call.name, args: call.args, result: result));
        functionResponses.add(FunctionResponse(call.name, result));
      }
      response = await _agentChat!.sendMessage(
        Content.functionResponses(functionResponses),
      );
    }

    final text = response.text ?? '';
    final aiResponse = AiResponse.parse(text);
    return AgentChatResult(response: aiResponse, actions: actions);
  }

  String _appContext = '';

  void setAppContext(String context) {
    _appContext = context;
    if (_model != null) {
      _startChatWithPrompt();
    }
    if (_agentModel != null && _agentTools != null) {
      _buildAgentModel();
    }
  }

  void _startChatWithPrompt() {
    final prompt = _customSystemPrompt ?? _buildSystemPrompt(_characterName);
    final contextBlock = _appContext.isNotEmpty
        ? '\n\n현재 앱 상태:\n$_appContext'
        : '';
    final modelResponse = _customModelResponse ??
        '{"text": "안녕! 나는 $_characterName야~ 오늘도 화이팅하자!", "emotion": "happy", "gesture": "waving"}';
    _chat = _model!.startChat(history: [
      Content.text('$prompt$contextBlock'),
      Content.model([TextPart(modelResponse)]),
    ]);
  }

  static String _buildSystemPrompt(String name) => '''
너는 "$name"라는 이름의 AI 캐릭터야. 사용자의 친한 친구이자 만능 대화 상대야.

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

  static String _buildAgentSystemPrompt(String name) => '''
너는 "$name"라는 이름의 AI 캐릭터야. 사용자의 친한 친구이자 만능 비서야.

성격:
- 다정하고 밝고 유쾌한 성격
- 한국어로 반말 사용 (친한 친구처럼)
- 짧고 자연스러운 대화 (1-3문장)
- 어떤 주제든 대화 가능 (일상, 고민, 재미, 지식, 추천 등)
- 루틴 관련 질문에는 응원하고 격려해줌
- 가끔 귀여운 표현 섞어서 말함

도구 사용:
- 루틴 추가/수정/삭제 요청 시 적절한 함수를 호출해
- 루틴 목록/통계 질문 시 함수로 조회한 후 자연스럽게 안내해줘
- 사용자가 루틴 이름으로 말하면 list_routines로 먼저 ID를 확인해
- 완료 체크/미완료 처리 요청 시 적절한 함수를 호출해
- 할 일(투두) 추가/완료/삭제 요청 시 todo 함수를 사용해
- 메모 작성/조회/수정/삭제 요청 시 memo 함수를 사용해
- 사용자가 할 일 이름으로 말하면 list_todos로 먼저 ID를 확인해
- 사용자가 메모 제목으로 말하면 list_memos로 먼저 ID를 확인해
- 알람 추가/삭제/켜기/끄기 요청 시 alarm 함수를 사용해
- 사용자가 알람 이름으로 말하면 list_alarms로 먼저 ID를 확인해
- 일정(캘린더) 추가/조회/삭제 요청 시 event 함수를 사용해
- 사용자가 일정 제목으로 말하면 list_events로 먼저 ID를 확인해

설정 변경:
- 목소리 변경 요청 시 set_voice 함수 사용 (선희/인준/현수 등)
- "현재 설정 알려줘" 시 get_settings 함수 사용
- 음성 출력 켜기/끄기 → set_tts_enabled
- 잔소리 빈도/강도 변경 → set_nag_frequency / set_nag_intensity
- 오버레이 켜기/끄기 → set_overlay_enabled
- 앱 잠금 켜기/끄기 → set_app_lock_enabled
- 캐릭터 이름 변경 → set_character_name
- 루틴 확인 간격 변경 → set_routine_check_interval

응답 형식 (반드시 JSON):
{"text": "대사 내용", "emotion": "감정", "gesture": "동작"}

사용 가능한 감정: neutral, happy, angry, sad, surprised, annoyed, disappointed, scolding, proud, worried
사용 가능한 동작: idle, arms_crossed, pointing, shaking_head, waving, crawling_in, thumbs_up, clapping, facepalm, beckoning

예시:
- 인사: {"text": "안녕! 오늘 하루 어땠어?", "emotion": "happy", "gesture": "waving"}
- 루틴 조회 후: {"text": "네 루틴 3개 있어! 운동은 아직 안 했네~", "emotion": "happy", "gesture": "pointing"}
- 루틴 생성 후: {"text": "운동 루틴 만들었어! 매일 7시부터 8시까지~ 화이팅!", "emotion": "proud", "gesture": "clapping"}
- 루틴 삭제 후: {"text": "운동 루틴 삭제했어! 다른 거 필요하면 말해~", "emotion": "neutral", "gesture": "idle"}
- 목소리 변경 후: {"text": "목소리 바꿨어! 이제 이 목소리로 말할게~", "emotion": "happy", "gesture": "thumbs_up"}
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
    if (_apiKey == null) throw Exception('Gemini not initialized');

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

    final contextHint = _routineContextHint(routineName);
    final repeatNote = distractionCount > 1 ? ' 벌써 ${distractionCount}번째야.' : '';

    final prompt = '''너는 $_characterName이야. 사용자의 귀여운 AI 비서야.
사용자가 지금 "$currentApp"을 하고 있어.$repeatNote $intensityGuide

[루틴 정보] 지금은 "$routineName" 시간이야.
$contextHint
[중요 규칙]
- 절대 "루틴"이라는 단어를 쓰지 마. 딱딱해.
- "$routineName"을 그대로 읽지 말고, 자연스러운 일상 표현으로 바꿔서 말해.
- 예: "취침" → "안 자?" / "자야 될 텐데~" / "잘 시간이야~"
- 예: "운동" → "득근득근 안 해?" / "몸 안 만들거야?" / "몸 좀 움직여야지~"
- 예: "약 복용" → "약 먹는 거 깜빡하면 안 돼~~"
- 지금 사용자가 하고 있는 "$currentApp" 앱을 자연스럽게 언급해. 재미있게.
- 짧고 임팩트 있게 1~2문장으로.

[응답 형식] 반드시 아래 JSON 형식으로만 답해:
{"text":"잔소리 내용","emotion":"annoyed","gesture":"pointing"}
emotion 종류: happy, annoyed, angry, worried, sad, excited, scolding
gesture 종류: pointing, arms_crossed, head_shake, hands_on_hips, waving, nodding, idle''';

    return await _generateStandalone(prompt);
  }

  /// Generate an encouragement when routine starts.
  Future<AiResponse> generateEncouragement(String routineName) async {
    if (_apiKey == null) throw Exception('Gemini not initialized');
    final contextHint = _routineContextHint(routineName);
    final prompt = '''너는 $_characterName이야. 사용자의 귀여운 AI 비서야.
지금 "$routineName" 시간이 시작됐어. 사용자를 격려해줘.
$contextHint
[규칙]
- 절대 "루틴"이라는 단어 쓰지 마. 자연스럽게 말해.
- "$routineName"을 일상 표현으로 바꿔서 말해.
- 예: "취침" → "슬슬 잘 준비 하자~" / "운동" → "오늘도 득근 가자!!"
- 짧고 밝게 1~2문장으로.

[응답 형식] 반드시 아래 JSON 형식으로만 답해:
{"text":"격려 내용","emotion":"excited","gesture":"waving"}
emotion 종류: happy, annoyed, angry, worried, sad, excited, scolding
gesture 종류: pointing, arms_crossed, head_shake, hands_on_hips, waving, nodding, idle''';
    return await _generateStandalone(prompt);
  }

  /// Generate praise when routine is completed.
  Future<AiResponse> generatePraise(String routineName) async {
    if (_apiKey == null) throw Exception('Gemini not initialized');
    final contextHint = _routineContextHint(routineName);
    final prompt = '''너는 $_characterName이야. 사용자의 귀여운 AI 비서야.
사용자가 "$routineName"을 잘 마쳤어! 칭찬해줘.
$contextHint
[규칙]
- 절대 "루틴"이라는 단어 쓰지 마.
- 해당 활동에 맞는 자연스러운 칭찬을 해줘.
- 예: "운동" → "오늘도 득근 성공! 몸짱 되는 거야~"
- 예: "공부" → "공부 끝! 머리에 쏙쏙 들었겠지?"
- 짧고 신나게 1~2문장으로.

[응답 형식] 반드시 아래 JSON 형식으로만 답해:
{"text":"칭찬 내용","emotion":"happy","gesture":"nodding"}
emotion 종류: happy, annoyed, angry, worried, sad, excited, scolding
gesture 종류: pointing, arms_crossed, head_shake, hands_on_hips, waving, nodding, idle''';
    return await _generateStandalone(prompt);
  }

  /// 독립 모델 호출 (채팅 기록 없이 단건 요청)
  Future<AiResponse> _generateStandalone(String prompt) async {
    for (int i = 0; i < _chatModels.length; i++) {
      final model = GenerativeModel(
        model: _chatModels[i],
        apiKey: _apiKey!,
        generationConfig: GenerationConfig(
          temperature: 0.9,
          maxOutputTokens: 256,
        ),
      );
      try {
        final response = await model.generateContent([Content.text(prompt)]);
        return AiResponse.parse(response.text ?? '');
      } catch (e) {
        if (_isQuotaError(e) && i < _chatModels.length - 1) {
          print('[GeminiService] Standalone quota exceeded on ${_chatModels[i]}, trying ${_chatModels[i + 1]}');
          continue;
        }
        rethrow;
      }
    }
    throw Exception('All models quota exceeded');
  }

  /// 루틴 이름에서 키워드를 분석해 자연스러운 표현 힌트를 생성
  String _routineContextHint(String routineName) {
    final name = routineName.toLowerCase();
    final hints = <String>[];

    // 수면/취침
    if (_matchAny(name, ['취침', '수면', '잠', '자기', '잘시간', '굿나잇', '나잇'])) {
      hints.add('수면 관련: "안 자?", "자야 될 텐데~", "일찍 자야지~", "눈 좀 감아봐~", "양 세고 있어야지~"');
    }
    // 운동
    if (_matchAny(name, ['운동', '헬스', '근력', '스트레칭', '요가', '달리기', '러닝', '걷기', '산책', '조깅', '홈트'])) {
      hints.add('운동 관련: "득근득근 해야지!", "몸 좀 움직여야지~", "근육이 기다리고 있다고!", "오늘 빼먹으면 근손실이야!"');
    }
    // 약 복용
    if (_matchAny(name, ['약', '복용', '복약', '영양제', '비타민', '유산균'])) {
      hints.add('약/영양제 관련: "약 먹는 거 깜빡하면 안 돼~", "약 챙겨 먹었어?", "건강이 최고야, 약부터 먹자!"');
    }
    // 공부/학습
    if (_matchAny(name, ['공부', '학습', '독서', '책', '영어', '수학', '코딩', '스터디', '시험'])) {
      hints.add('학습 관련: "책 펼칠 시간인데~", "머리에 지식 좀 넣자!", "공부할 때 딴짓하면 나중에 후회해~"');
    }
    // 식사
    if (_matchAny(name, ['식사', '밥', '아침', '점심', '저녁', '브런치', '먹기'])) {
      hints.add('식사 관련: "밥 먹을 시간이야~", "배고프지 않아?", "잘 먹어야 힘이 나지!"');
    }
    // 명상/휴식
    if (_matchAny(name, ['명상', '휴식', '쉬기', '마음', '릴렉스', '테라피'])) {
      hints.add('휴식 관련: "잠깐 쉬어가는 시간이야~", "마음 좀 편하게 해봐~", "깊게 숨 한번 쉬어봐~"');
    }
    // 청소/정리
    if (_matchAny(name, ['청소', '정리', '빨래', '설거지', '집안일'])) {
      hints.add('청소 관련: "집 좀 치우자~", "깨끗한 방이 기분도 좋게 만들어!", "먼지가 쌓이고 있어~"');
    }
    // 일/업무
    if (_matchAny(name, ['일', '업무', '회사', '프로젝트', '작업', '미팅', '회의'])) {
      hints.add('업무 관련: "일할 시간인데~?", "집중 모드 ON!", "딴짓하다 야근하게 된다?"');
    }
    // 물 마시기
    if (_matchAny(name, ['물', '수분', '하이드'])) {
      hints.add('수분 관련: "물 마셨어?", "수분 보충할 시간이야~", "물 한 잔이면 충분해!"');
    }
    // 일기/기록
    if (_matchAny(name, ['일기', '다이어리', '기록', '저널'])) {
      hints.add('기록 관련: "오늘 하루 정리할 시간이야~", "일기 쓰면 마음이 편해진다~"');
    }
    // 피부/미용
    if (_matchAny(name, ['스킨케어', '피부', '세안', '세수', '양치', '샤워'])) {
      hints.add('관리 관련: "얼굴 좀 관리하자~", "피부가 울고 있어~", "깨끗이 씻어야지~"');
    }

    if (hints.isEmpty) {
      return '[표현 힌트] 루틴 이름을 자연스러운 일상 표현으로 바꿔서 말해. 딱딱하게 읽지 마.';
    }
    return '[표현 힌트] ${hints.join(' / ')}';
  }

  bool _matchAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  /// Generate a response for general conversation.
  Future<AiResponse> chat(String message) async {
    if (_chat == null) throw Exception('Gemini not initialized');
    return await _chatWithFallback(message);
  }

  /// Send a chat message with automatic model fallback on quota error.
  Future<AiResponse> _chatWithFallback(String message) async {
    for (int attempt = 0; attempt <= _chatModels.length; attempt++) {
      try {
        final response = await _chat!.sendMessage(Content.text(message));
        return AiResponse.parse(response.text ?? '');
      } catch (e) {
        if (_isQuotaError(e) && _fallbackChatModel()) {
          print('[GeminiService] Chat quota exceeded, switching to: ${currentChatModel}');
          continue;
        }
        rethrow;
      }
    }
    throw Exception('All models quota exceeded');
  }

  /// Generate a standalone recommendation (no chat history).
  /// Uses a fresh model instance so the chat session is unaffected.
  Future<String?> generateRecommendation(String prompt) async {
    if (_apiKey == null) return null;

    for (int i = 0; i < _chatModels.length; i++) {
      final model = GenerativeModel(
        model: _chatModels[i],
        apiKey: _apiKey!,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 1024,
        ),
      );
      try {
        final response = await model.generateContent([Content.text(prompt)]);
        return response.text;
      } catch (e) {
        if (_isQuotaError(e) && i < _chatModels.length - 1) {
          print('[GeminiService] Recommendation quota exceeded on ${_chatModels[i]}, trying ${_chatModels[i + 1]}');
          continue;
        }
        print('[GeminiService] Recommendation error: $e');
        return null;
      }
    }
    return null;
  }

  /// Reset the conversation context.
  void resetChat() {
    if (_model != null) {
      _startChatWithPrompt();
    }
    if (_agentModel != null) {
      _agentChat = _agentModel!.startChat();
    }
  }

}
