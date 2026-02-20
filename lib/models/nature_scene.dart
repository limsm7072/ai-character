import 'package:flutter/material.dart';

class NatureScene {
  final String id;
  final String name;
  final IconData icon;
  final List<Color> gradient;
  final String soundType;

  const NatureScene({
    required this.id,
    required this.name,
    required this.icon,
    required this.gradient,
    required this.soundType,
  });

  static const scenes = [
    NatureScene(
      id: 'rain',
      name: '빗소리',
      icon: Icons.water_drop,
      gradient: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
      soundType: 'rain',
    ),
    NatureScene(
      id: 'ocean',
      name: '파도',
      icon: Icons.waves,
      gradient: [Color(0xFF0F2027), Color(0xFF2C5364)],
      soundType: 'ocean',
    ),
    NatureScene(
      id: 'stream',
      name: '시냇물',
      icon: Icons.water,
      gradient: [Color(0xFF134E5E), Color(0xFF71B280)],
      soundType: 'stream',
    ),
    NatureScene(
      id: 'forest',
      name: '숲속',
      icon: Icons.forest,
      gradient: [Color(0xFF1D4E2C), Color(0xFF6B8F71)],
      soundType: 'forest',
    ),
    NatureScene(
      id: 'fire',
      name: '모닥불',
      icon: Icons.local_fire_department,
      gradient: [Color(0xFF3E1C0D), Color(0xFFB85C38)],
      soundType: 'fire',
    ),
    NatureScene(
      id: 'wind',
      name: '바람',
      icon: Icons.air,
      gradient: [Color(0xFF373B44), Color(0xFF73868C)],
      soundType: 'wind',
    ),
    NatureScene(
      id: 'night',
      name: '밤벌레',
      icon: Icons.nightlight_round,
      gradient: [Color(0xFF0F0C29), Color(0xFF302B63)],
      soundType: 'night',
    ),
  ];
}
