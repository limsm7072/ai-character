import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/character_state.dart';
import '../models/character_registry.dart';
import '../models/routine.dart' as model;
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/accessory_service.dart';
import '../services/routine_service.dart';
import '../services/routine_completion_service.dart';
import '../widgets/spine_character_widget.dart';
import 'dress_up_screen.dart';

enum _RoutineStep { idle, askName, askStartDate, askStartTime, askEndTime, askDays, askBlockedApps }

class _RoutineCreationFlow {
  _RoutineStep step = _RoutineStep.idle;
  String name = '';
  String? startDate;
  model.TimeOfDay? startTime;
  model.TimeOfDay? endTime;
  List<bool> activeDays = List.filled(7, true);
  List<String> blockedApps = [];

  bool get isActive => step != _RoutineStep.idle;

  void reset() {
    step = _RoutineStep.idle;
    name = '';
    startDate = null;
    startTime = null;
    endTime = null;
    activeDays = List.filled(7, true);
    blockedApps = [];
  }
}

model.TimeOfDay? _parseTime(String input) {
  final t = input.replaceAll(RegExp(r'\s+'), '');

  // "HH:MM" or "HH시MM분"
  final colonMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(input);
  if (colonMatch != null) {
    return model.TimeOfDay(
      hour: int.parse(colonMatch.group(1)!),
      minute: int.parse(colonMatch.group(2)!),
    );
  }

  bool isPm = input.contains('오후') || input.contains('저녁') || input.contains('밤');
  bool isAm = input.contains('오전') || input.contains('아침') || input.contains('새벽');

  final hourMatch = RegExp(r'(\d{1,2})\s*시').firstMatch(input);
  final minuteMatch = RegExp(r'(\d{1,2})\s*분').firstMatch(input);

  if (hourMatch != null) {
    var hour = int.parse(hourMatch.group(1)!);
    final minute = minuteMatch != null ? int.parse(minuteMatch.group(1)!) : 0;

    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;

    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return model.TimeOfDay(hour: hour, minute: minute);
    }
  }

  // bare number like "6" or "18"
  final bareMatch = RegExp(r'^[오후오전아침저녁밤새벽\s]*(\d{1,2})$').firstMatch(input.trim());
  if (bareMatch != null) {
    var hour = int.parse(bareMatch.group(1)!);
    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;
    if (hour >= 0 && hour <= 23) {
      return model.TimeOfDay(hour: hour, minute: 0);
    }
  }

  return null;
}

String? _parseDate(String input) {
  final t = input.trim();
  final now = DateTime.now();
  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  if (t.contains('오늘') || t.contains('지금') || t.contains('바로')) {
    return _fmt(now);
  }
  if (t.contains('내일')) {
    return _fmt(now.add(const Duration(days: 1)));
  }
  if (t.contains('모레') || t.contains('글피')) {
    return _fmt(now.add(Duration(days: t.contains('글피') ? 3 : 2)));
  }

  // "2월 20일", "2/20", "02-20"
  final mdMatch = RegExp(r'(\d{1,2})\s*[월/\-]\s*(\d{1,2})').firstMatch(t);
  if (mdMatch != null) {
    final month = int.parse(mdMatch.group(1)!);
    final day = int.parse(mdMatch.group(2)!);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      var year = now.year;
      final candidate = DateTime(year, month, day);
      if (candidate.isBefore(now.subtract(const Duration(days: 1)))) {
        year++;
      }
      return _fmt(DateTime(year, month, day));
    }
  }

  // "20일" (current month)
  final dayOnly = RegExp(r'(\d{1,2})\s*일').firstMatch(t);
  if (dayOnly != null) {
    final day = int.parse(dayOnly.group(1)!);
    if (day >= 1 && day <= 31) {
      var month = now.month;
      var year = now.year;
      if (day < now.day) {
        month++;
        if (month > 12) { month = 1; year++; }
      }
      return _fmt(DateTime(year, month, day));
    }
  }

  return null;
}

List<bool>? _parseDays(String input) {
  final t = input.trim();
  if (t.contains('매일') || t.contains('전부') || t.contains('모두')) {
    return List.filled(7, true);
  }
  if (t.contains('평일')) {
    return [true, true, true, true, true, false, false];
  }
  if (t.contains('주말')) {
    return [false, false, false, false, false, true, true];
  }

  final dayMap = {'월': 0, '화': 1, '수': 2, '목': 3, '금': 4, '토': 5, '일': 6};
  final result = List.filled(7, false);
  bool found = false;
  for (final entry in dayMap.entries) {
    if (t.contains(entry.key)) {
      result[entry.value] = true;
      found = true;
    }
  }
  return found ? result : null;
}

