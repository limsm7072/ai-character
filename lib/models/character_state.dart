/// Represents the AI character's current emotional and gestural state.
class CharacterState {
  final String emotion;
  final String gesture;
  final String text;
  final String? characterId;
  /// Optional action prompt (e.g., 'completion_check')
  final String? action;
  /// Routine ID associated with the action
  final String? actionRoutineId;

  const CharacterState({
    this.emotion = 'neutral',
    this.gesture = 'idle',
    this.text = '',
    this.characterId,
    this.action,
    this.actionRoutineId,
  });

  factory CharacterState.fromJson(Map<String, dynamic> json) => CharacterState(
        emotion: json['emotion'] ?? 'neutral',
        gesture: json['gesture'] ?? 'idle',
        text: json['text'] ?? '',
        characterId: json['characterId'],
        action: json['action'],
        actionRoutineId: json['actionRoutineId'],
      );

  Map<String, dynamic> toJson() => {
        'emotion': emotion,
        'gesture': gesture,
        'text': text,
        if (characterId != null) 'characterId': characterId,
        if (action != null) 'action': action,
        if (actionRoutineId != null) 'actionRoutineId': actionRoutineId,
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
