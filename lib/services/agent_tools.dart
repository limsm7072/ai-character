import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/routine.dart';
import '../models/alarm.dart';
import '../models/calendar_event.dart';
import 'routine_service.dart';
import 'routine_completion_service.dart';
import 'todo_service.dart';
import 'memo_service.dart';
import 'alarm_service.dart';
import 'calendar_service.dart';
import 'settings_service.dart';
import 'tts_service.dart';
import 'auto_page_service.dart';
import 'memory_service.dart';

class ToolAction {
  final String name;
  final Map<String, Object?> args;
  final Map<String, Object?> result;

  ToolAction({required this.name, required this.args, required this.result});
}

class AgentTools {
  final RoutineService routineService;
  final RoutineCompletionService completionService;
  final TodoService? todoService;
  final MemoService? memoService;
  final AlarmService? alarmService;
  final CalendarService? calendarService;
  final SettingsService? settingsService;
  final TtsService? ttsService;
  final AutoPageService? autoPageService;
  final MemoryService? memoryService;
  final Future<void> Function(String url)? onOpenUrl;

  AgentTools({
    required this.routineService,
    required this.completionService,
    this.todoService,
    this.memoService,
    this.alarmService,
    this.calendarService,
    this.settingsService,
    this.ttsService,
    this.autoPageService,
    this.memoryService,
    this.onOpenUrl,
  });

