import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/character_state.dart';
import '../models/character_registry.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/accessory_service.dart';
import '../services/routine_service.dart';
import '../services/routine_completion_service.dart';
import '../services/agent_tools.dart';
import '../services/health_service.dart';
import '../services/todo_service.dart';
import '../services/memo_service.dart';
import '../services/alarm_service.dart';
import '../services/calendar_service.dart';
import '../services/weather_service.dart';
import '../services/news_service.dart';
import '../services/card_service.dart';
import '../services/timer_service.dart';
import '../services/diary_service.dart';
import '../widgets/spine_character_widget.dart';
import '../theme/app_colors.dart';
import 'dress_up_screen.dart';

class CharacterChatScreen extends StatefulWidget {
  final SettingsService settingsService;
  final AccessoryService accessoryService;
  final RoutineService? routineService;
  final RoutineCompletionService? completionService;
  final HealthService? healthService;
  final TodoService? todoService;
  final MemoService? memoService;
  final AlarmService? alarmService;
  final CalendarService? calendarService;
  final WeatherService? weatherService;
  final NewsService? newsService;
  final CardService? cardService;
  final TimerService? timerService;
  final DiaryService? diaryService;
  final VoidCallback? onRoutinesChanged;

  const CharacterChatScreen({
    super.key,
    required this.settingsService,
    required this.accessoryService,
    this.routineService,
    this.completionService,
    this.healthService,
    this.todoService,
    this.memoService,
    this.alarmService,
    this.calendarService,
    this.weatherService,
    this.newsService,
    this.cardService,
    this.timerService,
    this.diaryService,
    this.onRoutinesChanged,
  });

  @override
  State<CharacterChatScreen> createState() => _CharacterChatScreenState();
}

