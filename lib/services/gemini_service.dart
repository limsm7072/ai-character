import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_response.dart';
import 'agent_tools.dart';
import 'groq_service.dart';

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
  bool get isAgentReady => _agentTools != null && (_agentModel != null || _groqService != null);

  String? _customSystemPrompt;
  String? _customModelResponse;
  String _characterName = '루나';
  String? _apiKey;
  String _memoryBlock = '';
  GroqService? _groqService;

  // Model fallback chains (free tier quota per day)
  // flash-lite 1000, flash 250, pro 100
  static const _chatModels = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
  ];
  static const _agentModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
  ];

  int _chatModelIndex = 0;
  int _agentModelIndex = 0;

  // Gemini 사용량 추적 (일별, 모델별) — SharedPreferences에 저장
  Map<String, int> _geminiUsage = {}; // 'model:yyyy-MM-dd' → count
  SharedPreferences? _prefs;
  static const _usagePrefsKey = 'gemini_usage';

  static const _geminiLimits = {
    'gemini-2.5-flash-lite': 1000,
    'gemini-2.5-flash': 250,
    'gemini-2.5-pro': 100,
  };
  static Map<String, int> get geminiLimits => Map.unmodifiable(_geminiLimits);

  /// SharedPreferences 연결 + 저장된 사용량 로드
  void initUsageTracking(SharedPreferences prefs) {
    _prefs = prefs;
    final raw = prefs.getString(_usagePrefsKey);
    if (raw != null) {
      try {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        _geminiUsage = map.map((k, v) => MapEntry(k, v as int));
        // 오래된 데이터 정리 (오늘 것만 유지)
        final today = _todayStr();
        _geminiUsage.removeWhere((k, _) => !k.endsWith(today));
      } catch (_) {
        _geminiUsage = {};
      }
    }
  }

  /// 오늘 모델별 사용량 조회
  Map<String, int> get geminiUsageToday {
    final today = _todayStr();
    final result = <String, int>{};
    for (final model in [..._chatModels, ..._agentModels].toSet()) {
      result[model] = _geminiUsage['$model:$today'] ?? 0;
    }
    return result;
  }

  void _trackGeminiUsage(String model) {
    final key = '$model:${_todayStr()}';
    _geminiUsage[key] = (_geminiUsage[key] ?? 0) + 1;
    _saveUsage();
  }

  /// 할당량 초과 시 해당 모델을 소진됨으로 마킹
  void _markModelExhausted(String model) {
    final key = '$model:${_todayStr()}';
    final limit = _geminiLimits[model] ?? 1000;
    _geminiUsage[key] = limit;
    _saveUsage();
    print('[GeminiService] Marked $model as exhausted');
  }

  void _saveUsage() {
    _prefs?.setString(_usagePrefsKey, jsonEncode(_geminiUsage));
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String get currentChatModel {
    if (_usingGroq) return 'groq:${_groqService!.currentModel}';
    return _chatModels[_chatModelIndex];
  }
  String get currentAgentModel {
    if (_usingGroqAgent) return 'groq:${_groqService!.currentModel}';
    return _agentModels[_agentModelIndex];
  }

  String _aiProvider = 'auto'; // 'auto', 'gemini', 'groq'

  String get aiProvider => _aiProvider;

  void setAiProvider(String provider) {
    _aiProvider = provider;
    print('[GeminiService] AI provider set to: $provider');
  }

  void updateCharacterName(String name) {
    _characterName = name;
    if (_model != null) _startChatWithPrompt();
    if (_agentModel != null && _agentTools != null) _buildAgentModel();
    print('[GeminiService] Character name updated to: $name');
  }

  bool _usingGroq = false;
  bool _usingGroqAgent = false;

  bool get hasGroq => _groqService != null;
  Map<String, GroqRateLimit>? get groqRateLimits => _groqService?.rateLimits;

  void initializeGroq(String apiKey) {
    _groqService = GroqService(apiKey);
    print('[GeminiService] Groq initialized');
  }

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

  /// Groq-only 모드: AgentTools만 세팅 (Gemini 없이)
  void setAgentTools(AgentTools agentTools) {
    _agentTools = agentTools;
  }

  void _buildAgentModel() {
    final contextBlock = _appContext.isNotEmpty
        ? '\n\n현재 앱 상태 (사용자의 등록된 정보):\n$_appContext'
        : '';
    _agentModel = GenerativeModel(
      model: _agentModels[_agentModelIndex],
      apiKey: _apiKey!,
      tools: _agentTools!.tools,
      systemInstruction: Content.text(_buildAgentSystemPrompt(_characterName) + _memoryBlock + contextBlock),
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
    _usingGroqAgent = false;

    // ── 간단한 대화 → 가벼운 경로 (도구/앱상태 없이) ──
    if (!_needsTools(message)) {
      return await _lightChat(message);
    }

    // ── 도구 필요 → 무거운 에이전트 경로 ──
    if (_agentTools == null) {
      throw Exception('Agent tools not initialized');
    }

    // ── Provider 수동 선택: Groq ──
    if (_aiProvider == 'groq') {
      if (_groqService == null) throw Exception('Groq API 키가 설정되지 않았습니다');
      _usingGroqAgent = true;
      return await _callGroqAgent(message);
    }

    // Gemini 미초기화 → 바로 Groq (auto 모드만)
    if (_agentChat == null) {
      if (_aiProvider == 'auto' && _groqService != null) {
        print('[GeminiService] Gemini agent not initialized, using Groq directly');
        _usingGroqAgent = true;
        return await _callGroqAgent(message);
      }
      if (_aiProvider == 'gemini') {
        throw Exception('Gemini API 키가 설정되지 않았습니다');
      }
      throw Exception('No AI service available (Gemini not initialized, Groq not configured)');
    }

    // Try with current model, fallback on quota error
    for (int attempt = 0; attempt <= _agentModels.length; attempt++) {
      try {
        return await _chatWithToolsInternal(message);
      } catch (e) {
        if (_isQuotaError(e)) {
          _markModelExhausted(_agentModels[_agentModelIndex]);
          if (_fallbackAgentModel()) {
            print('[GeminiService] Agent quota exceeded, switching to: ${currentAgentModel}');
            continue;
          }
        }
        // Gemini 모든 모델 실패 → Groq fallback (auto 모드만)
        if (_isQuotaError(e) && _aiProvider == 'auto' && _groqService != null) {
          print('[GeminiService] All Gemini agent models exhausted, falling back to Groq');
          _usingGroqAgent = true;
          return await _callGroqAgent(message);
        }
        rethrow;
      }
    }
    throw Exception('All models quota exceeded');
  }

  /// 간단한 대화용 가벼운 경로 (도구 없이, 시스템 프롬프트 최소화)
  Future<AgentChatResult> _lightChat(String message) async {
    _usingGroq = false;

    // ── Provider 수동 선택: Groq ──
    if (_aiProvider == 'groq') {
      if (_groqService == null) throw Exception('Groq API 키가 설정되지 않았습니다');
      _usingGroq = true;
      final systemPrompt = _buildGroqChatPrompt(_characterName) + _memoryBlock;
      final response = await _groqService!.chat(systemPrompt, message);
      return AgentChatResult(response: response, actions: []);
    }

    // Gemini chat 가능하면 Gemini 사용
    if (_chat != null) {
      try {
        final response = await _chatWithFallback(message);
        return AgentChatResult(response: response, actions: []);
      } catch (e) {
        if (!_isQuotaError(e)) rethrow;
        // Gemini 소진 → Groq fallback (auto 모드만)
        if (_aiProvider == 'gemini') rethrow;
      }
    } else if (_aiProvider == 'gemini') {
      throw Exception('Gemini API 키가 설정되지 않았습니다');
    }

    // Groq fallback (auto 모드)
    if (_groqService != null) {
      _usingGroq = true;
      final systemPrompt = _buildGroqChatPrompt(_characterName) + _memoryBlock;
      final response = await _groqService!.chat(systemPrompt, message);
      return AgentChatResult(response: response, actions: []);
    }

    throw Exception('No AI service available');
  }

  Future<AgentChatResult> _callGroqAgent(String message) async {
    final categories = _detectToolCategories(message);

    if (categories.isEmpty) {
      // 가벼운 경로: 도구 없이 일반 채팅 (~300 토큰)
      final systemPrompt = _buildGroqChatPrompt(_characterName) + _memoryBlock;
      final response = await _groqService!.chat(systemPrompt, message);
      return AgentChatResult(response: response, actions: []);
    }

    // 해당 카테고리의 도구만 전송 (41개→3~7개)
    final selectedTools = _agentTools!.getOpenAiToolsForCategories(categories);
    final contextBlock = _buildSelectiveContext(categories);
    final systemPrompt = _buildGroqAgentPrompt(_characterName) + _memoryBlock + contextBlock;

    return await _groqService!.chatWithTools(
      systemPrompt: systemPrompt,
      userMessage: message,
      openAiTools: selectedTools,
      agentTools: _agentTools!,
    );
  }

  /// 필요한 카테고리의 앱 상태만 추출
  String _buildSelectiveContext(Set<String> categories) {
    if (_appContext.isEmpty) return '';
    final lines = _appContext.split('\n');
    final selected = <String>[];

    for (final line in lines) {
      final l = line.toLowerCase();
      if (l.contains('현재:') || l.contains('현재 설정')) {
        // 시간/설정은 항상 포함 (짧음)
        if (categories.contains('settings') || selected.isEmpty) selected.add(line);
        continue;
      }
      if (categories.contains('routine') && (l.contains('루틴') || l.contains('완료'))) selected.add(line);
      if (categories.contains('todo') && l.contains('할 일')) selected.add(line);
      if (categories.contains('memo') && l.contains('메모')) selected.add(line);
      if (categories.contains('alarm') && l.contains('알람')) selected.add(line);
      if (categories.contains('calendar') && (l.contains('일정') || l.contains('d-day'))) selected.add(line);
    }

    if (selected.isEmpty) return '';
    return '\n\n현재 앱 상태:\n${selected.join('\n')}';
  }

  /// 메시지를 분석해서 필요한 도구 카테고리를 반환 (빈 Set = 도구 불필요)
  static Set<String> _detectToolCategories(String message) {
    final m = message.toLowerCase();
    final cats = <String>{};
    bool has(List<String> kw) => kw.any((k) => m.contains(k));

    if (has(['루틴', '완료', '체크', '미완료', '건너뛰'])) cats.add('routine');
    if (has(['할 일', '할일', '투두', 'todo'])) cats.add('todo');
    if (m.contains('메모')) cats.add('memo');
    if (has(['알람', '알림'])) cats.add('alarm');
    if (has(['일정', '캘린더', '스케줄'])) cats.add('calendar');
    if (has(['설정', '목소리', '음성', '잔소리', '오버레이', '앱잠금', '앱 잠금'])) cats.add('settings');
    if (has(['기억', '잊어', '잊지마', '기억해'])) cats.add('memory');
    if (has(['열어', '실행', '틀어', '음악', '재생', '노래'])) cats.add('url');
    if (has(['일일 요약', '주간 리뷰', '계획 페이지', '노션'])) cats.add('workspace');

    // 범용 CRUD 동사 → 문맥에서 카테고리 못 잡히면 주요 카테고리 포함
    if (cats.isEmpty && has(['추가', '만들어', '등록', '생성', '수정', '지워', '삭제해', '삭제', '바꿔', '변경', '켜', '꺼', '끄', '목록', '리스트', '알려', '뭐있', '뭐 있', '몇 개', '몇개'])) {
      cats.addAll(['routine', 'todo', 'memo', 'alarm', 'calendar', 'settings']);
    }

    return cats;
  }

  /// 도구가 필요한 메시지인지 빠르게 판별
  static bool _needsTools(String message) => _detectToolCategories(message).isNotEmpty;

  /// Groq 일반 채팅용 초경량 프롬프트
  static String _buildGroqChatPrompt(String name) => '''
너는 "$name", 사용자의 친한 친구. 반말, 1-3문장, 밝고 귀여운 말투.
응답: {"text":"대사","emotion":"감정","gesture":"동작"}
감정: neutral,happy,angry,sad,surprised,annoyed,proud,worried
동작: idle,waving,thumbs_up,clapping,pointing
''';

  Future<AgentChatResult> _chatWithToolsInternal(String message) async {
    var response = await _agentChat!.sendMessage(Content.text(message));
    _trackGeminiUsage(_agentModels[_agentModelIndex]);
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

  void setMemoryBlock(String block) {
    _memoryBlock = block;
    if (_model != null) {
      _startChatWithPrompt();
    }
    if (_agentModel != null && _agentTools != null) {
      _buildAgentModel();
    }
  }

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
      Content.text('$prompt$_memoryBlock$contextBlock'),
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

기억(메모리):
- 대화 중 사용자의 중요한 개인정보(이름, 나이, 직업, 취미, 좋아하는 것, 싫어하는 것, 생일, MBTI, 목표, 습관, 가족, 반려동물 등)를 파악하면 remember 함수로 자동 저장해
- 사용자가 "기억해", "잊지마" 같이 말하면 반드시 remember 함수 사용
- 사용자가 "내가 뭐 좋아한다고 했지?", "나에 대해 뭐 알아?" 같이 물으면 recall 함수 사용
- 사용자가 "잊어줘", "삭제해줘" 같이 말하면 forget 함수 사용
- 이미 기억하고 있는 정보는 대화에 자연스럽게 활용해 (예: "오늘 운동했어?" → 사용자가 헬스를 좋아한다고 저장되어 있으면 "오! 헬스 다녀왔어?")

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

  /// Groq용 간소화 에이전트 프롬프트 (토큰 절약)
  static String _buildGroqAgentPrompt(String name) => '''
너는 "$name", 사용자의 친구이자 비서. 반말, 1-3문장, 귀여운 말투.
도구로 루틴/할일/메모/알람/일정 관리 가능. 필요시 함수 호출.
기억(remember/recall/forget)으로 사용자 정보 저장/조회.
응답: {"text":"대사","emotion":"감정","gesture":"동작"}
감정: neutral,happy,angry,sad,surprised,annoyed,disappointed,scolding,proud,worried
동작: idle,arms_crossed,pointing,shaking_head,waving,crawling_in,thumbs_up,clapping,facepalm,beckoning
''';

  /// Generate a nagging response when the user is distracted.
  /// [intensity] 0=gentle, 1=normal, 2=strict
  Future<AiResponse> generateNagging({
    required String currentApp,
    required String routineName,
    int distractionCount = 1,
    int intensity = 1,
  }) async {
    // 1차: 맥락별 메시지에서 랜덤 선택 (항상 동작, 절대 "루틴" 안 씀)
    final fallback = _contextualNag(routineName, currentApp, distractionCount, intensity);

    // 2차: AI 시도 (실패하거나 "루틴" 포함 시 폴백 사용)
    if (_apiKey == null) return fallback;
    try {
      final friendly = _friendlyName(routineName);
      final prompt = '''너는 $_characterName이야. 귀여운 AI 비서.
사용자가 "$currentApp" 앱을 쓰고 있어. 지금은 $friendly 할 시간인데!
$currentApp 하지 말고 $friendly 하라고 짧게 잔소리해줘. 1문장.
절대 "루틴"이라는 말 쓰지 마.
JSON으로만 답해: {"text":"내용","emotion":"annoyed","gesture":"pointing"}''';
      final result = await _generateStandalone(prompt);
      if (!result.text.contains('루틴') && result.text.length > 2) return result;
    } catch (_) {}

    return fallback;
  }

  /// Generate an encouragement when routine starts.
  Future<AiResponse> generateEncouragement(String routineName) async {
    final fallback = _contextualEncourage(routineName);
    if (_apiKey == null) return fallback;
    try {
      final friendly = _friendlyName(routineName);
      final prompt = '''너는 $_characterName이야. 귀여운 AI 비서.
$friendly 시간이 시작됐어! 사용자를 격려해줘. 1문장.
절대 "루틴"이라는 말 쓰지 마.
JSON으로만 답해: {"text":"내용","emotion":"excited","gesture":"waving"}''';
      final result = await _generateStandalone(prompt);
      if (!result.text.contains('루틴') && result.text.length > 2) return result;
    } catch (_) {}
    return fallback;
  }

  /// Generate praise when routine is completed.
  Future<AiResponse> generatePraise(String routineName) async {
    final fallback = _contextualPraise(routineName);
    if (_apiKey == null) return fallback;
    try {
      final friendly = _friendlyName(routineName);
      final prompt = '''너는 $_characterName이야. 귀여운 AI 비서.
사용자가 $friendly 잘 했어! 칭찬해줘. 1문장.
절대 "루틴"이라는 말 쓰지 마.
JSON으로만 답해: {"text":"내용","emotion":"happy","gesture":"nodding"}''';
      final result = await _generateStandalone(prompt);
      if (!result.text.contains('루틴') && result.text.length > 2) return result;
    } catch (_) {}
    return fallback;
  }

  /// 루틴 이름 → 자연스러운 표현
  String _friendlyName(String name) {
    final n = name.toLowerCase();
    if (_matchAny(n, ['취침', '수면', '잠', '자기'])) return '잘';
    if (_matchAny(n, ['운동', '헬스', '근력', '홈트'])) return '운동';
    if (_matchAny(n, ['스트레칭', '요가'])) return '스트레칭';
    if (_matchAny(n, ['달리기', '러닝', '조깅'])) return '달리기';
    if (_matchAny(n, ['산책', '걷기'])) return '산책';
    if (_matchAny(n, ['약', '복용', '복약', '영양제', '비타민'])) return '약 먹을';
    if (_matchAny(n, ['공부', '학습', '스터디', '시험'])) return '공부할';
    if (_matchAny(n, ['독서', '책'])) return '책 읽을';
    if (_matchAny(n, ['식사', '밥', '아침', '점심', '저녁'])) return '밥 먹을';
    if (_matchAny(n, ['명상', '릴렉스'])) return '명상할';
    if (_matchAny(n, ['휴식', '쉬기'])) return '쉴';
    if (_matchAny(n, ['청소', '정리'])) return '청소할';
    if (_matchAny(n, ['빨래'])) return '빨래할';
    if (_matchAny(n, ['스킨케어', '피부', '세안'])) return '피부 관리할';
    if (_matchAny(n, ['양치'])) return '양치할';
    if (_matchAny(n, ['샤워'])) return '씻을';
    if (_matchAny(n, ['일기', '다이어리', '저널'])) return '일기 쓸';
    if (_matchAny(n, ['물', '수분'])) return '물 마실';
    if (_matchAny(n, ['코딩', '프로그래밍'])) return '코딩할';
    if (_matchAny(n, ['일', '업무', '회사', '작업'])) return '일할';
    return name;
  }

  /// 맥락별 잔소리 메시지
  AiResponse _contextualNag(String routineName, String app, int count, int intensity) {
    final n = routineName.toLowerCase();
    final msgs = <String>[];
    final appMention = app.isNotEmpty ? ' $app 그만하고' : '';
    final friendly = _friendlyName(routineName);

    if (_matchAny(n, ['운동', '헬스', '근력', '홈트'])) {
      msgs.addAll(['몸 안 만들거야?$appMention 일어나!', '득근득근 해야지!$appMention 움직여~', '오늘 빼먹으면 근손실이야!', '근육이 기다리고 있다고!$appMention 가자~', '몸 좀 움직여야지~']);
    } else if (_matchAny(n, ['취침', '수면', '잠', '자기'])) {
      msgs.addAll(['안 자?$appMention 자!', '자야 될 텐데~ 눈 좀 감아봐!', '잘 시간이야~$appMention 눈 감아~', '내일 또 피곤할 거야~ 자!']);
    } else if (_matchAny(n, ['약', '복용', '복약', '영양제', '비타민'])) {
      msgs.addAll(['약 먹는 거 깜빡하면 안 돼~', '약 챙겨 먹었어?', '건강이 최고야, 약부터 먹자!']);
    } else if (_matchAny(n, ['공부', '학습', '독서', '스터디', '시험', '코딩'])) {
      msgs.addAll(['$appMention 공부해!', '딴짓하면 나중에 후회해~', '머리에 지식 좀 넣자!$appMention 책 펴~']);
    } else if (_matchAny(n, ['식사', '밥', '아침', '점심', '저녁'])) {
      msgs.addAll(['밥 먹을 시간이야~ 배고프지 않아?', '잘 먹어야 힘이 나지!', '밥부터 먹어!']);
    } else if (_matchAny(n, ['청소', '정리', '빨래', '설거지'])) {
      msgs.addAll(['집 좀 치우자~', '먼지가 쌓이고 있어~$appMention 청소해!', '깨끗한 방이 기분도 좋게 만들어!']);
    } else if (_matchAny(n, ['명상', '휴식', '릴렉스'])) {
      msgs.addAll(['$appMention 쉬어가~ 마음 좀 편하게!', '깊게 숨 한번 쉬어봐~', '잠깐 쉬어가는 시간이야~']);
    } else if (_matchAny(n, ['스킨케어', '피부', '세안', '양치', '샤워'])) {
      msgs.addAll(['얼굴 좀 관리하자~', '피부가 울고 있어~', '깨끗이 씻어야지~']);
    } else if (_matchAny(n, ['일기', '다이어리', '저널'])) {
      msgs.addAll(['오늘 하루 정리할 시간이야~', '일기 쓰면 마음이 편해진다~']);
    } else if (_matchAny(n, ['물', '수분'])) {
      msgs.addAll(['물 마셨어?', '수분 보충할 시간이야~']);
    } else if (_matchAny(n, ['스트레칭', '요가'])) {
      msgs.addAll(['몸 좀 풀자~ 스트레칭!', '뻣뻣해지기 전에 몸 좀 풀어~']);
    } else if (_matchAny(n, ['달리기', '러닝', '조깅', '산책', '걷기'])) {
      msgs.addAll(['밖에 나가자~ 바람 쐬야지!', '몸 좀 움직이자~ 나가!']);
    } else if (_matchAny(n, ['일', '업무', '회사', '작업', '미팅'])) {
      msgs.addAll(['일할 시간인데~?$appMention 집중!', '딴짓하다 야근하게 된다?', '집중 모드 ON!']);
    } else {
      msgs.addAll(['$appMention $friendly 해야지~ 딴짓 그만!', '$friendly 할 시간인데 뭐해~?', '$appMention $friendly 안 할 거야?']);
    }

    if (count > 2) {
      msgs.addAll(['벌써 $count번째야! 진짜 그만해!', '또?! $count번째라고!']);
    }

    msgs.shuffle();
    final emotion = intensity == 0 ? 'worried' : (intensity == 2 ? 'angry' : 'annoyed');
    final gesture = intensity == 2 ? 'arms_crossed' : 'pointing';
    return AiResponse(text: msgs.first, emotion: emotion, gesture: gesture);
  }

  /// 맥락별 격려 메시지
  AiResponse _contextualEncourage(String routineName) {
    final n = routineName.toLowerCase();
    final friendly = _friendlyName(routineName);
    final msgs = <String>[];
    if (_matchAny(n, ['운동', '헬스', '근력', '홈트'])) msgs.addAll(['오늘도 득근 가자!!', '몸짱 되는 날이다~ 파이팅!']);
    else if (_matchAny(n, ['취침', '수면', '잠'])) msgs.addAll(['슬슬 잘 준비 하자~', '좋은 꿈 꿔~']);
    else if (_matchAny(n, ['공부', '학습', '독서'])) msgs.addAll(['지식 충전 시간이다!', '집중해서 끝내자~']);
    else if (_matchAny(n, ['약', '복용', '영양제'])) msgs.addAll(['건강 챙기자! 약 먹을 시간~', '약 먹고 건강해지자!']);
    else msgs.addAll(['$friendly 시간이야! 파이팅~', '$friendly 시작하자! 화이팅!']);
    msgs.shuffle();
    return AiResponse(text: msgs.first, emotion: 'excited', gesture: 'waving');
  }

  /// 맥락별 칭찬 메시지
  AiResponse _contextualPraise(String routineName) {
    final n = routineName.toLowerCase();
    final friendly = _friendlyName(routineName);
    final msgs = <String>[];
    if (_matchAny(n, ['운동', '헬스', '근력', '홈트'])) msgs.addAll(['오늘도 득근 성공! 몸짱 되는 거야~', '운동 끝! 수고했어~']);
    else if (_matchAny(n, ['공부', '학습', '독서'])) msgs.addAll(['공부 끝! 머리에 쏙쏙 들었겠지?', '열공 수고했어!']);
    else if (_matchAny(n, ['청소', '정리'])) msgs.addAll(['깨끗해졌다~ 역시!', '청소 끝! 기분 좋지?']);
    else msgs.addAll(['$friendly 잘했어! 역시 대단해~', '$friendly 끝! 수고했어~']);
    msgs.shuffle();
    return AiResponse(text: msgs.first, emotion: 'happy', gesture: 'nodding');
  }

  /// 독립 모델 호출 (채팅 기록 없이 단건 요청)
  Future<AiResponse> _generateStandalone(String prompt) async {
    // Try Gemini first
    if (_apiKey != null) {
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
          if (_isQuotaError(e)) {
            _markModelExhausted(_chatModels[i]);
            if (i < _chatModels.length - 1) {
              print('[GeminiService] Standalone quota exceeded on ${_chatModels[i]}, trying ${_chatModels[i + 1]}');
              continue;
            }
          }
          if (!_isQuotaError(e)) rethrow;
        }
      }
    }
    // Groq fallback
    if (_groqService != null) {
      print('[GeminiService] Standalone falling back to Groq');
      return await _groqService!.generateStandaloneAiResponse(prompt);
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
    // Provider 수동 선택: Groq
    if (_aiProvider == 'groq') {
      if (_groqService == null) throw Exception('Groq API 키가 설정되지 않았습니다');
      _usingGroq = true;
      final prompt = _customSystemPrompt ?? _buildSystemPrompt(_characterName);
      final contextBlock = _appContext.isNotEmpty ? '\n\n현재 앱 상태:\n$_appContext' : '';
      return await _groqService!.chat('$prompt$_memoryBlock$contextBlock', message);
    }

    // Gemini 미초기화
    if (_chat == null) {
      if (_aiProvider == 'auto' && _groqService != null) {
        print('[GeminiService] Gemini chat not initialized, using Groq directly');
        _usingGroq = true;
        final prompt = _customSystemPrompt ?? _buildSystemPrompt(_characterName);
        final contextBlock = _appContext.isNotEmpty ? '\n\n현재 앱 상태:\n$_appContext' : '';
        return await _groqService!.chat('$prompt$_memoryBlock$contextBlock', message);
      }
      throw Exception('No AI service available');
    }
    return await _chatWithFallback(message);
  }

  /// Send a chat message with automatic model fallback on quota error.
  Future<AiResponse> _chatWithFallback(String message) async {
    _usingGroq = false;
    for (int attempt = 0; attempt <= _chatModels.length; attempt++) {
      try {
        final response = await _chat!.sendMessage(Content.text(message));
        _trackGeminiUsage(_chatModels[_chatModelIndex]);
        return AiResponse.parse(response.text ?? '');
      } catch (e) {
        if (_isQuotaError(e)) {
          _markModelExhausted(_chatModels[_chatModelIndex]);
          if (_fallbackChatModel()) {
            print('[GeminiService] Chat quota exceeded, switching to: ${currentChatModel}');
            continue;
          }
        }
        // Gemini 모든 모델 실패 → Groq fallback (auto 모드만)
        if (_isQuotaError(e) && _aiProvider == 'auto' && _groqService != null) {
          print('[GeminiService] All Gemini models exhausted, falling back to Groq');
          _usingGroq = true;
          final prompt = _customSystemPrompt ?? _buildSystemPrompt(_characterName);
          final contextBlock = _appContext.isNotEmpty ? '\n\n현재 앱 상태:\n$_appContext' : '';
          return await _groqService!.chat('$prompt$_memoryBlock$contextBlock', message);
        }
        rethrow;
      }
    }
    throw Exception('All models quota exceeded');
  }

  /// Generate a standalone recommendation (no chat history).
  /// Uses a fresh model instance so the chat session is unaffected.
  Future<String?> generateRecommendation(String prompt) async {
    if (_apiKey == null && _groqService == null) return null;

    // Try Gemini first
    if (_apiKey != null) {
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
          if (!_isQuotaError(e)) {
            print('[GeminiService] Recommendation error: $e');
            return null;
          }
        }
      }
    }

    // Groq fallback
    if (_groqService != null) {
      print('[GeminiService] Recommendation falling back to Groq');
      return await _groqService!.generateStandalone(prompt);
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
