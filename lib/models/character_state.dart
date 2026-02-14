/// Represents the AI character's current emotional and gestural state.
class CharacterState {
  final String emotion;
  final String gesture;
  final String text;
  final String? characterId;

  const CharacterState({
    this.emotion = 'neutral',
    this.gesture = 'idle',
    this.text = '',
    this.characterId,
  });

  factory CharacterState.fromJson(Map<String, dynamic> json) => CharacterState(
        emotion: json['emotion'] ?? 'neutral',
        gesture: json['gesture'] ?? 'idle',
        text: json['text'] ?? '',
        characterId: json['characterId'],
      );

  Map<String, dynamic> toJson() => {
        'emotion': emotion,
        'gesture': gesture,
        'text': text,
        if (characterId != null) 'characterId': characterId,
      };

  /// Available emotions for the character
  static const List<String> emotions = [
    'neutral',
    'happy',
    'angry',
    'sad',
    'surprised',
    'annoyed',
    'disappointed',
    'scolding',
    'proud',
    'worried',
  ];

  /// Available gestures for the character
  static const List<String> gestures = [
    'idle',
    'arms_crossed',
    'pointing',
    'shaking_head',
    'waving',
    'crawling_in',
    'thumbs_up',
    'clapping',
    'facepalm',
    'beckoning',
  ];
}