  List<Tool> get tools => [
    Tool(functionDeclarations: [
      FunctionDeclaration(
        'list_routines',
        '전체 루틴 목록과 오늘의 완료 상태를 조회합니다',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'create_routine',
        '새 루틴을 생성합니다',
        Schema(SchemaType.object,
          properties: {
            'name': Schema(SchemaType.string, description: '루틴 이름'),
            'start_date': Schema(SchemaType.string, description: '시작 날짜 (yyyy-MM-dd). 미지정시 오늘'),
            'start_hour': Schema(SchemaType.integer, description: '시작 시 (0-23)'),
            'start_minute': Schema(SchemaType.integer, description: '시작 분 (0-59)'),
            'end_hour': Schema(SchemaType.integer, description: '종료 시 (0-23)'),
            'end_minute': Schema(SchemaType.integer, description: '종료 분 (0-59)'),
            'active_days': Schema(SchemaType.array,
              description: '활동 요일 [월,화,수,목,금,토,일] 순서로 7개 boolean. 미지정시 매일',
              items: Schema(SchemaType.boolean),
            ),
          },
          requiredProperties: ['name', 'start_hour', 'start_minute', 'end_hour', 'end_minute'],
        ),
      ),
      FunctionDeclaration(
        'update_routine',
        '기존 루틴을 수정합니다',
        Schema(SchemaType.object,
          properties: {
            'routine_id': Schema(SchemaType.string, description: '수정할 루틴 ID'),
            'name': Schema(SchemaType.string, description: '새 루틴 이름'),
            'start_hour': Schema(SchemaType.integer, description: '새 시작 시'),
            'start_minute': Schema(SchemaType.integer, description: '새 시작 분'),
            'end_hour': Schema(SchemaType.integer, description: '새 종료 시'),
            'end_minute': Schema(SchemaType.integer, description: '새 종료 분'),
            'active_days': Schema(SchemaType.array,
              description: '새 활동 요일',
              items: Schema(SchemaType.boolean),
            ),
            'is_enabled': Schema(SchemaType.boolean, description: '활성화 여부'),
          },
          requiredProperties: ['routine_id'],
        ),
      ),
      FunctionDeclaration(
        'delete_routine',
        '루틴을 삭제합니다',
        Schema(SchemaType.object,
          properties: {
            'routine_id': Schema(SchemaType.string, description: '삭제할 루틴 ID'),
          },
          requiredProperties: ['routine_id'],
        ),
      ),
      FunctionDeclaration(
        'mark_complete',
        '루틴을 완료 체크합니다',
        Schema(SchemaType.object,
          properties: {
            'routine_id': Schema(SchemaType.string, description: '루틴 ID'),
            'date': Schema(SchemaType.string, description: '날짜 (yyyy-MM-dd). 미지정시 오늘'),
          },
          requiredProperties: ['routine_id'],
        ),
      ),
      FunctionDeclaration(
        'mark_skipped',
        '루틴을 미완료(건너뛰기) 처리합니다',
        Schema(SchemaType.object,
          properties: {
            'routine_id': Schema(SchemaType.string, description: '루틴 ID'),
            'date': Schema(SchemaType.string, description: '날짜 (yyyy-MM-dd). 미지정시 오늘'),
          },
          requiredProperties: ['routine_id'],
        ),
      ),
      FunctionDeclaration(
        'get_completion_rate',
        '루틴의 완료율을 조회합니다',
        Schema(SchemaType.object,
          properties: {
            'routine_id': Schema(SchemaType.string, description: '루틴 ID'),
            'days': Schema(SchemaType.integer, description: '조회 기간 (일수, 기본 7)'),
          },
          requiredProperties: ['routine_id'],
        ),
      ),
      // ─── Todo tools ─────────────────────────────────────
      FunctionDeclaration(
        'list_todos',
        '할 일 목록을 조회합니다',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'create_todo',
        '새 할 일을 추가합니다',
        Schema(SchemaType.object,
          properties: {
            'title': Schema(SchemaType.string, description: '할 일 내용'),
          },
          requiredProperties: ['title'],
        ),
      ),
      FunctionDeclaration(
        'complete_todo',
        '할 일을 완료/미완료 토글합니다',
        Schema(SchemaType.object,
          properties: {
            'todo_id': Schema(SchemaType.string, description: '할 일 ID'),
          },
          requiredProperties: ['todo_id'],
        ),
      ),
      FunctionDeclaration(
        'delete_todo',
        '할 일을 삭제합니다',
        Schema(SchemaType.object,
          properties: {
            'todo_id': Schema(SchemaType.string, description: '할 일 ID'),
          },
          requiredProperties: ['todo_id'],
        ),
      ),
      // ─── Memo tools ─────────────────────────────────────
      FunctionDeclaration(
        'list_memos',
        '메모 목록을 조회합니다',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'create_memo',
        '새 메모를 작성합니다',
        Schema(SchemaType.object,
          properties: {
            'title': Schema(SchemaType.string, description: '메모 제목'),
            'content': Schema(SchemaType.string, description: '메모 내용'),
          },
          requiredProperties: ['title'],
        ),
      ),
      FunctionDeclaration(
        'update_memo',
        '기존 메모를 수정합니다',
        Schema(SchemaType.object,
          properties: {
            'memo_id': Schema(SchemaType.string, description: '메모 ID'),
            'title': Schema(SchemaType.string, description: '새 제목'),
            'content': Schema(SchemaType.string, description: '새 내용'),
          },
          requiredProperties: ['memo_id'],
        ),
      ),
      FunctionDeclaration(
        'delete_memo',
        '메모를 삭제합니다',
        Schema(SchemaType.object,
          properties: {
            'memo_id': Schema(SchemaType.string, description: '메모 ID'),
          },
          requiredProperties: ['memo_id'],
        ),
      ),
      // ─── Alarm tools ─────────────────────────────────────
      FunctionDeclaration(
        'list_alarms',
        '알람 목록을 조회합니다',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'create_alarm',
        '새 알람을 생성합니다',
        Schema(SchemaType.object,
          properties: {
            'label': Schema(SchemaType.string, description: '알람 라벨'),
            'hour': Schema(SchemaType.integer, description: '시 (0-23)'),
            'minute': Schema(SchemaType.integer, description: '분 (0-59)'),
            'active_days': Schema(SchemaType.array,
              description: '반복 요일 [월,화,수,목,금,토,일] 순서로 7개 boolean. 미지정시 일회성',
              items: Schema(SchemaType.boolean),
            ),
          },
          requiredProperties: ['label', 'hour', 'minute'],
        ),
      ),
      FunctionDeclaration(
        'delete_alarm',
        '알람을 삭제합니다',
        Schema(SchemaType.object,
          properties: {
            'alarm_id': Schema(SchemaType.string, description: '알람 ID'),
          },
          requiredProperties: ['alarm_id'],
        ),
      ),
      FunctionDeclaration(
        'toggle_alarm',
        '알람을 켜거나 끕니다',
        Schema(SchemaType.object,
          properties: {
            'alarm_id': Schema(SchemaType.string, description: '알람 ID'),
          },
          requiredProperties: ['alarm_id'],
        ),
      ),
      // ─── Calendar tools ───────────────────────────────────
      FunctionDeclaration(
        'list_events',
        '일정을 조회합니다 (날짜 미지정시 오늘)',
        Schema(SchemaType.object,
          properties: {
            'date': Schema(SchemaType.string, description: '조회 날짜 (yyyy-MM-dd). 미지정시 오늘'),
          },
        ),
      ),
      FunctionDeclaration(
        'create_event',
        '새 일정을 추가합니다',
        Schema(SchemaType.object,
          properties: {
            'title': Schema(SchemaType.string, description: '일정 제목'),
            'date': Schema(SchemaType.string, description: '날짜 (yyyy-MM-dd)'),
            'description': Schema(SchemaType.string, description: '설명'),
            'start_hour': Schema(SchemaType.integer, description: '시작 시 (0-23)'),
            'start_minute': Schema(SchemaType.integer, description: '시작 분 (0-59)'),
            'end_hour': Schema(SchemaType.integer, description: '종료 시 (0-23)'),
            'end_minute': Schema(SchemaType.integer, description: '종료 분 (0-59)'),
          },
          requiredProperties: ['title', 'date'],
        ),
      ),
      FunctionDeclaration(
        'delete_event',
        '일정을 삭제합니다',
        Schema(SchemaType.object,
          properties: {
            'event_id': Schema(SchemaType.string, description: '일정 ID'),
          },
          requiredProperties: ['event_id'],
        ),
      ),
      // ─── Settings tools ─────────────────────────────────────
      FunctionDeclaration(
        'get_settings',
        '현재 앱 설정을 조회합니다 (목소리, 잔소리 빈도/강도, 음성출력, 오버레이, 앱잠금, 캐릭터 이름 등)',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'set_voice',
        '목소리를 변경합니다. 가능한 voice_id: sunhi(선희-밝고친근), sunhi_gentle(선희차분), sunhi_bright(선희활발), injoon(인준-차분), injoon_energetic(인준활발), hyunsu(현수-중후), hyunsu_deep(현수중저음)',
        Schema(SchemaType.object,
          properties: {
            'voice_id': Schema(SchemaType.string, description: '목소리 ID (sunhi, sunhi_gentle, sunhi_bright, injoon, injoon_energetic, hyunsu, hyunsu_deep)'),
          },
          requiredProperties: ['voice_id'],
        ),
      ),
      FunctionDeclaration(
        'set_tts_enabled',
        '음성 출력을 켜거나 끕니다',
        Schema(SchemaType.object,
          properties: {
            'enabled': Schema(SchemaType.boolean, description: 'true=켜기, false=끄기'),
          },
          requiredProperties: ['enabled'],
        ),
      ),
      FunctionDeclaration(
        'set_nag_frequency',
        '잔소리 빈도를 변경합니다',
        Schema(SchemaType.object,
          properties: {
            'seconds': Schema(SchemaType.integer, description: '잔소리 간격 (초). 가능한 값: 1, 5, 15, 30, 60, 120, 300'),
          },
          requiredProperties: ['seconds'],
        ),
      ),
      FunctionDeclaration(
        'set_nag_intensity',
        '잔소리 강도를 변경합니다',
        Schema(SchemaType.object,
          properties: {
            'level': Schema(SchemaType.integer, description: '0=부드럽게, 1=보통, 2=엄격하게'),
          },
          requiredProperties: ['level'],
        ),
      ),
      FunctionDeclaration(
        'set_overlay_enabled',
        '오버레이(딴짓할 때 캐릭터 표시)를 켜거나 끕니다',
        Schema(SchemaType.object,
          properties: {
            'enabled': Schema(SchemaType.boolean, description: 'true=켜기, false=끄기'),
          },
          requiredProperties: ['enabled'],
        ),
      ),
      FunctionDeclaration(
        'set_app_lock_enabled',
        '앱 잠금(루틴 시간에 차단된 앱 강제 종료)을 켜거나 끕니다',
        Schema(SchemaType.object,
          properties: {
            'enabled': Schema(SchemaType.boolean, description: 'true=켜기, false=끄기'),
          },
          requiredProperties: ['enabled'],
        ),
      ),
      FunctionDeclaration(
        'set_overlay_character_visible',
        '잔소리할 때 캐릭터 화면 표시 여부를 설정합니다. 끄면 목소리만 나옵니다',
        Schema(SchemaType.object,
          properties: {
            'visible': Schema(SchemaType.boolean, description: 'true=캐릭터 표시, false=목소리만'),
          },
          requiredProperties: ['visible'],
        ),
      ),
      FunctionDeclaration(
        'set_character_name',
        '캐릭터 이름을 변경합니다',
        Schema(SchemaType.object,
          properties: {
            'name': Schema(SchemaType.string, description: '새 캐릭터 이름'),
          },
          requiredProperties: ['name'],
        ),
      ),
      FunctionDeclaration(
        'set_routine_check_interval',
        '미완료 루틴 확인 간격을 변경합니다',
        Schema(SchemaType.object,
          properties: {
            'seconds': Schema(SchemaType.integer, description: '확인 간격 (초). 가능한 값: 5, 60, 300, 1800, 3600'),
          },
          requiredProperties: ['seconds'],
        ),
      ),
      FunctionDeclaration(
        'set_shake_to_disable',
        '흔들어서 알람 끄기 기능을 켜거나 끕니다',
        Schema(SchemaType.object,
          properties: {
            'enabled': Schema(SchemaType.boolean, description: 'true=켜기, false=끄기'),
          },
          requiredProperties: ['enabled'],
        ),
      ),
      FunctionDeclaration(
        'set_shake_count',
        '알람을 끄기 위한 흔들기 횟수를 설정합니다',
        Schema(SchemaType.object,
          properties: {
            'count': Schema(SchemaType.integer, description: '흔들기 횟수. 가능한 값: 5, 10, 15, 20, 30'),
          },
          requiredProperties: ['count'],
        ),
      ),
      // ─── URL open tool ─────────────────────────────────────
      FunctionDeclaration(
        'open_url',
        '사용자가 요청한 웹사이트나 앱을 엽니다. 예: 네이버, 유튜브, 구글 등. 사용자가 "네이버 열어줘", "유튜브 틀어줘" 같이 요청하면 이 도구를 사용하세요.',
        Schema(SchemaType.object,
          properties: {
            'url': Schema(SchemaType.string, description: '열 URL (예: https://www.naver.com, https://www.youtube.com)'),
          },
          requiredProperties: ['url'],
        ),
      ),
      FunctionDeclaration(
        'generate_daily_summary',
        '오늘의 일일 정리 페이지를 워크스페이스에 생성합니다. 사용자가 "오늘 정리해줘", "하루 요약해줘" 같이 요청하면 이 도구를 사용하세요.',
        Schema(SchemaType.object,
          properties: {
            'date': Schema(SchemaType.string, description: '날짜 (yyyy-MM-dd). 미지정시 오늘'),
          },
        ),
      ),
      FunctionDeclaration(
        'generate_planning_page',
        '내일(또는 지정 날짜) 계획 페이지를 워크스페이스에 생성합니다. 사용자가 "내일 계획 세워줘", "계획 정리해줘" 같이 요청하면 이 도구를 사용하세요.',
        Schema(SchemaType.object,
          properties: {
            'date': Schema(SchemaType.string, description: '계획 날짜 (yyyy-MM-dd). 미지정시 내일'),
          },
        ),
      ),
      FunctionDeclaration(
        'generate_weekly_review',
        '이번 주 주간 리뷰 페이지를 워크스페이스에 생성합니다. 사용자가 "이번 주 정리해줘", "주간 리뷰 만들어줘" 같이 요청하면 이 도구를 사용하세요.',
        Schema(SchemaType.object, properties: {}),
      ),
      // ─── Memory tools ─────────────────────────────────────
      FunctionDeclaration(
        'remember',
        '사용자에 대한 중요한 정보를 기억합니다. 대화 중 사용자의 이름, 나이, 직업, 취미, 좋아하는 것, 싫어하는 것, 생일, 습관, 목표 등 개인 정보를 파악하면 이 도구로 저장하세요. 사용자가 직접 "기억해" 라고 말하지 않아도 중요한 개인정보가 나오면 자동으로 저장하세요.',
        Schema(SchemaType.object,
          properties: {
            'key': Schema(SchemaType.string, description: '기억할 정보의 카테고리 (예: 이름, 나이, 직업, 취미, 좋아하는음식, 생일, 목표, 성격, MBTI 등)'),
            'value': Schema(SchemaType.string, description: '기억할 내용'),
          },
          requiredProperties: ['key', 'value'],
        ),
      ),
      FunctionDeclaration(
        'recall',
        '저장된 기억을 조회합니다. 사용자에 대해 기억하고 있는 정보를 확인할 때 사용하세요.',
        Schema(SchemaType.object,
          properties: {
            'key': Schema(SchemaType.string, description: '조회할 정보의 카테고리. 미지정시 전체 조회'),
          },
        ),
      ),
      FunctionDeclaration(
        'forget',
        '저장된 기억을 삭제합니다. 사용자가 "잊어줘", "삭제해줘" 같이 요청하면 이 도구를 사용하세요.',
        Schema(SchemaType.object,
          properties: {
            'key': Schema(SchemaType.string, description: '삭제할 정보의 카테고리'),
          },
          requiredProperties: ['key'],
        ),
      ),
    ]),
  ];

