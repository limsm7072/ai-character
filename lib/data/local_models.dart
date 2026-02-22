class LocalModel {
  final String id;
  final String name;
  final String nameKo;
  final String emoji;
  final String fileName; // e.g. "Fox.glb"
  final String source;
  final bool animated;
  final int price;
  final String category; // 'character' or 'deco'

  const LocalModel({
    required this.id,
    required this.name,
    required this.nameKo,
    required this.emoji,
    required this.fileName,
    required this.source,
    this.animated = false,
    required this.price,
    this.category = 'character',
  });

  /// URL for loading in native WebView via local assets
  String get viewerUrl =>
      'file:///android_asset/viewer.html#src=models/$fileName';
}

const localModels = [
  // ── 캐릭터 ──
  LocalModel(
    id: 'local_duck',
    name: 'Duck',
    nameKo: '오리',
    emoji: '🦆',
    fileName: 'Duck.glb',
    source: 'Khronos glTF Samples',
    price: 50,
  ),
  LocalModel(
    id: 'local_fox',
    name: 'Fox',
    nameKo: '여우',
    emoji: '🦊',
    fileName: 'Fox.glb',
    source: 'Khronos glTF Samples',
    animated: true,
    price: 100,
  ),
  LocalModel(
    id: 'local_horse',
    name: 'Horse',
    nameKo: '말',
    emoji: '🐴',
    fileName: 'Horse.glb',
    source: 'Google model-viewer',
    price: 80,
  ),
  LocalModel(
    id: 'local_cesiumman',
    name: 'CesiumMan',
    nameKo: '캐릭터',
    emoji: '🧑',
    fileName: 'CesiumMan.glb',
    source: 'Khronos glTF Samples',
    animated: true,
    price: 150,
  ),
  LocalModel(
    id: 'local_robot',
    name: 'RobotExpressive',
    nameKo: '로봇 친구',
    emoji: '🤖',
    fileName: 'RobotExpressive.glb',
    source: 'Google model-viewer',
    animated: true,
    price: 200,
  ),
  LocalModel(
    id: 'local_astronaut',
    name: 'Astronaut',
    nameKo: '우주비행사',
    emoji: '🧑‍🚀',
    fileName: 'Astronaut.glb',
    source: 'Google model-viewer',
    price: 200,
  ),
  LocalModel(
    id: 'local_brainstem',
    name: 'BrainStem',
    nameKo: '바이오 로봇',
    emoji: '🦾',
    fileName: 'BrainStem.glb',
    source: 'Khronos glTF Samples',
    animated: true,
    price: 300,
  ),

  // ── 방꾸미기 ──
  LocalModel(
    id: 'deco_chair_purple',
    name: 'ChairDamaskPurplegold',
    nameKo: '보라 의자',
    emoji: '🪑',
    fileName: 'ChairDamaskPurplegold.glb',
    source: 'Khronos glTF Samples',
    price: 120,
    category: 'deco',
  ),
  LocalModel(
    id: 'deco_sofa',
    name: 'GlamVelvetSofa',
    nameKo: '벨벳 소파',
    emoji: '🛋️',
    fileName: 'GlamVelvetSofa.glb',
    source: 'Khronos glTF Samples',
    price: 250,
    category: 'deco',
  ),
  LocalModel(
    id: 'deco_sheen_chair',
    name: 'SheenChair',
    nameKo: '광택 의자',
    emoji: '💺',
    fileName: 'SheenChair.glb',
    source: 'Khronos glTF Samples',
    price: 180,
    category: 'deco',
  ),
  LocalModel(
    id: 'deco_candle',
    name: 'GlassHurricaneCandleHolder',
    nameKo: '캔들 홀더',
    emoji: '🕯️',
    fileName: 'GlassHurricaneCandleHolder.glb',
    source: 'Khronos glTF Samples',
    price: 90,
    category: 'deco',
  ),
  LocalModel(
    id: 'deco_lamp',
    name: 'LightsPunctualLamp',
    nameKo: '스탠드 조명',
    emoji: '💡',
    fileName: 'LightsPunctualLamp.glb',
    source: 'Khronos glTF Samples',
    price: 150,
    category: 'deco',
  ),
  LocalModel(
    id: 'deco_pot',
    name: 'PotOfCoals',
    nameKo: '화로',
    emoji: '🔥',
    fileName: 'PotOfCoals.glb',
    source: 'Khronos glTF Samples',
    price: 100,
    category: 'deco',
  ),
  LocalModel(
    id: 'deco_helmet',
    name: 'DamagedHelmet',
    nameKo: '우주 헬멧',
    emoji: '⛑️',
    fileName: 'DamagedHelmet.glb',
    source: 'Khronos glTF Samples',
    price: 200,
    category: 'deco',
  ),
  LocalModel(
    id: 'deco_truck',
    name: 'CesiumMilkTruck',
    nameKo: '미니 트럭',
    emoji: '🚚',
    fileName: 'CesiumMilkTruck.glb',
    source: 'Khronos glTF Samples',
    animated: true,
    price: 160,
    category: 'deco',
  ),
];
