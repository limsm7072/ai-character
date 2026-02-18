import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/business_card.dart';
import '../services/card_service.dart';
import '../theme/app_colors.dart';

class CardScreen extends StatefulWidget {
  final CardService cardService;

  const CardScreen({super.key, required this.cardService});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');

  final _cardKey = GlobalKey();
  late BusinessCard _card;
  bool _editing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _positionCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _countryCtrl;
  late TextEditingController _provinceCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _birthYearCtrl;

  @override
  void initState() {
    super.initState();
    _card = widget.cardService.get() ?? BusinessCard();
    _editing = _card.isEmpty; // 명함 없으면 바로 편집 모드
    _nameCtrl = TextEditingController(text: _card.name);
    _companyCtrl = TextEditingController(text: _card.company);
    _positionCtrl = TextEditingController(text: _card.position);
    _phoneCtrl = TextEditingController(text: _card.phone);
    _emailCtrl = TextEditingController(text: _card.email);
    _bioCtrl = TextEditingController(text: _card.bio);
    _countryCtrl = TextEditingController(text: _card.country);
    _provinceCtrl = TextEditingController(text: _card.province);
    _cityCtrl = TextEditingController(text: _card.city);
    _birthYearCtrl = TextEditingController(text: _card.birthYear);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _positionCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    _countryCtrl.dispose();
    _provinceCtrl.dispose();
    _cityCtrl.dispose();
    _birthYearCtrl.dispose();
    super.dispose();
  }

  void _updateCard() {
    _card.name = _nameCtrl.text.trim();
    _card.company = _companyCtrl.text.trim();
    _card.position = _positionCtrl.text.trim();
    _card.phone = _phoneCtrl.text.trim();
    _card.email = _emailCtrl.text.trim();
    _card.bio = _bioCtrl.text.trim();
    _card.country = _countryCtrl.text.trim();
    _card.province = _provinceCtrl.text.trim();
    _card.city = _cityCtrl.text.trim();
    _card.birthYear = _birthYearCtrl.text.trim();
    setState(() {});
  }

