import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/character_state.dart';
import '../models/character_registry.dart';
import '../services/gemini_service.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/accessory_service.dart';
import '../widgets/spine_character_widget.dart';
import 'dress_up_screen.dart';

class CharacterChatScreen extends StatefulWidget {
  final SettingsService settingsService;
  final AccessoryService accessoryService;

  const CharacterChatScreen({
    super.key,
    required this.settingsService,
    required this.accessoryService,
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
  String _currentWords = '';

  @override
  void initState() {
    super.initState();
    _initGemini();
    _initSpeech();
  }

  void _initGemini() {
    final apiKey = widget.settingsService.apiKey;
    if (apiKey.isNotEmpty) {
      _gemini.initialize(apiKey);
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_isListening) {
            setState(() => _isListening = false);
            // Auto-send if we got words
            if (_currentWords.isNotEmpty) {
              _messageController.text = _currentWords;
              _sendMessage(isVoice: true);
              _currentWords = '';
            }
          }
        }
      },
    );
    setState(() {});
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
                    onPressed: _stopListening,
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
                  // Microphone button
                  if (_speechAvailable)
                    IconButton(
                      onPressed: _isLoading
                          ? null
                          : (_isListening ? _stopListening : _startListening),
                      icon: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: _isListening ? Colors.red : null,
                      ),
                      tooltip: _isListening ? '음성 입력 중지' : '음성으로 말하기',
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

  void _startListening() async {
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
          text: response.text,
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
