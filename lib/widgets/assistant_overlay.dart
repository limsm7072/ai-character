import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/character_state.dart';
import '../models/character_registry.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/accessory_service.dart';
import '../widgets/spine_character_widget.dart';

class AssistantOverlay extends StatefulWidget {
  final SettingsService settingsService;
  final AccessoryService accessoryService;
  final String? initialCommand;

  const AssistantOverlay({
    super.key,
    required this.settingsService,
    required this.accessoryService,
    this.initialCommand,
  });

  @override
  State<AssistantOverlay> createState() => _AssistantOverlayState();
}

class _AssistantOverlayState extends State<AssistantOverlay> {
  final _gemini = GeminiService();
  final _tts = TtsService();
  final _speech = stt.SpeechToText();
  final _messages = <_AssistantMessage>[];
  final _scrollController = ScrollController();

  CharacterState _characterState = const CharacterState(emotion: 'happy');
  bool _isListening = false;
  bool _isLoading = false;
  bool _speechAvailable = false;
  String _currentWords = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final apiKey = widget.settingsService.apiKey;
    if (apiKey.isNotEmpty) {
      _gemini.initialize(apiKey);
    }

    // Apply voice preset
    await _tts.applyPreset(widget.settingsService.voicePreset);

    _speechAvailable = await _speech.initialize(
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && _isListening) {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );

    // Greeting
    setState(() {
      _messages.add(_AssistantMessage(
        text: '무엇을 도와드릴까요?',
        isUser: false,
        emotion: 'happy',
      ));
    });

    if (widget.settingsService.ttsEnabled) {
      await _tts.speak('무엇을 도와드릴까요?');
    }

    // Process initial command or start listening
    if (widget.initialCommand != null && widget.initialCommand!.isNotEmpty) {
      _processCommand(widget.initialCommand!);
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tts.dispose();
    _speech.stop();
    super.dispose();
  }

  void _startListening() async {
    if (!_speechAvailable || !mounted) return;
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
        if (result.finalResult && _currentWords.isNotEmpty) {
          setState(() => _isListening = false);
          _processCommand(_currentWords);
          _currentWords = '';
        }
      },
      localeId: 'ko_KR',
      listenMode: stt.ListenMode.dictation,
      cancelOnError: true,
      listenFor: const Duration(seconds: 15),
    );
  }

  Future<void> _processCommand(String text) async {
    if (_isExitCommand(text)) {
      _dismiss();
      return;
    }

    setState(() {
      _messages.add(_AssistantMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await _gemini.assistantChat(text);

      setState(() {
        _messages.add(_AssistantMessage(
          text: response.text,
          isUser: false,
          emotion: response.emotion,
        ));
        _characterState = CharacterState(emotion: response.emotion);
        _isLoading = false;
      });
      _scrollToBottom();

      if (widget.settingsService.ttsEnabled) {
        await _tts.speak(response.text);
      }

      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _startListening();
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(_AssistantMessage(
          text: '앗, 오류가 났어... ($e)',
          isUser: false,
          emotion: 'sad',
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _startListening();
        });
      }
    }
  }

  bool _isExitCommand(String text) {
    final t = text.replaceAll(' ', '');
    return t == '그만' || t == '종료' || t == '끝' || t == '닫아' || t == '닫아줘';
  }

  void _dismiss() {
    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final config = CharacterRegistry.getById(
        widget.settingsService.selectedCharacter);
    final customSkins =
        widget.accessoryService.getSelectedSkins(config.id);

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '비서 모드',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Character
            SizedBox(
              height: 200,
              child: SpineCharacterWidget(
                key: ValueKey('assistant_${config.id}'),
                config: config,
                state: _characterState,
                customSkins: customSkins.isNotEmpty ? customSkins : null,
                showBubble: false,
                interactive: false,
              ),
            ),

            // Messages
            Expanded(
              child: _messages.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildMessage(_messages[i]),
                    ),
            ),

            // Loading
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),

            // Listening indicator
            if (_isListening)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _currentWords.isEmpty
                            ? '듣고 있어요...'
                            : _currentWords,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontStyle: _currentWords.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Hint
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '"그만" 또는 "종료"로 닫기',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(_AssistantMessage msg) {
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
              ? Colors.blueAccent
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? Radius.zero : null,
            bottomLeft: !isUser ? Radius.zero : null,
          ),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _AssistantMessage {
  final String text;
  final bool isUser;
  final String? emotion;

  _AssistantMessage({required this.text, required this.isUser, this.emotion});
}
