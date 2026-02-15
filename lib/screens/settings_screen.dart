import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/character_registry.dart';
import '../services/settings_service.dart';
import '../services/app_detection_service.dart';
import '../services/overlay_service.dart';
import '../services/tts_service.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final AppDetectionService? appDetection;
  final TtsService ttsService;

  const SettingsScreen({
    super.key,
    required this.settingsService,
    this.appDetection,
    required this.ttsService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');

  late TextEditingController _apiKeyController;
  final _appDetection = AppDetectionService();
  final _overlayService = OverlayService();
  bool _hasUsagePermission = false;
  bool _hasOverlayPermission = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController =
        TextEditingController(text: widget.settingsService.apiKey);
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final usage = await _appDetection.hasPermission();
    final overlay = await _overlayService.hasPermission();
    setState(() {
      _hasUsagePermission = usage;
      _hasOverlayPermission = overlay;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // Permissions Section
          _buildSectionHeader('권한'),
          _buildPermissionTile(
            title: '사용 정보 접근',
            subtitle: '현재 사용 중인 앱을 감지합니다',
            granted: _hasUsagePermission,
            onTap: () async {
              await _appDetection.requestPermission();
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissions();
            },
          ),
          _buildPermissionTile(
            title: '다른 앱 위에 표시',
            subtitle: '캐릭터를 오버레이로 표시합니다',
            granted: _hasOverlayPermission,
            onTap: () async {
              await _overlayService.requestPermission();
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissions();
            },
          ),
          const Divider(),

          // Test Section
          _buildSectionHeader('진단'),
          ListTile(
            title: const Text('감지 테스트'),
            subtitle: const Text('현재 앱 감지가 작동하는지 확인'),
            trailing: const Icon(Icons.bug_report),
            onTap: _testDetection,
          ),
          ListTile(
            title: const Text('모니터링 서비스 시작'),
            subtitle: const Text('백그라운드 감시 수동 시작'),
            trailing: const Icon(Icons.play_arrow),
            onTap: () async {
              try {
                await _channel.invokeMethod('requestNotificationPermission');
                await Future.delayed(const Duration(seconds: 1));
                await _channel.invokeMethod('startMonitorService');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('모니터링 서비스 시작됨! 알림바를 확인하세요')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('서비스 시작 실패: $e')),
                  );
                }
              }
            },
          ),
          const Divider(),

          // API Key Section
          _buildSectionHeader('AI 설정'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'Gemini API 키',
                hintText: 'Google AI Studio에서 발급받은 키',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () async {
                    await widget.settingsService
                        .setApiKey(_apiKeyController.text.trim());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API 키가 저장되었습니다')),
                      );
                    }
                  },
                ),
              ),
              obscureText: true,
            ),
          ),
          const Divider(),

          // Nag Settings
          _buildSectionHeader('잔소리 설정'),
          ListTile(
            title: const Text('잔소리 빈도'),
            subtitle: Text('${widget.settingsService.nagFrequency}초마다'),
            trailing: DropdownButton<int>(
              value: widget.settingsService.nagFrequency,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1초')),
                DropdownMenuItem(value: 5, child: Text('5초')),
                DropdownMenuItem(value: 15, child: Text('15초')),
                DropdownMenuItem(value: 30, child: Text('30초')),
                DropdownMenuItem(value: 60, child: Text('1분')),
                DropdownMenuItem(value: 120, child: Text('2분')),
                DropdownMenuItem(value: 300, child: Text('5분')),
              ],
              onChanged: (v) async {
                if (v != null) {
                  await widget.settingsService.setNagFrequency(v);
                  setState(() {});
                }
              },
            ),
          ),
          ListTile(
            title: const Text('잔소리 강도'),
            subtitle: Text(_intensityLabel(widget.settingsService.nagIntensity)),
            trailing: DropdownButton<int>(
              value: widget.settingsService.nagIntensity,
              items: const [
                DropdownMenuItem(value: 0, child: Text('부드럽게')),
                DropdownMenuItem(value: 1, child: Text('보통')),
                DropdownMenuItem(value: 2, child: Text('엄격하게')),
              ],
              onChanged: (v) async {
                if (v != null) {
                  await widget.settingsService.setNagIntensity(v);
                  setState(() {});
                }
              },
            ),
          ),
          const Divider(),

          // Voice Settings
          _buildSectionHeader('음성'),
          SwitchListTile(
            title: const Text('음성 출력'),
            subtitle: const Text('캐릭터가 말할 때 음성으로 읽어줍니다'),
            value: widget.settingsService.ttsEnabled,
            onChanged: (v) async {
              await widget.settingsService.setTtsEnabled(v);
              setState(() {});
            },
          ),
          // Female voices
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('여자 목소리',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          ...voicePresets
              .where((p) => p.gender == 'female')
              .map((preset) => _buildVoiceTile(preset)),
          // Male voices
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('남자 목소리',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          ...voicePresets
              .where((p) => p.gender == 'male')
              .map((preset) => _buildVoiceTile(preset)),
          const Divider(),

          // Character Selection
          _buildSectionHeader('캐릭터'),
          ListTile(
            title: const Text('캐릭터 선택'),
            subtitle: Text(CharacterRegistry.getById(
                    widget.settingsService.selectedCharacter)
                .displayName),
            trailing: DropdownButton<String>(
              value: widget.settingsService.selectedCharacter,
              items: CharacterRegistry.characters
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.displayName),
                      ))
                  .toList(),
              onChanged: (v) async {
                if (v != null) {
                  await widget.settingsService.setSelectedCharacter(v);
                  setState(() {});
                }
              },
            ),
          ),
          const Divider(),

          // Overlay Settings
          _buildSectionHeader('오버레이'),
          SwitchListTile(
            title: const Text('오버레이 활성화'),
            subtitle: const Text('딴짓할 때 캐릭터가 화면에 나타납니다'),
            value: widget.settingsService.overlayEnabled,
            onChanged: (v) async {
              await widget.settingsService.setOverlayEnabled(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 32),

          Center(
            child: Text(
              'AI Character v1.0.0',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _testDetection() async {
    try {
      final result = await _channel.invokeMethod<Map>('testDetection');
      if (result != null && mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('감지 테스트 결과'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('사용 정보 권한: ${result['has_usage_permission'] == true ? "OK" : "없음"}'),
                Text('오버레이 권한: ${result['has_overlay_permission'] == true ? "OK" : "없음"}'),
                const SizedBox(height: 8),
                Text('현재 앱: ${result['app_label'] ?? '감지 불가'}'),
                Text('패키지: ${result['foreground_app'] ?? ''}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('테스트 실패: $e')),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: granted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : OutlinedButton(
              onPressed: onTap,
              child: const Text('허용'),
            ),
    );
  }

  Widget _buildVoiceTile(VoicePreset preset) {
    return RadioListTile<String>(
      title: Text(preset.label),
      subtitle: Text(preset.description),
      value: preset.id,
      groupValue: widget.settingsService.voicePreset,
      secondary: IconButton(
        icon: const Icon(Icons.play_circle_outline),
        tooltip: '미리 듣기',
        onPressed: () async {
          await widget.ttsService.applyPreset(preset.id);
          await widget.ttsService.speak('안녕! 나는 루나야. 오늘도 파이팅!');
        },
      ),
      onChanged: (v) async {
        if (v != null) {
          await widget.settingsService.setVoicePreset(v);
          await widget.ttsService.applyPreset(v);
          setState(() {});
        }
      },
    );
  }

  String _intensityLabel(int level) {
    switch (level) {
      case 0:
        return '부드럽게 격려합니다';
      case 1:
        return '보통 강도로 잔소리합니다';
      case 2:
        return '엄격하게 혼냅니다';
      default:
        return '';
    }
  }
}
