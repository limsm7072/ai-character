import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/character_registry.dart';
import '../services/settings_service.dart';
import '../services/app_detection_service.dart';
import '../services/overlay_service.dart';
import '../services/tts_service.dart';
import '../services/weather_service.dart';
import '../theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final AppDetectionService? appDetection;
  final TtsService ttsService;
  final WeatherService weatherService;

  const SettingsScreen({
    super.key,
    required this.settingsService,
    this.appDetection,
    required this.ttsService,
    required this.weatherService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');

  late TextEditingController _apiKeyController;
  late TextEditingController _nameController;
  final _appDetection = AppDetectionService();
  final _overlayService = OverlayService();
  bool _hasUsagePermission = false;
  bool _hasOverlayPermission = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController =
        TextEditingController(text: widget.settingsService.apiKey);
    _nameController =
        TextEditingController(text: widget.settingsService.characterName);
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
    _nameController.dispose();
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
          ListTile(
            title: const Text('완료 확인 간격'),
            subtitle: Text(_intervalLabel(widget.settingsService.routineCheckInterval)),
            trailing: DropdownButton<int>(
              value: widget.settingsService.routineCheckInterval,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5초')),
                DropdownMenuItem(value: 60, child: Text('1분')),
                DropdownMenuItem(value: 300, child: Text('5분')),
                DropdownMenuItem(value: 1800, child: Text('30분')),
                DropdownMenuItem(value: 3600, child: Text('1시간')),
              ],
              onChanged: (v) async {
                if (v != null) {
                  await widget.settingsService.setRoutineCheckInterval(v);
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
          _buildVoiceGroup(
            title: '여자 목소리',
            presets: voicePresets.where((p) => p.gender == 'female').toList(),
          ),
          _buildVoiceGroup(
            title: '남자 목소리',
            presets: voicePresets.where((p) => p.gender == 'male').toList(),
          ),
          const Divider(),

          // Character Selection
          _buildSectionHeader('캐릭터'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '캐릭터 이름',
                hintText: '루나',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    if (name.isNotEmpty) {
                      await widget.settingsService.setCharacterName(name);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('캐릭터 이름이 "$name"(으)로 변경되었습니다')),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          ),
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
          SwitchListTile(
            title: const Text('앱 잠금'),
            subtitle: const Text('루틴 시간에 차단된 앱을 강제로 닫습니다'),
            value: widget.settingsService.appLockEnabled,
            onChanged: (v) async {
              await widget.settingsService.setAppLockEnabled(v);
              setState(() {});
            },
          ),
          const Divider(),

          // Weather Section
          _buildSectionHeader('날씨'),
          ListTile(
            title: Text(
              widget.settingsService.weatherLocationName.isNotEmpty
                  ? widget.settingsService.weatherLocationName
                  : '현재 위치',
            ),
            subtitle: Text(
              '위도 ${widget.settingsService.weatherLat.toStringAsFixed(4)}, '
              '경도 ${widget.settingsService.weatherLon.toStringAsFixed(4)}',
            ),
            trailing: const Icon(Icons.my_location),
            onTap: _updateWeatherLocation,
          ),
          const SizedBox(height: 32),

          Center(
            child: Text(
              'AI Character v1.0.0',
              style: TextStyle(color: AppColors.grey500, fontSize: 12),
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
          ? const Icon(Icons.check_circle, color: AppColors.success)
          : OutlinedButton(
              onPressed: onTap,
              child: const Text('허용'),
            ),
    );
  }

  Widget _buildVoiceGroup({
    required String title,
    required List<VoicePreset> presets,
  }) {
    final selected = presets.any((p) => p.id == widget.settingsService.voicePreset);
    final current = selected
        ? presets.firstWhere((p) => p.id == widget.settingsService.voicePreset)
        : null;

    return ExpansionTile(
      title: Text(title),
      subtitle: current != null
          ? Text(current.label, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13))
          : null,
      initiallyExpanded: selected,
      children: presets.map((p) => _buildVoiceTile(p)).toList(),
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
          await widget.ttsService.speak('안녕! 나는 ${widget.settingsService.characterName}야. 오늘도 파이팅!');
          if (mounted) {
            final used = widget.ttsService.lastUsedEdgeTts;
            final err = widget.ttsService.lastEdgeError;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(used
                    ? 'Edge TTS (${preset.voiceName})'
                    : 'Edge TTS 실패 → 기본 TTS 사용\n$err'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
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

  String _intervalLabel(int seconds) {
    if (seconds < 60) return '$seconds초마다 미완료 루틴 확인';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes분마다 미완료 루틴 확인';
    return '${minutes ~/ 60}시간마다 미완료 루틴 확인';
  }

  Future<void> _updateWeatherLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 영구 거부됨. 설정에서 허용해주세요')),
          );
        }
        return;
      }
      if (perm == LocationPermission.denied) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      await widget.settingsService.setWeatherLocation(pos.latitude, pos.longitude);
      // Fetch weather to trigger reverse geocoding for location name
      final data = await widget.weatherService.fetch(pos.latitude, pos.longitude);
      if (data != null && data.locationName.isNotEmpty) {
        await widget.settingsService.setWeatherLocationName(data.locationName);
      }
      if (mounted) {
        setState(() {});
        final name = widget.settingsService.weatherLocationName;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(name.isNotEmpty ? '위치 업데이트: $name' : '위치 업데이트 완료')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 가져오기 실패: $e')),
        );
      }
    }
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