  // ─── 도구 카테고리 분류 (토큰 최적화) ──────────────────────
  static const toolCategories = <String, Set<String>>{
    'routine': {'list_routines', 'create_routine', 'update_routine', 'delete_routine', 'mark_complete', 'mark_skipped', 'get_completion_rate'},
    'todo': {'list_todos', 'create_todo', 'complete_todo', 'delete_todo'},
    'memo': {'list_memos', 'create_memo', 'update_memo', 'delete_memo'},
    'alarm': {'list_alarms', 'create_alarm', 'delete_alarm', 'toggle_alarm'},
    'calendar': {'list_events', 'create_event', 'delete_event'},
    'settings': {'get_settings', 'set_voice', 'set_tts_enabled', 'set_nag_frequency', 'set_nag_intensity', 'set_overlay_enabled', 'set_app_lock_enabled', 'set_overlay_character_visible', 'set_character_name', 'set_routine_check_interval', 'set_shake_to_disable', 'set_shake_count'},
    'url': {'open_url'},
    'memory': {'remember', 'recall', 'forget'},
    'workspace': {'generate_daily_summary', 'generate_planning_page', 'generate_weekly_review'},
  };

  /// OpenAI-compatible tool definitions (for Groq etc.)
  List<Map<String, dynamic>> get openAiTools => _buildOpenAiTools(null);

