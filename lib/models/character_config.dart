/// Configuration for a Spine 2D character.
class CharacterConfig {
  final String id;
  final String displayName;
  final String atlasAsset;
  final String skelAsset;
  final Map<String, String> emotionAnimations;
  final Map<String, String> gestureAnimations;
  final Map<String, double> emotionAnimationSpeeds;
  final Map<String, double> gestureAnimationSpeeds;
  final Set<String> oneShotAnimations;
  final String idleAnimation;
  final String? defaultSkin;
  final List<String> combineSkins;
  final bool supportsLipSync;
  final bool supportsDressUp;
  final List<String> baseSkins;

  const CharacterConfig({
    required this.id,
    required this.displayName,
    required this.atlasAsset,
    required this.skelAsset,
    required this.emotionAnimations,
    required this.gestureAnimations,
    this.emotionAnimationSpeeds = const {},
    this.gestureAnimationSpeeds = const {},
    this.oneShotAnimations = const {},
    this.idleAnimation = 'idle',
    this.defaultSkin,
    this.combineSkins = const [],
    this.supportsLipSync = false,
    this.supportsDressUp = false,
    this.baseSkins = const [],
  });
}
