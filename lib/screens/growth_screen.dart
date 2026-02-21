import 'dart:math';
import 'package:flutter/material.dart';
import '../models/growth_data.dart';
import '../services/growth_service.dart';
import '../service_locator.dart';
import '../theme/app_colors.dart';

class GrowthScreen extends StatelessWidget {
  final String? title;

  const GrowthScreen({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = getIt<GrowthService>().currentData;
    final accent = AppColors.accent;

    return Scaffold(
      appBar: AppBar(title: Text(title ?? '루나 성장'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─── 레벨 카드 ───
            _buildLevelCard(theme, data, accent),
            const SizedBox(height: 20),

            // ─── XP 진행도 ───
            _buildXpProgress(theme, data, accent),
            const SizedBox(height: 20),

            // ─── 오늘 통계 ───
            _buildTodayStats(theme, data, accent),
            const SizedBox(height: 20),

            // ─── 칭호 목록 ───
            _buildTitleList(theme, data, accent),
            const SizedBox(height: 20),

            // ─── XP 히스토리 차트 ───
            _buildXpChart(theme, data, accent),
            const SizedBox(height: 20),

            // ─── XP 획득 안내 ───
            _buildXpGuide(theme, accent),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(ThemeData theme, GrowthData data, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.03)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // 레벨 원형
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withValues(alpha: 0.3), accent.withValues(alpha: 0.1)],
              ),
              border: Border.all(color: accent, width: 3),
              boxShadow: [
                if (data.level >= 5)
                  BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2),
              ],
            ),
            child: Center(
              child: Text('${data.level}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: accent)),
            ),
          ),
          const SizedBox(height: 12),

          // 칭호
          Text(data.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('${data.totalXp} XP', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildXpProgress(ThemeData theme, GrowthData data, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('레벨 진행도', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Lv.${data.level}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
              const Spacer(),
              Text('Lv.${data.level + 1}', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: data.levelProgress,
              minHeight: 10,
              backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${data.totalXp - data.currentLevelXp} / ${data.nextLevelXp - data.currentLevelXp} XP',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              Text('다음 레벨까지 ${data.xpToNextLevel} XP',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStats(ThemeData theme, GrowthData data, Color accent) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.bolt, size: 24, color: accent),
                const SizedBox(height: 8),
                Text('+${data.todayXp}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: accent)),
                const SizedBox(height: 2),
                Text('오늘 획득 XP', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.local_fire_department, size: 24, color: data.streak > 0 ? AppColors.streak : theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text('${data.streak}일', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: data.streak > 0 ? AppColors.streak : theme.colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text('연속 달성', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleList(ThemeData theme, GrowthData data, Color accent) {
    final titles = [
      (1, '새싹', 0),
      (2, '새싹 루티너', 50),
      (4, '성장 중', 450),
      (6, '습관 마스터', 1250),
      (8, '꾸준함의 왕', 2450),
      (10, '루나의 자랑', 4050),
      (12, '습관의 달인', 6050),
      (15, '전설의 루티너', 10050),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('칭호 목록', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...titles.map((t) {
            final (lv, name, xp) = t;
            final unlocked = data.level >= lv;
            final isCurrent = data.title == name;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: unlocked ? accent.withValues(alpha: 0.15) : theme.colorScheme.outline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrent ? Border.all(color: accent, width: 2) : null,
                    ),
                    child: Center(
                      child: Text('$lv', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: unlocked ? accent : theme.colorScheme.outline,
                      )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(
                          fontSize: 14, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: unlocked ? theme.colorScheme.onSurface : theme.colorScheme.outline,
                        )),
                        Text('Lv.$lv | ${xp} XP', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text('현재', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
                    )
                  else if (unlocked)
                    Icon(Icons.check_circle, size: 18, color: accent.withValues(alpha: 0.5))
                  else
                    Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildXpChart(ThemeData theme, GrowthData data, Color accent) {
    if (data.xpHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text('XP 히스토리', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Text('아직 기록이 없어요', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('루틴을 완료하면 XP를 획득해요!', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final sorted = data.xpHistory.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final last7 = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;
    final maxXp = last7.fold<int>(1, (prev, e) => e.value > prev ? e.value : prev);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('최근 XP 획득', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: last7.map((e) {
                final barHeight = (80.0 * e.value / maxXp).clamp(4.0, 80.0);
                final dateLabel = e.key.substring(5); // MM-DD
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('+${e.value}', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(dateLabel, style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpGuide(ThemeData theme, Color accent) {
    final items = [
      ('루틴 완료', '+10 XP', Icons.check_circle_outline),
      ('연속 달성 보너스', '+연속일x2 XP (최대 20)', Icons.local_fire_department),
      ('모든 루틴 완료', '+30 XP', Icons.star_outline),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('XP 획득 방법', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...items.map((item) {
            final (label, xp, icon) = item;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
                  Text(xp, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