class _CharacterChatScreenState extends State<CharacterChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _gemini = GeminiService();
  final _tts = TtsService();
  final _speech = stt.SpeechToText();
  final _messages = <_ChatMessage>[];
  CharacterState _characterState = const CharacterState();
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _voiceMode = false; // Continuous voice mode
  String _currentWords = '';

  @override
  void initState() {
    super.initState();
    _initGemini();
    _loadAppContext();
    // _initSpeech is called lazily in _ensureSpeechReady()
    // to avoid conflicting with HomeScreen's wake word SpeechToText
  }

  String get _charName => widget.settingsService.characterName;

  void _initGemini() {
    final apiKey = widget.settingsService.apiKey;
    if (apiKey.isNotEmpty && widget.routineService != null && widget.completionService != null) {
      final agentTools = AgentTools(
        routineService: widget.routineService!,
        completionService: widget.completionService!,
        todoService: widget.todoService,
        memoService: widget.memoService,
        alarmService: widget.alarmService,
        calendarService: widget.calendarService,
        settingsService: widget.settingsService,
        ttsService: _tts,
        onOpenUrl: (url) async {
          const channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
          await channel.invokeMethod('openUrl', {'url': url});
        },
        onPlayMusic: (query) async {
          const channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
          await channel.invokeMethod('playMusic', {'query': query});
        },
      );
      _gemini.initializeAgent(apiKey, agentTools: agentTools, characterName: _charName);
    }
  }

  Future<void> _loadAppContext() async {
    final parts = <String>[];
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    parts.add('현재: ${now.year}년 ${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일 ${now.hour}시 ${now.minute}분');

    // 설정 정보
    final s = widget.settingsService;
    final voicePreset = voicePresets.firstWhere(
      (p) => p.id == s.voicePreset,
      orElse: () => voicePresets.first,
    );
    parts.add('현재 설정: 캐릭터이름=${s.characterName}, 목소리=${voicePreset.label}, 음성출력=${s.ttsEnabled ? "켜짐" : "꺼짐"}, 잔소리빈도=${s.nagFrequency}초, 잔소리강도=${s.nagIntensity == 0 ? "부드럽게" : s.nagIntensity == 1 ? "보통" : "엄격하게"}, 오버레이=${s.overlayEnabled ? "켜짐" : "꺼짐"}, 캐릭터표시=${s.overlayCharacterVisible ? "켜짐" : "꺼짐(목소리만)"}, 앱잠금=${s.appLockEnabled ? "켜짐" : "꺼짐"}');

    // 날씨
    if (widget.weatherService != null) {
      final weather = widget.weatherService!.getCached();
      if (weather != null) {
        final loc = s.weatherLocationName.isNotEmpty ? s.weatherLocationName : '현재위치';
        parts.add('날씨($loc): ${weather.temperature.toStringAsFixed(1)}°C, ${weather.description}, 습도 ${weather.humidity}%, UV ${weather.uvIndex.toStringAsFixed(1)}');
      }
    }

    // 루틴
    if (widget.routineService != null && widget.completionService != null) {
      final routines = widget.routineService!.getAll();
      final active = routines.where((r) => r.isActiveOnDate(now)).toList();
      final done = active.where((r) =>
          widget.completionService!.isCompleted(r.id, todayStr) ||
          widget.completionService!.isSkipped(r.id, todayStr)).length;
      parts.add('오늘 루틴: ${active.length}개 중 ${done}개 완료');
      if (active.isNotEmpty) {
        final names = active.map((r) {
          final isDone = widget.completionService!.isCompleted(r.id, todayStr) ||
              widget.completionService!.isSkipped(r.id, todayStr);
          return '${r.name}(${r.startTime.format()}~${r.endTime.format()}, ${isDone ? "완료" : "미완료"})';
        }).join(', ');
        parts.add('  - $names');
      }
    }

    // 할 일
    if (widget.todoService != null) {
      final incomplete = widget.todoService!.getIncomplete();
      if (incomplete.isNotEmpty) {
        final names = incomplete.take(5).map((t) => t.title).join(', ');
        parts.add('미완료 할 일: ${incomplete.length}개 ($names)');
      } else {
        parts.add('할 일: 모두 완료');
      }
    }

    // 메모
    if (widget.memoService != null) {
      final memos = widget.memoService!.getAll();
      if (memos.isNotEmpty) {
        final titles = memos.take(5).map((m) => m.title).join(', ');
        parts.add('메모: ${memos.length}개 ($titles)');
      }
    }

    // 알람
    if (widget.alarmService != null) {
      final alarms = widget.alarmService!.getAll();
      final enabled = alarms.where((a) => a.isEnabled).toList();
      if (enabled.isNotEmpty) {
        final alarmList = enabled.take(5).map((a) => '${a.label}(${a.timeString})').join(', ');
        parts.add('활성 알람: ${enabled.length}개 ($alarmList)');
      }
    }

    // 타이머 프리셋
    if (widget.timerService != null) {
      final presets = widget.timerService!.getAll();
      if (presets.isNotEmpty) {
        final presetList = presets.take(5).map((p) => '${p.label}(${p.durationSeconds ~/ 60}분)').join(', ');
        parts.add('타이머 프리셋: ${presets.length}개 ($presetList)');
      }
    }

    // 캘린더
    if (widget.calendarService != null) {
      final todayEvents = widget.calendarService!.getByDate(todayStr);
      if (todayEvents.isNotEmpty) {
        final eventList = todayEvents.take(5).map((e) => '${e.title}${e.timeString.isNotEmpty ? "(${e.timeString})" : ""}').join(', ');
        parts.add('오늘 일정: ${todayEvents.length}건 ($eventList)');
      }
      final ddayEvents = widget.calendarService!.getDDayEvents();
      final upcoming = ddayEvents.where((e) {
        final d = DateTime.tryParse(e.date);
        return d != null && !d.isBefore(DateTime(now.year, now.month, now.day));
      }).take(3).toList();
      if (upcoming.isNotEmpty) {
        final ddayStr = upcoming.map((e) => '${e.title}(${e.dDayString()})').join(', ');
        parts.add('D-Day: $ddayStr');
      }
    }

    // 명함 (개인정보 요약 - 외부 전송 없음, 앱 내부 컨텍스트용)
    if (widget.cardService != null) {
      final card = widget.cardService!.get();
      if (card != null && card.name.isNotEmpty) {
        final cardParts = <String>[];
        cardParts.add('이름=${card.name}');
        if (card.company.isNotEmpty) cardParts.add('회사=${card.company}');
        if (card.position.isNotEmpty) cardParts.add('직책=${card.position}');
        if (card.phone.isNotEmpty) cardParts.add('전화=${card.phone}');
        if (card.email.isNotEmpty) cardParts.add('이메일=${card.email}');
        if (card.city.isNotEmpty || card.province.isNotEmpty) {
          cardParts.add('지역=${card.province} ${card.city}'.trim());
        }
        if (card.gender.isNotEmpty) cardParts.add('성별=${card.gender}');
        if (card.birthYear.isNotEmpty) cardParts.add('출생년도=${card.birthYear}');
        if (card.bio.isNotEmpty) cardParts.add('자기소개=${card.bio}');
        final interests = [card.interest1, card.interest2, card.interest3]
            .where((i) => i.isNotEmpty).toList();
        if (interests.isNotEmpty) cardParts.add('관심사=${interests.join(",")}');
        parts.add('사용자 명함: ${cardParts.join(", ")}');
      }
    }

    // 일기
    if (widget.diaryService != null) {
      final todayDiary = widget.diaryService!.getByDate(todayStr);
      final streak = widget.diaryService!.getCurrentStreak();
      if (todayDiary != null) {
        parts.add('오늘 일기: ${todayDiary.moodLabel} - ${todayDiary.content.isNotEmpty ? todayDiary.content : "(내용 없음)"}');
      }
      if (streak > 0) {
        parts.add('일기 연속 작성: ${streak}일');
      }
      final recent = widget.diaryService!.getRecent(limit: 3);
      if (recent.isNotEmpty) {
        final recentStr = recent.where((d) => d.date != todayStr).take(2).map((d) => '${d.date}: ${d.moodLabel}${d.content.isNotEmpty ? " - ${d.content.length > 30 ? d.content.substring(0, 30) + "..." : d.content}" : ""}').join(', ');
        if (recentStr.isNotEmpty) parts.add('최근 일기: $recentStr');
      }
    }

    // 뉴스 헤드라인
    if (widget.newsService != null) {
      final headlines = widget.newsService!.getCached();
      if (headlines.isNotEmpty) {
        parts.add('주요 뉴스: ${headlines.take(3).join(" / ")}');
      }
    }

    // 건강
    if (widget.healthService != null) {
      try {
        if (widget.healthService!.isAuthorized) {
          final healthSummary = await widget.healthService!.buildHealthSummary();
          if (healthSummary.isNotEmpty) {
            parts.add(healthSummary);
          }
        }
      } catch (_) {}
    }

    if (parts.isNotEmpty) {
      _gemini.setAppContext(parts.join('\n'));
    }
  }

  Future<void> _ensureSpeechReady() async {
    if (_speechAvailable) return;
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_isListening && mounted) {
            setState(() => _isListening = false);
          }
        }
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _tts.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasApiKey = widget.settingsService.apiKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('$_charName와 대화'),
        centerTitle: true,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '새 대화',
              onPressed: _clearChat,
            ),
          if (CharacterRegistry.getById(
                  widget.settingsService.selectedCharacter)
              .supportsDressUp)
            IconButton(
              icon: const Icon(Icons.checkroom),
              tooltip: '꾸미기',
              onPressed: _openDressUp,
            ),
        ],
      ),
      body: Column(
        children: [
          // Spine 2D Character display — hide when keyboard is open or setting is off
          if (widget.settingsService.chatCharacterVisible && MediaQuery.of(context).viewInsets.bottom < 50)
            SizedBox(
              height: 250,
              child: Builder(builder: (_) {
                final config = CharacterRegistry.getById(
                    widget.settingsService.selectedCharacter);
                final customSkins = widget.accessoryService
                    .getSelectedSkins(config.id);
                final customColors = widget.accessoryService
                    .getSlotColors(config.id);
                return SpineCharacterWidget(
                  key: ValueKey('${config.id}_${customSkins.join("_")}_${customColors.hashCode}'),
                  config: config,
                  state: _characterState,
                  customSkins: customSkins.isNotEmpty ? customSkins : null,
                  customColors: customColors.isNotEmpty ? customColors : null,
                  showBubble: false,
                  interactive: true,
                );
              }),
            ),

          // Messages
          Expanded(
            child: !hasApiKey
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.key, size: 48, color: AppColors.grey400),
                          const SizedBox(height: 16),
                          Text(
                            'Gemini API 키를 설정해주세요',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.grey600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '설정 탭에서 API 키를 입력하면\n$_charName와 대화할 수 있어요',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.grey500),
                          ),
                        ],
                      ),
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_charName에게 말을 걸어보세요!',
                              style: TextStyle(color: AppColors.grey500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '루틴, 할 일, 메모, 알람, 일정도 대화로 관리해요',
                              style: TextStyle(
                                color: AppColors.grey400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildMessage(_messages[i]),
                      ),
          ),

          // Listening indicator
          if (_isListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentWords.isEmpty ? '듣고 있어요...' : _currentWords,
                      style: TextStyle(
                        color: _currentWords.isEmpty
                            ? AppColors.grey600
                            : AppColors.black87,
                        fontStyle: _currentWords.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _stopListening();
                      setState(() => _voiceMode = false);
                    },
                    child: const Text('취소'),
                  ),
                ],
              ),
            ),

          // Input
          if (hasApiKey)
            Container(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + MediaQuery.of(context).viewPadding.bottom),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Voice mode toggle button
                  IconButton(
                    onPressed: _isLoading ? null : _toggleVoiceMode,
                    icon: Icon(
                      _voiceMode ? Icons.mic : Icons.mic_none,
                      color: _voiceMode ? AppColors.error : null,
                    ),
                    tooltip: _voiceMode ? '음성 모드 끄기' : '음성 모드 켜기',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _toggleVoiceMode() async {
    if (_voiceMode) {
      // Turn off voice mode
      _stopListening();
      setState(() => _voiceMode = false);
    } else {
      // Turn on voice mode and start listening
      await _ensureSpeechReady();
      setState(() => _voiceMode = true);
      _startListening();
    }
  }

  void _startListening() async {
    if (!_voiceMode) return;
    // Stop TTS if speaking
    await _tts.stop();

    setState(() {
      _isListening = true;
      _currentWords = '';
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _currentWords = result.recognizedWords;
        });
        if (result.finalResult) {
          setState(() => _isListening = false);
          if (_currentWords.isNotEmpty) {
            _messageController.text = _currentWords;
            _sendMessage(isVoice: true);
            _currentWords = '';
          }
        }
      },
      localeId: 'ko_KR',
      listenMode: stt.ListenMode.dictation,
      cancelOnError: true,
      listenFor: const Duration(seconds: 30),
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _currentWords = '';
    });
  }

  Widget _buildMessage(_ChatMessage msg) {
    if (msg.isSystemMessage) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.build_circle_outlined, size: 14, color: AppColors.grey500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.grey600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? Radius.zero : null,
            bottomLeft: !isUser ? Radius.zero : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && msg.emotion != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _emotionEmoji(msg.emotion!),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            Text(
              msg.text,
              style: TextStyle(
                color: isUser
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            // Show mic icon for voice messages
            if (isUser && msg.isVoice)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.mic,
                  size: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _emotionEmoji(String emotion) {
    switch (emotion) {
      case 'happy':
        return 'happy';
      case 'angry':
        return 'angry';
      case 'sad':
        return 'sad';
      case 'annoyed':
        return 'annoyed';
      case 'scolding':
        return 'scolding';
      case 'proud':
        return 'proud';
      case 'surprised':
        return 'surprised';
      case 'worried':
        return 'worried';
      case 'disappointed':
        return 'disappointed';
      default:
        return 'neutral';
    }
  }

  void _clearChat() {
    _stopListening();
    setState(() {
      _voiceMode = false;
      _messages.clear();
      _characterState = const CharacterState();
    });
    _gemini.resetChat();
  }

  Future<void> _openDressUp() async {
    final config = CharacterRegistry.getById(
        widget.settingsService.selectedCharacter);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DressUpScreen(
          config: config,
          accessoryService: widget.accessoryService,
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() {}); // Refresh to show new skins
    }
  }

  void _addLunaMessage(String text, {String emotion = 'happy', String gesture = 'idle'}) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false, emotion: emotion));
      _characterState = CharacterState(
        emotion: emotion,
        gesture: gesture,
      );
    });
    if (widget.settingsService.ttsEnabled) {
      _tts.speak(text);
    }
    _scrollToBottom();
    // Auto-restart listening if voice mode is on
    if (_voiceMode && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_voiceMode && mounted && !_isListening) {
          _startListening();
        }
      });
    }
  }

  String _describeAction(ToolAction action) {
    switch (action.name) {
      case 'list_routines':
        return '루틴 목록을 조회했어요';
      case 'create_routine':
        return '루틴을 생성했어요: ${action.args['name'] ?? ''}';
      case 'update_routine':
        return '루틴을 수정했어요';
      case 'delete_routine':
        final deletedName = action.result['deleted_name'];
        return deletedName != null ? '루틴을 삭제했어요: $deletedName' : '루틴을 삭제했어요';
      case 'mark_complete':
        return '완료 처리했어요';
      case 'mark_skipped':
        return '미완료 처리했어요';
      case 'get_completion_rate':
        final pct = action.result['percentage'];
        return pct != null ? '완료율: $pct' : '완료율을 조회했어요';
      case 'list_todos':
        return '할 일 목록을 조회했어요';
      case 'create_todo':
        return '할 일을 추가했어요: ${action.args['title'] ?? ''}';
      case 'complete_todo':
        return '할 일 완료 처리했어요';
      case 'delete_todo':
        final title = action.result['deleted_title'];
        return title != null ? '할 일을 삭제했어요: $title' : '할 일을 삭제했어요';
      case 'list_memos':
        return '메모 목록을 조회했어요';
      case 'create_memo':
        return '메모를 작성했어요: ${action.args['title'] ?? ''}';
      case 'update_memo':
        return '메모를 수정했어요';
      case 'delete_memo':
        final title = action.result['deleted_title'];
        return title != null ? '메모를 삭제했어요: $title' : '메모를 삭제했어요';
      case 'list_alarms':
        return '알람 목록을 조회했어요';
      case 'create_alarm':
        return '알람을 생성했어요: ${action.args['label'] ?? ''}';
      case 'delete_alarm':
        final label = action.result['deleted_label'];
        return label != null ? '알람을 삭제했어요: $label' : '알람을 삭제했어요';
      case 'toggle_alarm':
        final enabled = action.result['is_enabled'];
        return enabled == true ? '알람을 켰어요' : '알람을 껐어요';
      case 'list_events':
        return '일정을 조회했어요';
      case 'create_event':
        return '일정을 추가했어요: ${action.args['title'] ?? ''}';
      case 'delete_event':
        final evTitle = action.result['deleted_title'];
        return evTitle != null ? '일정을 삭제했어요: $evTitle' : '일정을 삭제했어요';
      case 'get_settings':
        return '현재 설정을 조회했어요';
      case 'set_voice':
        final vLabel = action.result['label'];
        return vLabel != null ? '목소리를 변경했어요: $vLabel' : '목소리를 변경했어요';
      case 'set_tts_enabled':
        final ttsOn = action.result['tts_enabled'];
        return ttsOn == true ? '음성 출력을 켰어요' : '음성 출력을 껐어요';
      case 'set_nag_frequency':
        return '잔소리 빈도를 변경했어요: ${action.result['nag_frequency_seconds']}초';
      case 'set_nag_intensity':
        return '잔소리 강도를 변경했어요: ${action.result['label'] ?? ''}';
      case 'set_overlay_enabled':
        final ovOn = action.result['overlay_enabled'];
        return ovOn == true ? '오버레이를 켰어요' : '오버레이를 껐어요';
      case 'set_app_lock_enabled':
        final lockOn = action.result['app_lock_enabled'];
        return lockOn == true ? '앱 잠금을 켰어요' : '앱 잠금을 껐어요';
      case 'set_overlay_character_visible':
        final charVis = action.result['overlay_character_visible'];
        return charVis == true ? '캐릭터 표시를 켰어요' : '캐릭터를 숨기고 목소리만 나와요';
      case 'set_character_name':
        return '캐릭터 이름을 변경했어요: ${action.result['character_name'] ?? ''}';
      case 'set_routine_check_interval':
        return '루틴 확인 간격을 변경했어요';
      case 'open_url':
        return '${action.result['url'] ?? '웹사이트'}를 열었어요';
      case 'play_music':
        return '${action.result['query'] ?? '음악'}을(를) 재생했어요';
      default:
        return '${action.name} 실행';
    }
  }

  static const _dataChangingActions = {
    'create_routine', 'update_routine', 'delete_routine',
    'mark_complete', 'mark_skipped',
    'create_todo', 'complete_todo', 'delete_todo',
    'create_memo', 'update_memo', 'delete_memo',
    'create_alarm', 'delete_alarm', 'toggle_alarm',
    'create_event', 'delete_event',
    'set_voice', 'set_tts_enabled', 'set_nag_frequency', 'set_nag_intensity',
    'set_overlay_enabled', 'set_app_lock_enabled', 'set_overlay_character_visible',
    'set_character_name',
    'set_routine_check_interval',
  };

  Future<void> _sendMessage({bool isVoice = false}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _messageController.clear();
    setState(() {
      _messages
          .add(_ChatMessage(text: text, isUser: true, isVoice: isVoice));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      if (!_gemini.isAgentInitialized) _initGemini();
      final prevModel = _gemini.currentAgentModel;
      final result = await _gemini.chatWithTools(text);

      // Show model switch notification
      if (_gemini.currentAgentModel != prevModel) {
        setState(() {
          _messages.add(_ChatMessage(
            text: '모델 전환: ${_gemini.currentAgentModel} (할당량 초과)',
            isUser: false,
            isSystemMessage: true,
          ));
        });
      }

      // Show tool actions as system messages
      for (final action in result.actions) {
        setState(() {
          _messages.add(_ChatMessage(
            text: _describeAction(action),
            isUser: false,
            isSystemMessage: true,
          ));
        });
      }

      // Notify home screen if routines changed
      if (result.actions.any((a) => _dataChangingActions.contains(a.name))) {
        widget.onRoutinesChanged?.call();
      }

      setState(() {
        _messages.add(_ChatMessage(
          text: result.response.text,
          isUser: false,
          emotion: result.response.emotion,
        ));
        _characterState = CharacterState(
          emotion: result.response.emotion,
          gesture: result.response.gesture,
        );
      });

      if (widget.settingsService.ttsEnabled) {
        await _tts.speak(result.response.text);
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: '앗, 오류가 발생했어... ($e)',
          isUser: false,
          emotion: 'sad',
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
      // Auto-restart listening if voice mode is on
      if (_voiceMode && mounted) {
        // Small delay to let TTS finish and avoid overlap
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_voiceMode && mounted && !_isListening) {
            _startListening();
          }
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final String? emotion;
  final bool isVoice;
  final bool isSystemMessage;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.emotion,
    this.isVoice = false,
    this.isSystemMessage = false,
  });
}