  Future<void> _save() async {
    _updateCard();
    await widget.cardService.save(_card);
    if (mounted) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('명함이 저장되었습니다'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _shareImage() async {
    _updateCard();
    if (_card.isEmpty) return;
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final cacheDir = await _channel.invokeMethod<String>('getCacheDir');
      final file = File('$cacheDir/my_card.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await _channel.invokeMethod('shareFile', {'path': file.path, 'mimeType': 'image/png'});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('공유 실패: $e')));
      }
    }
  }

  Future<void> _shareVcf() async {
    _updateCard();
    if (_card.isEmpty) return;
    try {
      final cacheDir = await _channel.invokeMethod<String>('getCacheDir');
      final file = File('$cacheDir/my_card.vcf');
      await file.writeAsString(_card.toVCard());
      await _channel.invokeMethod('shareFile', {'path': file.path, 'mimeType': 'text/x-vcard'});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('공유 실패: $e')));
      }
    }
  }

  void _showShareDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('이미지로 공유'),
              onTap: () {
                Navigator.pop(ctx);
                _shareImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone_outlined),
              title: const Text('연락처로 공유'),
              onTap: () {
                Navigator.pop(ctx);
                _shareVcf();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final path = await _channel.invokeMethod<String>('pickImage');
      if (path != null && path.isNotEmpty) {
        setState(() => _card.photoPath = path);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 명함'),
        actions: _editing
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: '공유',
                  onPressed: () => _showShareDialog(),
                ),
              ],
      ),
      body: _editing ? _buildEditBody(theme) : _buildViewBody(theme),
    );
  }

  // ─── 뷰 모드 ───────────────────────────────
  Widget _buildViewBody(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          RepaintBoundary(
            key: _cardKey,
            child: _buildCardPreview(theme),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('편집'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── 편집 모드 ──────────────────────────────
  Widget _buildEditBody(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ─── 명함 미리보기 ──────────────────
          RepaintBoundary(
            key: _cardKey,
            child: _buildCardPreview(theme),
          ),
          const SizedBox(height: 20),

          // ─── 테마 선택 ────────────────────
          _buildThemeSelector(theme),
          const SizedBox(height: 24),

          // ─── 사진 ────────────────────────
          _buildPhotoSection(theme),
          const SizedBox(height: 16),

          // ─── 기본 정보 ──────────────────
          _buildField('이름', _nameCtrl, Icons.person_outline),
          _buildField('회사', _companyCtrl, Icons.business_outlined,
              visible: _card.showCompany,
              onToggle: (v) => setState(() => _card.showCompany = v)),
          _buildField('직책', _positionCtrl, Icons.badge_outlined,
              visible: _card.showPosition,
              onToggle: (v) => setState(() => _card.showPosition = v)),
          _buildField('전화번호', _phoneCtrl, Icons.phone_outlined,
              keyboard: TextInputType.phone,
              visible: _card.showPhone,
              onToggle: (v) => setState(() => _card.showPhone = v)),
          _buildField('이메일', _emailCtrl, Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
              visible: _card.showEmail,
              onToggle: (v) => setState(() => _card.showEmail = v)),

          // ─── 지역 ──────────────────────
          _buildLocationRow(theme),

          // ─── 개인 정보 ──────────────────
          _buildGenderSelector(theme),
          _buildField('출생 연도', _birthYearCtrl, Icons.cake_outlined,
              keyboard: TextInputType.number,
              visible: _card.showBirthYear,
              onToggle: (v) => setState(() => _card.showBirthYear = v)),

          _buildField('한 줄 소개', _bioCtrl, Icons.info_outline,
              visible: _card.showBio,
              onToggle: (v) => setState(() => _card.showBio = v)),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('저장'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── 헬퍼 ─────────────────────────────────

  String get _visibleSubtitle {
    final parts = <String>[];
    if (_card.showPosition && _card.position.isNotEmpty) parts.add(_card.position);
    if (_card.showCompany && _card.company.isNotEmpty) parts.add(_card.company);
    return parts.join(' | ');
  }

  // ─── 명함 미리보기 카드 ──────────────────────

  Widget _buildCardPreview(ThemeData theme) {
    final t = _cardTheme(_card.theme);
    final hasPhoto = _card.showPhoto && _card.photoPath.isNotEmpty && File(_card.photoPath).existsSync();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.bg,
        gradient: t.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (hasPhoto) ...[
                CircleAvatar(
                  radius: 28,
                  backgroundImage: FileImage(File(_card.photoPath)),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _card.name.isEmpty ? '이름' : _card.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _card.name.isEmpty ? t.textColor.withValues(alpha: 0.3) : t.textColor,
                      ),
                    ),
                    if (_visibleSubtitle.isNotEmpty)
                      Text(_visibleSubtitle, style: TextStyle(fontSize: 14, color: t.subColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: t.accentColor.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 16),
          if (_card.showPhone && _card.phone.isNotEmpty)
            _previewRow(Icons.phone_outlined, _card.phone, t),
          if (_card.showEmail && _card.email.isNotEmpty)
            _previewRow(Icons.email_outlined, _card.email, t),
          if (_card.showLocation && _card.locationText.isNotEmpty)
            _previewRow(Icons.location_on_outlined, _card.locationText, t),
          if (_card.showGender && _card.gender.isNotEmpty)
            _previewRow(Icons.wc_outlined, _card.gender, t),
          if (_card.showBirthYear && _card.birthYear.isNotEmpty)
            _previewRow(Icons.cake_outlined, '${_card.birthYear}년생', t),
          if (_card.showBio && _card.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _card.bio,
              style: TextStyle(fontSize: 12, color: t.subColor, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewRow(IconData icon, String text, _CardTheme t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: t.accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: t.textColor)),
          ),
        ],
      ),
    );
  }

  // ─── 사진 섹션 ──────────────────────────────

  Widget _buildPhotoSection(ThemeData theme) {
    final hasPhoto = _card.photoPath.isNotEmpty && File(_card.photoPath).existsSync();

    return Row(
      children: [
        GestureDetector(
          onTap: _pickPhoto,
          child: CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: hasPhoto ? FileImage(File(_card.photoPath)) : null,
            child: hasPhoto ? null : Icon(Icons.camera_alt, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('프로필 사진', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(
                hasPhoto ? '탭하여 변경' : '탭하여 추가',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (hasPhoto)
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: AppColors.grey500),
            onPressed: () => setState(() => _card.photoPath = ''),
            tooltip: '사진 삭제',
          ),
        IconButton(
          icon: Icon(
            _card.showPhoto ? Icons.visibility : Icons.visibility_off,
            size: 20,
            color: _card.showPhoto ? AppColors.primary : AppColors.grey400,
          ),
          tooltip: _card.showPhoto ? '공개' : '비공개',
          onPressed: () => setState(() => _card.showPhoto = !_card.showPhoto),
        ),
      ],
    );
  }

  // ─── 지역 입력 (국가 / 도 / 시 한 줄 + 토글) ──────

  Widget _buildLocationRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _countryCtrl,
              onChanged: (_) => _updateCard(),
              decoration: InputDecoration(
                labelText: '국가',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _provinceCtrl,
              onChanged: (_) => _updateCard(),
              decoration: InputDecoration(
                labelText: '도/광역시',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _cityCtrl,
              onChanged: (_) => _updateCard(),
              decoration: InputDecoration(
                labelText: '시/구',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(
                _card.showLocation ? Icons.visibility : Icons.visibility_off,
                size: 20,
                color: _card.showLocation ? AppColors.primary : AppColors.grey400,
              ),
              tooltip: _card.showLocation ? '공개' : '비공개',
              onPressed: () => setState(() => _card.showLocation = !_card.showLocation),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 성별 선택 ────────────────────────────────

  Widget _buildGenderSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '성별',
                prefixIcon: const Icon(Icons.wc_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              ),
              child: Row(
                children: [
                  _genderChip('남', theme),
                  const SizedBox(width: 8),
                  _genderChip('여', theme),
                  if (_card.gender.isNotEmpty) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _card.gender = ''),
                      child: Icon(Icons.close, size: 16, color: AppColors.grey400),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(
                _card.showGender ? Icons.visibility : Icons.visibility_off,
                size: 20,
                color: _card.showGender ? AppColors.primary : AppColors.grey400,
              ),
              tooltip: _card.showGender ? '공개' : '비공개',
              onPressed: () => setState(() => _card.showGender = !_card.showGender),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderChip(String label, ThemeData theme) {
    final selected = _card.gender == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _card.gender = v ? label : ''),
      visualDensity: VisualDensity.compact,
    );
  }

  // ─── 테마 선택 ──────────────────────────────

  Widget _buildThemeSelector(ThemeData theme) {
    const labels = ['미니멀', '다크', '그라데이션', '파스텔'];
    const colors = [
      AppColors.white,
      AppColors.grey900,
      AppColors.primary,
      Color(0xFFB2DFDB), // teal 100
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final selected = _card.theme == i;
        return GestureDetector(
          onTap: () => setState(() => _card.theme = i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.grey300,
                      width: selected ? 3 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6)]
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppColors.primary : AppColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─── 폼 필드 ──────────────────────────────────

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? keyboard, bool? visible, ValueChanged<bool>? onToggle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: keyboard,
              onChanged: (_) => _updateCard(),
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          if (onToggle != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: IconButton(
                icon: Icon(
                  visible == true ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                  color: visible == true ? AppColors.primary : AppColors.grey400,
                ),
                tooltip: visible == true ? '공개' : '비공개',
                onPressed: () => onToggle(!(visible ?? true)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 테마 데이터 ─────────────────────────────────

class _CardTheme {
  final Color? bg;
  final Gradient? gradient;
  final Color textColor;
  final Color subColor;
  final Color accentColor;

  const _CardTheme({
    this.bg,
    this.gradient,
    required this.textColor,
    required this.subColor,
    required this.accentColor,
  });
}

_CardTheme _cardTheme(int theme) {
  switch (theme) {
    case 1: // 다크
      return const _CardTheme(
        bg: Color(0xFF1E1E1E),
        textColor: AppColors.white,
        subColor: AppColors.grey400,
        accentColor: AppColors.accent,
      );
    case 2: // 그라데이션
      return const _CardTheme(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF00BCD4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        textColor: AppColors.white,
        subColor: Color(0xCCFFFFFF),
        accentColor: AppColors.white,
      );
    case 3: // 파스텔
      return const _CardTheme(
        bg: Color(0xFFE0F2F1), // teal 50
        textColor: AppColors.grey900,
        subColor: AppColors.grey600,
        accentColor: AppColors.primaryDark,
      );
    default: // 0 미니멀 화이트
      return const _CardTheme(
        bg: AppColors.white,
        textColor: AppColors.grey900,
        subColor: AppColors.grey600,
        accentColor: AppColors.primary,
      );
  }
}
