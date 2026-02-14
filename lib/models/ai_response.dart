import 'dart:convert';

/// Parsed response from Gemini AI
class AiResponse {
  final String text;
  final String emotion;
  final String gesture;

  const AiResponse({
    required this.text,
    this.emotion = 'neutral',
    this.gesture = 'idle',
  });

  factory AiResponse.fromJson(Map<String, dynamic> json) => AiResponse(
        text: json['text'] ?? '',
        emotion: json['emotion'] ?? 'neutral',
        gesture: json['gesture'] ?? 'idle',
      );

  /// Try to parse a JSON string from AI response.
  /// Falls back to plain text if parsing fails.
  factory AiResponse.parse(String raw) {
    try {
      // Try to extract JSON from the response
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(raw);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        return AiResponse.fromJson(json);
      }
    } catch (_) {}
    // Fallback: use raw text with default emotion/gesture
    return AiResponse(text: raw.trim());
  }
}