  /// 특정 카테고리의 도구만 OpenAI 포맷으로 반환
  List<Map<String, dynamic>> getOpenAiToolsForCategories(Set<String> categories) {
    final allowedNames = <String>{};
    for (final cat in categories) {
      final names = toolCategories[cat];
      if (names != null) allowedNames.addAll(names);
    }
    return _buildOpenAiTools(allowedNames);
  }

  List<Map<String, dynamic>> _buildOpenAiTools(Set<String>? allowedNames) {
    final declarations = <Map<String, dynamic>>[];
    for (final tool in tools) {
      if (tool.functionDeclarations == null) continue;
      for (final fd in tool.functionDeclarations!) {
        if (allowedNames != null && !allowedNames.contains(fd.name)) continue;
        declarations.add({
          'type': 'function',
          'function': {
            'name': fd.name,
            'description': fd.description,
            'parameters': fd.parameters != null ? _schemaToJson(fd.parameters!) : {'type': 'object', 'properties': {}},
          },
        });
      }
    }
    return declarations;
  }

  static Map<String, dynamic> _schemaToJson(Schema schema) {
    final result = <String, dynamic>{
      'type': _schemaTypeStr(schema.type),
    };
    if (schema.description != null && schema.description!.isNotEmpty) {
      result['description'] = schema.description;
    }
    if (schema.properties != null && schema.properties!.isNotEmpty) {
      final props = <String, dynamic>{};
      for (final entry in schema.properties!.entries) {
        props[entry.key] = _schemaToJson(entry.value);
      }
      result['properties'] = props;
    }
    if (schema.requiredProperties != null && schema.requiredProperties!.isNotEmpty) {
      result['required'] = schema.requiredProperties;
    }
    if (schema.items != null) {
      result['items'] = _schemaToJson(schema.items!);
    }
    if (schema.enumValues != null && schema.enumValues!.isNotEmpty) {
      result['enum'] = schema.enumValues;
    }
    return result;
  }

  static String _schemaTypeStr(SchemaType type) {
    switch (type) {
      case SchemaType.string: return 'string';
      case SchemaType.number: return 'number';
      case SchemaType.integer: return 'integer';
      case SchemaType.boolean: return 'boolean';
      case SchemaType.array: return 'array';
      case SchemaType.object: return 'object';
      default: return 'string';
    }
  }

  /// Execute a Gemini FunctionCall (delegates to executeRaw)
  Future<Map<String, Object?>> execute(FunctionCall call) async {
    return executeRaw(call.name, call.args);
  }