class CharacterChatScreen extends StatefulWidget {
  final SettingsService settingsService;
  final AccessoryService accessoryService;
  final RoutineService? routineService;
  final RoutineCompletionService? completionService;

  const CharacterChatScreen({
    super.key,
    required this.settingsService,
    required this.accessoryService,
    this.routineService,
    this.completionService,
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
  final _routineFlow = _RoutineCreationFlow();

  @override
  void initState() {
    super.initState();
    _initGemini();
    // _initSpeech is called lazily in _ensureSpeechReady()
    // to avoid conflicting with HomeScreen's wake word SpeechToText
  }

  void _initGemini() {
    final apiKey = widget.settingsService.apiKey;
    if (apiKey.isNotEmpty) {
      _gemini.initialize(apiKey);
      _gemini.setAppContext(_buildAppContext());
    }
  }

  String _buildAppContext() {
    final routineService = widget.routineService;
    final completionService = widget.completionService;
    if (routineService == null || completionService == null) return '';

    final today = DateTime.now();
    final todayStr = completionService.todayStr();
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final dayIndex = today.weekday - 1;
    final routines = routineService.getAll();

    if (routines.isEmpty) return '등록된 루틴 없음';

    final buf = StringBuffer();
    buf.writeln('오늘: ${today.month}/${today.day} (${dayNames[dayIndex]})');
    buf.writeln('루틴 목록:');
    for (final r in routines) {
      if (!r.activeDays[dayIndex]) continue;
      final completed = completionService.isCompleted(r.id, todayStr);
      final skipped = completionService.isSkipped(r.id, todayStr);
      final status = completed ? '완료' : skipped ? '미완료' : '아직';
      buf.writeln('- ${r.name} (${r.startTime.format()}-${r.endTime.format()}) [$status]');
    }
    return buf.toString();
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
        title: const Text('루나와 대화'),
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
          // Spine 2D Character display
          SizedBox(
            height: 250,
            child: Builder(builder: (_) {
              final config = CharacterRegistry.getById(
                  widget.settingsService.selectedCharacter);
              final customSkins = widget.accessoryService
                  .getSelectedSkins(config.id);
              return SpineCharacterWidget(
                key: ValueKey('${config.id}_${customSkins.join("_")}'),
                config: config,
                state: _characterState,
                customSkins: customSkins.isNotEmpty ? customSkins : null,
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
                          Icon(Icons.key, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Gemini API 키를 설정해주세요',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '설정 탭에서 API 키를 입력하면\n루나와 대화할 수 있어요',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500]),
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
                              '루나에게 말을 걸어보세요!',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                            if (_speechAvailable) ...[
                              const SizedBox(height: 8),
                              Text(
                                '마이크 버튼을 눌러 음성으로도 대화할 수 있어요',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
              color: Colors.red.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentWords.isEmpty ? '듣고 있어요...' : _currentWords,
                      style: TextStyle(
                        color: _currentWords.isEmpty
                            ? Colors.grey[600]
                            : Colors.black87,
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Voice mode toggle button
                  if (_speechAvailable)
                    IconButton(
                      onPressed: _isLoading ? null : _toggleVoiceMode,
                      icon: Icon(
                        _voiceMode ? Icons.mic : Icons.mic_none,
                        color: _voiceMode ? Colors.red : null,
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
      _routineFlow.reset();
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

  static const _routineKeywords = [
    '루틴 추가', '루틴 만들', '루틴 생성', '루틴 등록',
    '루틴 넣어', '루틴 잡아', '루틴 세워',
    '추가해줘', '만들어줘', '등록해줘',
  ];

  bool _isRoutineCreationIntent(String text) {
    final t = text.toLowerCase().replaceAll(' ', '');
    return _routineKeywords.any((k) => t.contains(k.replaceAll(' ', '')));
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

  Future<void> _handleRoutineFlow(String text) async {
    switch (_routineFlow.step) {
      case _RoutineStep.askName:
        _routineFlow.name = text;
        _routineFlow.step = _RoutineStep.askStartDate;
        _addLunaMessage('좋아! "${_routineFlow.name}" 루틴이구나. 언제부터 시작할 거야? (예: 오늘, 내일, 2월 20일)', emotion: 'happy', gesture: 'idle');
        break;

      case _RoutineStep.askStartDate:
        final date = _parseDate(text);
        if (date == null) {
          _addLunaMessage('날짜를 못 알아들었어. "오늘", "내일", "2월 20일" 이런 식으로 말해줘!', emotion: 'worried', gesture: 'shaking_head');
          return;
        }
        _routineFlow.startDate = date;
        _routineFlow.step = _RoutineStep.askStartTime;
        _addLunaMessage('$date부터 시작이구나! 매일 시작 시간은 몇 시야?', emotion: 'happy', gesture: 'idle');
        break;

      case _RoutineStep.askStartTime:
        final time = _parseTime(text);
        if (time == null) {
          _addLunaMessage('음... 시간을 못 알아들었어. "오후 6시"나 "18:00" 이런 식으로 말해줘!', emotion: 'worried', gesture: 'shaking_head');
          return;
        }
        _routineFlow.startTime = time;
        _routineFlow.step = _RoutineStep.askEndTime;
        _addLunaMessage('시작 시간 ${time.format()}! 끝나는 시간은?', emotion: 'happy', gesture: 'idle');
        break;

      case _RoutineStep.askEndTime:
        final time = _parseTime(text);
        if (time == null) {
          _addLunaMessage('음... 시간을 못 알아들었어. "오후 7시"나 "19:00" 이런 식으로 말해줘!', emotion: 'worried', gesture: 'shaking_head');
          return;
        }
        _routineFlow.endTime = time;
        _routineFlow.step = _RoutineStep.askDays;
        _addLunaMessage('${time.format()}까지! 무슨 요일에 할 거야? (매일, 평일, 주말, 또는 월수금 이런 식으로)', emotion: 'happy', gesture: 'idle');
        break;

      case _RoutineStep.askDays:
        final days = _parseDays(text);
        if (days == null) {
          _addLunaMessage('요일을 못 알아들었어. "매일", "평일", "월수금" 이런 식으로 말해줘!', emotion: 'worried', gesture: 'shaking_head');
          return;
        }
        _routineFlow.activeDays = days;
        _routineFlow.step = _RoutineStep.askBlockedApps;
        _addLunaMessage('루틴 시간에 차단할 앱이 있어? 앱 이름을 말해줘! (예: 유튜브, 인스타)\n없으면 "없어" 라고 해~', emotion: 'happy', gesture: 'idle');
        break;

      case _RoutineStep.askBlockedApps:
        final t = text.trim();
        if (t.contains('없') || t.contains('패스') || t.contains('스킵') || t.contains('안') || t.isEmpty) {
          _routineFlow.blockedApps = [];
        } else {
          _routineFlow.blockedApps = t
              .split(RegExp(r'[,\s、]+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
        await _createRoutineFromFlow();
        break;

      default:
        break;
    }
  }

  Future<void> _createRoutineFromFlow() async {
    final flow = _routineFlow;
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
    final activeDayStr = <String>[];
    for (int i = 0; i < 7; i++) {
      if (flow.activeDays[i]) activeDayStr.add(dayNames[i]);
    }
    final daysLabel = activeDayStr.length == 7 ? '매일' : activeDayStr.join('');

    final routine = model.Routine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: flow.name,
      startDate: flow.startDate,
      startTime: flow.startTime!,
      endTime: flow.endTime!,
      activeDays: flow.activeDays,
      blockedApps: flow.blockedApps,
    );

    try {
      await widget.routineService!.add(routine);
      final appsLabel = flow.blockedApps.isNotEmpty
          ? '\n차단 앱: ${flow.blockedApps.join(", ")}'
          : '';
      final dateLabel = flow.startDate != null ? '${flow.startDate}부터, ' : '';
      _addLunaMessage(
        '${flow.name} 루틴 만들었어! $dateLabel${flow.startTime!.format()}~${flow.endTime!.format()}, $daysLabel.$appsLabel\n화이팅!',
        emotion: 'proud',
        gesture: 'clapping',
      );
    } catch (e) {
      _addLunaMessage('앗, 루틴 만들다가 오류가 났어... ($e)', emotion: 'sad', gesture: 'facepalm');
    } finally {
      flow.reset();
    }
  }

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
      // Check if in routine creation flow
      if (_routineFlow.isActive) {
        await _handleRoutineFlow(text);
        return; // finally block handles isLoading & voice restart
      }

      // Check if user wants to create a routine
      if (_isRoutineCreationIntent(text) && widget.routineService != null) {
        _routineFlow.step = _RoutineStep.askName;
        _addLunaMessage('좋아! 새 루틴 만들어줄게. 루틴 이름은 뭐로 할까?', emotion: 'happy', gesture: 'waving');
        return; // finally block handles isLoading & voice restart
      }

      // Normal chat
      if (!_gemini.isInitialized) _initGemini();
      final response = await _gemini.chat(text);

      setState(() {
        _messages.add(_ChatMessage(
          text: response.text,
          isUser: false,
          emotion: response.emotion,
        ));
        _characterState = CharacterState(
          emotion: response.emotion,
          gesture: response.gesture,
        );
      });

      if (widget.settingsService.ttsEnabled) {
        await _tts.speak(response.text);
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

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.emotion,
    this.isVoice = false,
  });
}
