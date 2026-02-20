import 'package:flutter/material.dart';
import '../models/fortune_data.dart';
import '../services/fortune_service.dart';

class FortuneScreen extends StatefulWidget {
  final FortuneService fortuneService;
  final String title;

  const FortuneScreen({
    super.key,
    required this.fortuneService,
    this.title = '오늘의 운세',
  });

  @override
  State<FortuneScreen> createState() => _FortuneScreenState();
}

class _FortuneScreenState extends State<FortuneScreen> {
  FortuneData? _fortune;

  // Profile form
  DateTime _selectedDate = DateTime(2000, 1, 1);
  int _selectedHour = -1; // -1 = 모름
  String _selectedGender = '';

  @override
  void initState() {
    super.initState();
    if (widget.fortuneService.hasProfile) {
      _fortune = widget.fortuneService.generateTodayFortune();
    } else {
      // Pre-fill from existing profile if any
      final bd = widget.fortuneService.birthDate;
      if (bd.isNotEmpty) {
        final parts = bd.split('-');
        if (parts.length == 3) {
          _selectedDate = DateTime(
            int.tryParse(parts[0]) ?? 2000,
            int.tryParse(parts[1]) ?? 1,
            int.tryParse(parts[2]) ?? 1,
          );
        }
      }
      _selectedHour = widget.fortuneService.birthHour;
      _selectedGender = widget.fortuneService.gender;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.fortuneService.hasProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: _showProfileEdit,
                  tooltip: '생년월일 수정',
                ),
              ]
            : null,
      ),
      body: _fortune != null ? _buildFortuneView() : _buildProfileForm(),
    );
  }

  // ─── Profile Form ───

  Widget _buildProfileForm() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.auto_awesome, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('운세를 보려면\n생년월일을 입력해주세요',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 32),

          // 생년월일
          _buildFormLabel('생년월일 (양력)'),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(1920),
                lastDate: DateTime.now(),
                locale: const Locale('ko', 'KR'),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 태어난 시
          _buildFormLabel('태어난 시 (선택)'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedHour,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: -1, child: Text('모름')),
                  ..._birthHourOptions.map((e) => DropdownMenuItem(
                    value: e['hour'] as int,
                    child: Text(e['label'] as String),
                  )),
                ],
                onChanged: (v) => setState(() => _selectedHour = v ?? -1),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 성별
          _buildFormLabel('성별'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildGenderChip('남', Icons.male, _selectedGender == 'male'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGenderChip('여', Icons.female, _selectedGender == 'female'),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // 확인 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _selectedGender.isNotEmpty ? _saveProfile : null,
              child: const Text('운세 보기', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
    );
  }

  Widget _buildGenderChip(String label, IconData icon, bool selected) {
    final theme = Theme.of(context);
    final gender = label == '남' ? 'male' : 'female';
    return InkWell(
      onTap: () => setState(() => _selectedGender = gender),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20,
              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }

  static final _birthHourOptions = [
    {'hour': 0, 'label': '자시 (23:00~01:00)'},
    {'hour': 2, 'label': '축시 (01:00~03:00)'},
    {'hour': 4, 'label': '인시 (03:00~05:00)'},
    {'hour': 6, 'label': '묘시 (05:00~07:00)'},
    {'hour': 8, 'label': '진시 (07:00~09:00)'},
    {'hour': 10, 'label': '사시 (09:00~11:00)'},
    {'hour': 12, 'label': '오시 (11:00~13:00)'},
    {'hour': 14, 'label': '미시 (13:00~15:00)'},
    {'hour': 16, 'label': '신시 (15:00~17:00)'},
    {'hour': 18, 'label': '유시 (17:00~19:00)'},
    {'hour': 20, 'label': '술시 (19:00~21:00)'},
    {'hour': 22, 'label': '해시 (21:00~23:00)'},
  ];

  Future<void> _saveProfile() async {
    final dateStr = '${_selectedDate.year}-'
        '${_selectedDate.month.toString().padLeft(2, '0')}-'
        '${_selectedDate.day.toString().padLeft(2, '0')}';

    await widget.fortuneService.setProfile(
      birthDate: dateStr,
      birthHour: _selectedHour,
      gender: _selectedGender,
    );

    setState(() {
      _fortune = widget.fortuneService.generateTodayFortune();
    });
  }

  void _showProfileEdit() {
    // Load current profile into form
    final bd = widget.fortuneService.birthDate;
    if (bd.isNotEmpty) {
      final parts = bd.split('-');
      if (parts.length == 3) {
        _selectedDate = DateTime(
          int.tryParse(parts[0]) ?? 2000,
          int.tryParse(parts[1]) ?? 1,
          int.tryParse(parts[2]) ?? 1,
        );
      }
    }
    _selectedHour = widget.fortuneService.birthHour;
    _selectedGender = widget.fortuneService.gender;

    setState(() => _fortune = null);
  }

  // ─── Fortune View ───

  Widget _buildFortuneView() {
    final theme = Theme.of(context);
    final f = _fortune!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 총운 카드
          _buildOverallCard(theme, f),
          const SizedBox(height: 16),

          // 루나 한마디
          _buildAdviceCard(theme, f),
          const SizedBox(height: 16),

          // 카테고리별 운세
          _buildCategoryCards(theme, f),
          const SizedBox(height: 16),

          // 행운 아이템
          _buildLuckyItems(theme, f),
          const SizedBox(height: 16),

          // 기본 정보
          _buildInfoCard(theme, f),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOverallCard(ThemeData theme, FortuneData f) {
    final color = _scoreColor(f.overallScore, theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            theme.colorScheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(f.lunarDateStr,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          // Score circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: f.overallScore / 100,
                    strokeWidth: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: color,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${f.overallScore}',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: color)),
                    Text(f.overallLabel,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('오늘의 총운',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildAdviceCard(ThemeData theme, FortuneData f) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💬', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('루나의 한마디',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary)),
                const SizedBox(height: 4),
                Text(f.todayAdvice,
                  style: TextStyle(fontSize: 14, height: 1.5,
                    color: theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCards(ThemeData theme, FortuneData f) {
    final categories = [
      ('재물', Icons.monetization_on_outlined),
      ('연애', Icons.favorite_outline),
      ('건강', Icons.health_and_safety_outlined),
      ('사업', Icons.work_outline),
      ('학업', Icons.school_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('카테고리별 운세',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
        ...categories.map((cat) {
          final score = f.categoryScores[cat.$1] ?? 50;
          final text = f.categoryTexts[cat.$1] ?? '';
          final color = _scoreColor(score, theme);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(cat.$2, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(cat.$1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('$score점', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: color,
                    minHeight: 6,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(text,
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLuckyItems(ThemeData theme, FortuneData f) {
    final items = [
      ('색상', f.luckyColor, Icons.palette_outlined),
      ('숫자', f.luckyNumber, Icons.tag),
      ('방향', f.luckyDirection, Icons.explore_outlined),
      ('음식', f.luckyFood, Icons.restaurant_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('행운 아이템',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Row(
          children: items.map((item) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: item != items.last ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(item.$3, size: 22, color: theme.colorScheme.primary),
                    const SizedBox(height: 6),
                    Text(item.$1, style: TextStyle(fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(item.$2, style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInfoCard(ThemeData theme, FortuneData f) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(theme, '띠', '${f.zodiacAnimal}띠'),
          Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
          _buildInfoItem(theme, '별자리', f.constellation),
          Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
          _buildInfoItem(theme, '오행', '${f.dayMasterElement}(${_elementEmoji(f.dayMasterElement)})'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _elementEmoji(String element) {
    switch (element) {
      case '목': return '🌳';
      case '화': return '🔥';
      case '토': return '🌍';
      case '금': return '⚔️';
      case '수': return '💧';
      default: return '';
    }
  }

  Color _scoreColor(int score, ThemeData theme) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return theme.colorScheme.primary;
    if (score >= 45) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }
}