  /// Raw execute by name + args (for Groq/OpenAI-compatible APIs)
  Future<Map<String, Object?>> executeRaw(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'list_routines':
        return _listRoutines();
      case 'create_routine':
        return await _createRoutine(args.cast<String, Object?>());
      case 'update_routine':
        return await _updateRoutine(args.cast<String, Object?>());
      case 'delete_routine':
        return await _deleteRoutine(args.cast<String, Object?>());
      case 'mark_complete':
        return await _markComplete(args.cast<String, Object?>());
      case 'mark_skipped':
        return await _markSkipped(args.cast<String, Object?>());
      case 'get_completion_rate':
        return _getCompletionRate(args.cast<String, Object?>());
      case 'list_todos':
        return _listTodos();
      case 'create_todo':
        return await _createTodo(args.cast<String, Object?>());
      case 'complete_todo':
        return await _completeTodo(args.cast<String, Object?>());
      case 'delete_todo':
        return await _deleteTodo(args.cast<String, Object?>());
      case 'list_memos':
        return _listMemos();
      case 'create_memo':
        return await _createMemo(args.cast<String, Object?>());
      case 'update_memo':
        return await _updateMemo(args.cast<String, Object?>());
      case 'delete_memo':
        return await _deleteMemo(args.cast<String, Object?>());
      case 'list_alarms':
        return _listAlarms();
      case 'create_alarm':
        return await _createAlarm(args.cast<String, Object?>());
      case 'delete_alarm':
        return await _deleteAlarm(args.cast<String, Object?>());
      case 'toggle_alarm':
        return await _toggleAlarm(args.cast<String, Object?>());
      case 'list_events':
        return _listEvents(args.cast<String, Object?>());
      case 'create_event':
        return await _createEvent(args.cast<String, Object?>());
      case 'delete_event':
        return await _deleteEvent(args.cast<String, Object?>());
      case 'get_settings':
        return _getSettings();
      case 'set_voice':
        return await _setVoice(args.cast<String, Object?>());
      case 'set_tts_enabled':
        return await _setTtsEnabled(args.cast<String, Object?>());
      case 'set_nag_frequency':
        return await _setNagFrequency(args.cast<String, Object?>());
      case 'set_nag_intensity':
        return await _setNagIntensity(args.cast<String, Object?>());
      case 'set_overlay_enabled':
        return await _setOverlayEnabled(args.cast<String, Object?>());
      case 'set_app_lock_enabled':
        return await _setAppLockEnabled(args.cast<String, Object?>());
      case 'set_overlay_character_visible':
        return await _setOverlayCharacterVisible(args.cast<String, Object?>());
      case 'set_character_name':
        return await _setCharacterName(args.cast<String, Object?>());
      case 'set_routine_check_interval':
        return await _setRoutineCheckInterval(args.cast<String, Object?>());
      case 'set_shake_to_disable':
        return await _setShakeToDisable(args.cast<String, Object?>());
      case 'set_shake_count':
        return await _setShakeCount(args.cast<String, Object?>());
      case 'open_url':
        return await _openUrl(args.cast<String, Object?>());
      case 'generate_daily_summary':
        return await _generateDailySummary(args.cast<String, Object?>());
      case 'generate_planning_page':
        return await _generatePlanningPage(args.cast<String, Object?>());
      case 'generate_weekly_review':
        return await _generateWeeklyReview();
      case 'remember':
        return await _remember(args.cast<String, Object?>());
      case 'recall':
        return _recall(args.cast<String, Object?>());
      case 'forget':
        return await _forget(args.cast<String, Object?>());
      default:
        return {'error': '알 수 없는 함수: $name'};
    }
  }

  Future<Map<String, Object?>> _generateDailySummary(Map<String, Object?> args) async {
    if (autoPageService == null) return {'error': '워크스페이스 서비스를 사용할 수 없습니다'};
    final date = args['date'] as String? ?? _todayStr();
    try {
      final page = await autoPageService!.generateDailySummary(date);
      return {'success': true, 'title': page.title, 'page_id': page.id};
    } catch (e) {
      return {'error': '페이지 생성 실패: $e'};
    }
  }

  Future<Map<String, Object?>> _generatePlanningPage(Map<String, Object?> args) async {
    if (autoPageService == null) return {'error': '워크스페이스 서비스를 사용할 수 없습니다'};
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final defaultDate = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    final date = args['date'] as String? ?? defaultDate;
    try {
      final page = await autoPageService!.generatePlanningPage(date);
      return {'success': true, 'title': page.title, 'page_id': page.id};
    } catch (e) {
      return {'error': '페이지 생성 실패: $e'};
    }
  }

  Future<Map<String, Object?>> _generateWeeklyReview() async {
    if (autoPageService == null) return {'error': '워크스페이스 서비스를 사용할 수 없습니다'};
    try {
      final page = await autoPageService!.generateWeeklyReview();
      return {'success': true, 'title': page.title, 'page_id': page.id};
    } catch (e) {
      return {'error': '페이지 생성 실패: $e'};
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Map<String, Object?> _listRoutines() {
    final routines = routineService.getAll();
    final today = DateTime.now();
    final todayStr = _todayStr();
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];

    final list = routines.map((r) {
      final isToday = r.isActiveOnDate(today);
      String status = 'not_today';
      if (isToday) {
        if (completionService.isCompleted(r.id, todayStr)) {
          status = 'completed';
        } else if (completionService.isSkipped(r.id, todayStr)) {
          status = 'skipped';
        } else {
          status = 'pending';
        }
      }

      final activeDayStr = <String>[];
      for (int i = 0; i < 7; i++) {
        if (r.activeDays[i]) activeDayStr.add(dayNames[i]);
      }

      return <String, Object?>{
        'id': r.id,
        'name': r.name,
        'start_time': r.startTime.format(),
        'end_time': r.endTime.format(),
        'active_days': activeDayStr.join(','),
        'is_enabled': r.isEnabled,
        'today_status': status,
      };
    }).toList();

    return {'routines': list, 'today': todayStr, 'count': routines.length};
  }

  Future<Map<String, Object?>> _createRoutine(Map<String, Object?> args) async {
    try {
      final name = args['name'] as String;
      final startHour = (args['start_hour'] as num).toInt();
      final startMinute = (args['start_minute'] as num).toInt();
      final endHour = (args['end_hour'] as num).toInt();
      final endMinute = (args['end_minute'] as num).toInt();
      final startDate = args['start_date'] as String? ?? _todayStr();

      List<bool> activeDays = List.filled(7, true);
      if (args['active_days'] != null) {
        final days = args['active_days'] as List;
        if (days.length == 7) {
          activeDays = days.map((d) => d as bool).toList();
        }
      }

      final routine = Routine(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        startDate: startDate,
        startTime: TimeOfDay(hour: startHour, minute: startMinute),
        endTime: TimeOfDay(hour: endHour, minute: endMinute),
        activeDays: activeDays,
      );

      await routineService.add(routine);
      return {'success': true, 'routine_id': routine.id, 'name': name};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _updateRoutine(Map<String, Object?> args) async {
    try {
      final routineId = args['routine_id'] as String;
      final routines = routineService.getAll();
      final matches = routines.where((r) => r.id == routineId);

      if (matches.isEmpty) {
        return {'success': false, 'error': '루틴을 찾을 수 없습니다 (ID: $routineId)'};
      }

      final routine = matches.first;

      if (args['name'] != null) routine.name = args['name'] as String;
      if (args['start_hour'] != null && args['start_minute'] != null) {
        routine.startTime = TimeOfDay(
          hour: (args['start_hour'] as num).toInt(),
          minute: (args['start_minute'] as num).toInt(),
        );
      }
      if (args['end_hour'] != null && args['end_minute'] != null) {
        routine.endTime = TimeOfDay(
          hour: (args['end_hour'] as num).toInt(),
          minute: (args['end_minute'] as num).toInt(),
        );
      }
      if (args['active_days'] != null) {
        final days = args['active_days'] as List;
        if (days.length == 7) {
          routine.activeDays = days.map((d) => d as bool).toList();
        }
      }
      if (args['is_enabled'] != null) {
        routine.isEnabled = args['is_enabled'] as bool;
      }

      await routineService.update(routine);
      return {'success': true, 'name': routine.name};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _deleteRoutine(Map<String, Object?> args) async {
    try {
      final routineId = args['routine_id'] as String;
      final routines = routineService.getAll();
      final matches = routines.where((r) => r.id == routineId);

      if (matches.isEmpty) {
        return {'success': false, 'error': '루틴을 찾을 수 없습니다'};
      }

      final name = matches.first.name;
      await routineService.delete(routineId);
      return {'success': true, 'deleted_name': name};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _markComplete(Map<String, Object?> args) async {
    try {
      final routineId = args['routine_id'] as String;
      final date = args['date'] as String? ?? _todayStr();

      if (completionService.isCompleted(routineId, date)) {
        return {'success': true, 'already': true, 'message': '이미 완료 처리되어 있습니다'};
      }

      // Remove existing record if any (e.g. skipped)
      if (completionService.hasRecord(routineId, date)) {
        await completionService.toggleCompletion(routineId, date);
      }
      // Add completed record
      await completionService.toggleCompletion(routineId, date);
      return {'success': true, 'routine_id': routineId, 'date': date};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _markSkipped(Map<String, Object?> args) async {
    try {
      final routineId = args['routine_id'] as String;
      final date = args['date'] as String? ?? _todayStr();

      if (completionService.isSkipped(routineId, date)) {
        return {'success': true, 'already': true, 'message': '이미 미완료 처리되어 있습니다'};
      }

      await completionService.markSkipped(routineId, date);
      return {'success': true, 'routine_id': routineId, 'date': date};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Map<String, Object?> _getCompletionRate(Map<String, Object?> args) {
    try {
      final routineId = args['routine_id'] as String;
      final days = (args['days'] as num?)?.toInt() ?? 7;

      final rate = completionService.getCompletionRate(routineId, days);
      return {
        'success': true,
        'rate': rate,
        'days': days,
        'percentage': '${(rate * 100).toStringAsFixed(1)}%',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Todo handlers ──────────────────────────────────────

  Map<String, Object?> _listTodos() {
    if (todoService == null) return {'error': 'TodoService not available'};
    final todos = todoService!.getAll();
    final list = todos.map((t) => <String, Object?>{
      'id': t.id,
      'title': t.title,
      'is_completed': t.isCompleted,
    }).toList();
    final incomplete = todos.where((t) => !t.isCompleted).length;
    return {'todos': list, 'count': todos.length, 'incomplete': incomplete};
  }

  Future<Map<String, Object?>> _createTodo(Map<String, Object?> args) async {
    if (todoService == null) return {'error': 'TodoService not available'};
    try {
      final title = args['title'] as String;
      final todo = await todoService!.add(title);
      return {'success': true, 'todo_id': todo.id, 'title': title};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _completeTodo(Map<String, Object?> args) async {
    if (todoService == null) return {'error': 'TodoService not available'};
    try {
      final todoId = args['todo_id'] as String;
      await todoService!.toggleComplete(todoId);
      final todos = todoService!.getAll();
      final match = todos.where((t) => t.id == todoId);
      if (match.isEmpty) return {'success': false, 'error': '할 일을 찾을 수 없습니다'};
      return {'success': true, 'todo_id': todoId, 'is_completed': match.first.isCompleted};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _deleteTodo(Map<String, Object?> args) async {
    if (todoService == null) return {'error': 'TodoService not available'};
    try {
      final todoId = args['todo_id'] as String;
      final todos = todoService!.getAll();
      final match = todos.where((t) => t.id == todoId);
      final title = match.isNotEmpty ? match.first.title : '';
      await todoService!.delete(todoId);
      return {'success': true, 'deleted_title': title};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Memo handlers ──────────────────────────────────────

  Map<String, Object?> _listMemos() {
    if (memoService == null) return {'error': 'MemoService not available'};
    final memos = memoService!.getAll();
    final list = memos.map((m) => <String, Object?>{
      'id': m.id,
      'title': m.title,
      'content': m.content.length > 100 ? '${m.content.substring(0, 100)}...' : m.content,
    }).toList();
    return {'memos': list, 'count': memos.length};
  }

  Future<Map<String, Object?>> _createMemo(Map<String, Object?> args) async {
    if (memoService == null) return {'error': 'MemoService not available'};
    try {
      final title = args['title'] as String;
      final content = args['content'] as String? ?? '';
      final memo = await memoService!.add(title, content: content);
      return {'success': true, 'memo_id': memo.id, 'title': title};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _updateMemo(Map<String, Object?> args) async {
    if (memoService == null) return {'error': 'MemoService not available'};
    try {
      final memoId = args['memo_id'] as String;
      final memos = memoService!.getAll();
      final match = memos.where((m) => m.id == memoId);
      if (match.isEmpty) return {'success': false, 'error': '메모를 찾을 수 없습니다'};

      final memo = match.first;
      if (args['title'] != null) memo.title = args['title'] as String;
      if (args['content'] != null) memo.content = args['content'] as String;
      await memoService!.update(memo);
      return {'success': true, 'title': memo.title};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _deleteMemo(Map<String, Object?> args) async {
    if (memoService == null) return {'error': 'MemoService not available'};
    try {
      final memoId = args['memo_id'] as String;
      final memos = memoService!.getAll();
      final match = memos.where((m) => m.id == memoId);
      final title = match.isNotEmpty ? match.first.title : '';
      await memoService!.delete(memoId);
      return {'success': true, 'deleted_title': title};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Alarm handlers ──────────────────────────────────────

  Map<String, Object?> _listAlarms() {
    if (alarmService == null) return {'error': 'AlarmService not available'};
    final alarms = alarmService!.getAll();
    final list = alarms.map((a) => <String, Object?>{
      'id': a.id,
      'label': a.label,
      'time': a.timeString,
      'days': a.daysString,
      'is_enabled': a.isEnabled,
    }).toList();
    return {'alarms': list, 'count': alarms.length, 'enabled': alarmService!.enabledCount};
  }

  Future<Map<String, Object?>> _createAlarm(Map<String, Object?> args) async {
    if (alarmService == null) return {'error': 'AlarmService not available'};
    try {
      final label = args['label'] as String;
      final hour = (args['hour'] as num).toInt();
      final minute = (args['minute'] as num).toInt();
      List<bool> activeDays = List.filled(7, false);
      if (args['active_days'] != null) {
        final days = args['active_days'] as List;
        if (days.length == 7) {
          activeDays = days.map((d) => d as bool).toList();
        }
      }
      final alarm = Alarm(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        label: label,
        hour: hour,
        minute: minute,
        activeDays: activeDays,
      );
      await alarmService!.add(alarm);
      return {'success': true, 'alarm_id': alarm.id, 'label': label, 'time': alarm.timeString};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _deleteAlarm(Map<String, Object?> args) async {
    if (alarmService == null) return {'error': 'AlarmService not available'};
    try {
      final alarmId = args['alarm_id'] as String;
      final alarms = alarmService!.getAll();
      final match = alarms.where((a) => a.id == alarmId);
      final label = match.isNotEmpty ? match.first.label : '';
      await alarmService!.delete(alarmId);
      return {'success': true, 'deleted_label': label};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _toggleAlarm(Map<String, Object?> args) async {
    if (alarmService == null) return {'error': 'AlarmService not available'};
    try {
      final alarmId = args['alarm_id'] as String;
      await alarmService!.toggleEnabled(alarmId);
      final alarms = alarmService!.getAll();
      final match = alarms.where((a) => a.id == alarmId);
      if (match.isEmpty) return {'success': false, 'error': '알람을 찾을 수 없습니다'};
      return {'success': true, 'alarm_id': alarmId, 'is_enabled': match.first.isEnabled};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Calendar handlers ───────────────────────────────────

  Map<String, Object?> _listEvents(Map<String, Object?> args) {
    if (calendarService == null) return {'error': 'CalendarService not available'};
    final date = args['date'] as String? ?? _todayStr();
    final events = calendarService!.getByDate(date);
    final list = events.map((e) => <String, Object?>{
      'id': e.id,
      'title': e.title,
      'time': e.timeString,
      'description': e.description,
    }).toList();
    return {'events': list, 'date': date, 'count': events.length};
  }

  Future<Map<String, Object?>> _createEvent(Map<String, Object?> args) async {
    if (calendarService == null) return {'error': 'CalendarService not available'};
    try {
      final title = args['title'] as String;
      final date = args['date'] as String;
      final event = CalendarEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        date: date,
        description: args['description'] as String? ?? '',
        startHour: (args['start_hour'] as num?)?.toInt(),
        startMinute: (args['start_minute'] as num?)?.toInt(),
        endHour: (args['end_hour'] as num?)?.toInt(),
        endMinute: (args['end_minute'] as num?)?.toInt(),
      );
      await calendarService!.add(event);
      return {'success': true, 'event_id': event.id, 'title': title, 'date': date};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _deleteEvent(Map<String, Object?> args) async {
    if (calendarService == null) return {'error': 'CalendarService not available'};
    try {
      final eventId = args['event_id'] as String;
      final events = calendarService!.getAll();
      final match = events.where((e) => e.id == eventId);
      final title = match.isNotEmpty ? match.first.title : '';
      await calendarService!.delete(eventId);
      return {'success': true, 'deleted_title': title};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Settings handlers ──────────────────────────────────────

  Map<String, Object?> _getSettings() {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    final s = settingsService!;
    final preset = voicePresets.firstWhere(
      (p) => p.id == s.voicePreset,
      orElse: () => voicePresets.first,
    );
    return {
      'voice': {'id': s.voicePreset, 'label': preset.label, 'description': preset.description},
      'tts_enabled': s.ttsEnabled,
      'nag_frequency_seconds': s.nagFrequency,
      'nag_intensity': s.nagIntensity,
      'nag_intensity_label': s.nagIntensity == 0 ? '부드럽게' : s.nagIntensity == 1 ? '보통' : '엄격하게',
      'overlay_enabled': s.overlayEnabled,
      'app_lock_enabled': s.appLockEnabled,
      'overlay_character_visible': s.overlayCharacterVisible,
      'character_name': s.characterName,
      'routine_check_interval_seconds': s.routineCheckInterval,
      'shake_to_disable': s.shakeToDisable,
      'shake_count': s.shakeCount,
    };
  }

  Future<Map<String, Object?>> _setVoice(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final voiceId = args['voice_id'] as String;
      final validIds = voicePresets.map((p) => p.id).toSet();
      if (!validIds.contains(voiceId)) {
        return {'success': false, 'error': '유효하지 않은 목소리 ID: $voiceId', 'available': validIds.toList()};
      }
      await settingsService!.setVoicePreset(voiceId);
      if (ttsService != null) {
        await ttsService!.applyPreset(voiceId);
      }
      final preset = voicePresets.firstWhere((p) => p.id == voiceId);
      return {'success': true, 'voice_id': voiceId, 'label': preset.label, 'description': preset.description};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _setTtsEnabled(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final enabled = args['enabled'] as bool;
      await settingsService!.setTtsEnabled(enabled);
      return {'success': true, 'tts_enabled': enabled};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _setNagFrequency(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final seconds = (args['seconds'] as num).toInt();
      const valid = [1, 5, 15, 30, 60, 120, 300];
      if (!valid.contains(seconds)) {
        return {'success': false, 'error': '유효하지 않은 값: $seconds초', 'available': valid};
      }
      await settingsService!.setNagFrequency(seconds);
      return {'success': true, 'nag_frequency_seconds': seconds};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _setNagIntensity(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final level = (args['level'] as num).toInt();
      if (level < 0 || level > 2) {
        return {'success': false, 'error': '유효하지 않은 강도: $level (0~2)'};
      }
      await settingsService!.setNagIntensity(level);
      final label = level == 0 ? '부드럽게' : level == 1 ? '보통' : '엄격하게';
      return {'success': true, 'nag_intensity': level, 'label': label};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _setOverlayEnabled(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final enabled = args['enabled'] as bool;
      await settingsService!.setOverlayEnabled(enabled);
      return {'success': true, 'overlay_enabled': enabled};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _setAppLockEnabled(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final enabled = args['enabled'] as bool;
      await settingsService!.setAppLockEnabled(enabled);
      return {'success': true, 'app_lock_enabled': enabled};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _setOverlayCharacterVisible(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final visible = args['visible'] as bool;
      await settingsService!.setOverlayCharacterVisible(visible);
      return {'success': true, 'overlay_character_visible': visible};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _setCharacterName(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final name = args['name'] as String;
      if (name.trim().isEmpty) {
        return {'success': false, 'error': '이름이 비어있습니다'};
      }
      await settingsService!.setCharacterName(name.trim());
      return {'success': true, 'character_name': name.trim()};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _setRoutineCheckInterval(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final seconds = (args['seconds'] as num).toInt();
      const valid = [5, 60, 300, 1800, 3600];
      if (!valid.contains(seconds)) {
        return {'success': false, 'error': '유효하지 않은 값: $seconds초', 'available': valid};
      }
      await settingsService!.setRoutineCheckInterval(seconds);
      return {'success': true, 'routine_check_interval_seconds': seconds};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _setShakeToDisable(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final enabled = args['enabled'] as bool;
      await settingsService!.setShakeToDisable(enabled);
      return {'success': true, 'shake_to_disable': enabled};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _setShakeCount(Map<String, Object?> args) async {
    if (settingsService == null) return {'error': 'SettingsService not available'};
    try {
      final count = (args['count'] as num).toInt();
      const valid = [5, 10, 15, 20, 30];
      if (!valid.contains(count)) {
        return {'success': false, 'error': '유효하지 않은 값: $count회', 'available': valid};
      }
      await settingsService!.setShakeCount(count);
      return {'success': true, 'shake_count': count};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _openUrl(Map<String, Object?> args) async {
    try {
      final url = args['url'] as String;
      if (onOpenUrl != null) {
        await onOpenUrl!(url);
        return {'success': true, 'url': url};
      }
      return {'success': false, 'error': 'URL 열기 기능을 사용할 수 없습니다'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Memory handlers ──────────────────────────────────────

  Future<Map<String, Object?>> _remember(Map<String, Object?> args) async {
    if (memoryService == null) return {'error': 'MemoryService not available'};
    try {
      final key = args['key'] as String;
      final value = args['value'] as String;
      await memoryService!.set(key.trim(), value.trim());
      return {'success': true, 'key': key, 'value': value, 'total_memories': memoryService!.count};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Map<String, Object?> _recall(Map<String, Object?> args) {
    if (memoryService == null) return {'error': 'MemoryService not available'};
    final key = args['key'] as String?;
    if (key != null) {
      final value = memoryService!.get(key);
      if (value == null) return {'found': false, 'key': key};
      return {'found': true, 'key': key, 'value': value};
    }
    final all = memoryService!.getAll();
    return {'memories': all, 'count': all.length};
  }

  Future<Map<String, Object?>> _forget(Map<String, Object?> args) async {
    if (memoryService == null) return {'error': 'MemoryService not available'};
    try {
      final key = args['key'] as String;
      final existed = memoryService!.get(key) != null;
      await memoryService!.remove(key);
      return {'success': true, 'key': key, 'existed': existed};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

}
