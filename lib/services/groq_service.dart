import 'dart:convert';
import 'dart:io';
import '../models/ai_response.dart';
import 'agent_tools.dart';
import 'gemini_service.dart' show AgentChatResult;

/// Groq API 서비스 (OpenAI-compatible REST API)
/// Gemini quota 소진 시 fallback으로 사용
class GroqRateLimit {
  final int remainingRequests;
  final int remainingTokens;
  final int limitRequests;
  final int limitTokens;
  final DateTime updatedAt;

  GroqRateLimit({
    required this.remainingRequests,
    required this.remainingTokens,
    required this.limitRequests,
    required this.limitTokens,
    required this.updatedAt,
  });
}

class GroqService {
  String _apiKey;

  static const _baseUrl = 'api.groq.com';
  static const _path = '/openai/v1/chat/completions';

  // 모델별 rate limit이 별도 → 여러 모델 = 더 많은 총 용량
  // 70b: 12K TPM, 8b: 6K TPM, gemma2: 6K TPM = 합계 24K TPM
  static const _models = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
    'gemma2-9b-it',
  ];

  int _modelIndex = 0;

  String get currentModel => _models[_modelIndex];
  List<String> get models => List.unmodifiable(_models);

  // Rate limit 추적 (모델별)
  final Map<String, GroqRateLimit> _rateLimits = {};
  Map<String, GroqRateLimit> get rateLimits => Map.unmodifiable(_rateLimits);

  GroqService(this._apiKey);

  void updateApiKey(String key) {
    _apiKey = key;
    _modelIndex = 0;
  }

  bool _isQuotaError(int statusCode, String body) {
    if (statusCode == 429) return true;
    final lower = body.toLowerCase();
    return lower.contains('rate_limit') ||
        lower.contains('quota') ||
        lower.contains('resource_exhausted') ||
        lower.contains('too many requests');
  }

  bool _fallbackModel() {
    if (_modelIndex < _models.length - 1) {
      _modelIndex++;
      print('[GroqService] Switching to model: ${_models[_modelIndex]}');
      return true;
    }
    return false;
  }

  void _resetModelIndex() {
    _modelIndex = 0;
  }

  /// 일반 채팅 (function calling 없이)
  Future<AiResponse> chat(String systemPrompt, String userMessage) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ];

    _resetModelIndex();
    for (int attempt = 0; attempt <= _models.length; attempt++) {
      try {
        final body = await _callApi(messages: messages);
        final text = _extractText(body);
        return AiResponse.parse(text);
      } catch (e) {
        if (e is GroqQuotaException) {
          if (_fallbackModel()) continue;
          // 모든 모델 실패 → 대기 후 첫 모델로 재시도
          if (attempt == _models.length - 1) {
            print('[GroqService] All models rate limited, waiting 15s...');
            await Future.delayed(const Duration(seconds: 15));
            _resetModelIndex();
            try {
              final body = await _callApi(messages: messages);
              return AiResponse.parse(_extractText(body));
            } catch (_) {
              rethrow;
            }
          }
        }
        rethrow;
      }
    }
    throw Exception('[GroqService] All models quota exceeded');
  }

  /// 채팅 히스토리 기반 채팅
  Future<AiResponse> chatWithHistory(String systemPrompt, List<Map<String, dynamic>> history, String userMessage) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    _resetModelIndex();
    for (int attempt = 0; attempt <= _models.length; attempt++) {
      try {
        final body = await _callApi(messages: messages);
        final text = _extractText(body);
        return AiResponse.parse(text);
      } catch (e) {
        if (e is GroqQuotaException && _fallbackModel()) continue;
        rethrow;
      }
    }
    throw Exception('[GroqService] All models quota exceeded');
  }

  /// Function calling 지원 채팅
  Future<AgentChatResult> chatWithTools({
    required String systemPrompt,
    required String userMessage,
    required List<Map<String, dynamic>> openAiTools,
    required AgentTools agentTools,
  }) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ];

    _resetModelIndex();
    for (int attempt = 0; attempt <= _models.length; attempt++) {
      try {
        return await _chatWithToolsInternal(messages, openAiTools, agentTools);
      } catch (e) {
        if (e is GroqQuotaException) {
          if (_fallbackModel()) continue;
          // 모든 모델 실패 → 대기 후 첫 모델로 재시도
          print('[GroqService] All models rate limited, waiting 15s...');
          await Future.delayed(const Duration(seconds: 15));
          _resetModelIndex();
          try {
            return await _chatWithToolsInternal(messages, openAiTools, agentTools);
          } catch (_) {
            rethrow;
          }
        }
        rethrow;
      }
    }
    throw Exception('[GroqService] All models quota exceeded');
  }

  Future<AgentChatResult> _chatWithToolsInternal(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
    AgentTools agentTools,
  ) async {
    final actions = <ToolAction>[];
    int iterations = 0;

    while (iterations < 5) {
      iterations++;
      final body = await _callApi(messages: messages, tools: tools);
      final choice = (body['choices'] as List).first;
      final message = choice['message'] as Map<String, dynamic>;
      final finishReason = choice['finish_reason'] as String?;

      // tool_calls 확인
      final toolCalls = message['tool_calls'] as List?;
      if (toolCalls == null || toolCalls.isEmpty || finishReason != 'tool_calls') {
        // 최종 응답
        final text = message['content'] as String? ?? '';
        return AgentChatResult(
          response: AiResponse.parse(text),
          actions: actions,
        );
      }

      // assistant 메시지를 히스토리에 추가
      messages.add(message);

      // 각 tool call 실행
      for (final tc in toolCalls) {
        final function = tc['function'] as Map<String, dynamic>;
        final name = function['name'] as String;
        final argsStr = function['arguments'] as String;
        final args = jsonDecode(argsStr) as Map<String, dynamic>;
        final toolCallId = tc['id'] as String;

        // AgentTools.execute 호출을 위해 FunctionCall과 유사한 형태로 변환
        final result = await agentTools.executeRaw(name, args);
        actions.add(ToolAction(name: name, args: args, result: result));

        // tool 결과를 히스토리에 추가
        messages.add({
          'role': 'tool',
          'tool_call_id': toolCallId,
          'content': jsonEncode(result),
        });
      }
    }

    // 5회 반복 후에도 tool_calls → 강제 종료
    throw Exception('[GroqService] Too many tool call iterations');
  }

  /// Standalone 호출 (채팅 기록 없이 단건)
  Future<String?> generateStandalone(String prompt) async {
    final messages = [
      {'role': 'user', 'content': prompt},
    ];

    for (int i = 0; i < _models.length; i++) {
      try {
        final body = await _callApi(messages: messages, model: _models[i]);
        return _extractText(body);
      } catch (e) {
        if (e is GroqQuotaException && i < _models.length - 1) {
          print('[GroqService] Standalone quota exceeded on ${_models[i]}');
          continue;
        }
        print('[GroqService] Standalone error: $e');
        return null;
      }
    }
    return null;
  }

  /// Standalone AiResponse (잔소리/격려/칭찬용)
  Future<AiResponse> generateStandaloneAiResponse(String prompt) async {
    final messages = [
      {'role': 'user', 'content': prompt},
    ];

    for (int i = 0; i < _models.length; i++) {
      try {
        final body = await _callApi(messages: messages, model: _models[i]);
        final text = _extractText(body);
        return AiResponse.parse(text);
      } catch (e) {
        if (e is GroqQuotaException && i < _models.length - 1) continue;
        rethrow;
      }
    }
    throw Exception('[GroqService] All models quota exceeded');
  }

  // ─── Internal ─────────────────────────────────────────

  Future<Map<String, dynamic>> _callApi({
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    String? model,
  }) async {
    final client = HttpClient();
    try {
      final requestBody = <String, dynamic>{
        'model': model ?? _models[_modelIndex],
        'messages': messages,
        'temperature': 0.85,
        'max_tokens': 400,
      };

      if (tools != null && tools.isNotEmpty) {
        requestBody['tools'] = tools;
        requestBody['tool_choice'] = 'auto';
      }

      final request = await client.postUrl(Uri.https(_baseUrl, _path));
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.add(utf8.encode(jsonEncode(requestBody)));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      // Rate limit 헤더 추적
      final modelUsed = model ?? _models[_modelIndex];
      _updateRateLimits(modelUsed, response.headers);

      if (response.statusCode == 429 || _isQuotaError(response.statusCode, responseBody)) {
        throw GroqQuotaException('Rate limit exceeded (${response.statusCode})');
      }

      if (response.statusCode != 200) {
        throw Exception('[GroqService] API error ${response.statusCode}: $responseBody');
      }

      return jsonDecode(responseBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  void _updateRateLimits(String model, HttpHeaders headers) {
    try {
      final remReq = int.tryParse(headers.value('x-ratelimit-remaining-requests') ?? '') ?? -1;
      final remTok = int.tryParse(headers.value('x-ratelimit-remaining-tokens') ?? '') ?? -1;
      final limReq = int.tryParse(headers.value('x-ratelimit-limit-requests') ?? '') ?? -1;
      final limTok = int.tryParse(headers.value('x-ratelimit-limit-tokens') ?? '') ?? -1;
      if (remReq >= 0 || remTok >= 0) {
        _rateLimits[model] = GroqRateLimit(
          remainingRequests: remReq,
          remainingTokens: remTok,
          limitRequests: limReq,
          limitTokens: limTok,
          updatedAt: DateTime.now(),
        );
      }
    } catch (_) {}
  }

  String _extractText(Map<String, dynamic> body) {
    final choices = body['choices'] as List;
    if (choices.isEmpty) return '';
    final message = choices[0]['message'] as Map<String, dynamic>;
    return message['content'] as String? ?? '';
  }
}

class GroqQuotaException implements Exception {
  final String message;
  GroqQuotaException(this.message);
  @override
  String toString() => 'GroqQuotaException: $message';
}
