import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/character_registry.dart';
import '../services/settings_service.dart';
import '../services/app_detection_service.dart';
import '../services/overlay_service.dart';
import '../services/tts_service.dart';
import '../services/weather_service.dart';
import '../service_locator.dart';
import '../theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _channel = MethodChannel('com.aicharacter.ai_character/usage_stats');

  late TextEditingController _apiKeyController;
  late TextEditingController _nameController;
  AppDetectionService get _appDetection => getIt<AppDetectionService>();
  OverlayService get _overlayService => getIt<OverlayService>();
  bool _hasUsagePermission = false;
  bool _hasOverlayPermission = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController =
        TextEditingController(text: getIt<SettingsService>().apiKey);
    _nameController =
        TextEditingController(text: getIt<SettingsService>().characterName);
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
          // Permissions + Diagnostics (collapsible, starts collapsed)
          ExpansionTile(
            title: const Text('권한 / 진단 / AI'),
            leading: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary, size: 20),
            initiallyExpanded: false,
            children: [
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
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                title: const Text('감지 테스트'),
                subtitle: const Text('현재 앱 감지가 작동하는지 확인'),
                trailing: const Icon(Icons.bug_report),
                onTap: _testDetection,
              ),
              ListTile(
                title: const Text('위젯 데이터 테스트'),
                subtitle: const Text('위젯이 읽는 SharedPreferences 확인'),
                trailing: const Icon(Icons.widgets),
                onTap: () async {
                  try {
                    final result = await _channel.invokeMethod('debugWidgetData');
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('위젯 데이터'),
                          content: SingleChildScrollView(
                            child: Text(
                              result?.toString() ?? '결과 없음',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
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
                        SnackBar(content: Text('오류: $e')),
                      );
                    }
                  }
                },
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
              const Divider(indent: 16, endIndent: 16),
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
                        await getIt<SettingsService>()
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
            ],
          ),
          const Divider(),

          // Voice Settings
          _buildSectionHeader('음성'),
          SwitchListTile(
            title: const Text('음성 출력'),
            subtitle: const Text('캐릭터가 말할 때 음성으로 읽어줍니다'),
            value: getIt<SettingsService>().ttsEnabled,
            onChanged: (v) async {
              await getIt<SettingsService>().setTtsEnabled(v);
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
                      await getIt<SettingsService>().setCharacterName(name);
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
                    getIt<SettingsService>().selectedCharacter)
                .displayName),
            trailing: DropdownButton<String>(
              value: getIt<SettingsService>().selectedCharacter,
              items: CharacterRegistry.characters
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.displayName),
                      ))
                  .toList(),
              onChanged: (v) async {
                if (v != null) {
                  await getIt<SettingsService>().setSelectedCharacter(v);
                  setState(() {});
                }
              },
            ),
          ),
          SwitchListTile(
            title: const Text('대화 화면 캐릭터'),
            subtitle: const Text('대화 화면에서 캐릭터를 표시합니다'),
            value: getIt<SettingsService>().chatCharacterVisible,
            onChanged: (v) async {
              await getIt<SettingsService>().setChatCharacterVisible(v);
              setState(() {});
            },
          ),
          const Divider(),

          // Routine Section
          _buildSectionHeader('루틴'),
          SwitchListTile(
            title: const Text('지난 루틴 확인'),
            subtitle: const Text('끝난 루틴의 완료 여부를 자동으로 물어봅니다'),
            value: getIt<SettingsService>().pastRoutineCheckEnabled,
            onChanged: (v) async {
              await getIt<SettingsService>().setPastRoutineCheckEnabled(v);
              setState(() {});
            },
          ),
          if (getIt<SettingsService>().pastRoutineCheckEnabled)
            ListTile(
              title: const Text('확인 간격'),
              subtitle: const Text('얼마나 자주 확인할지 설정합니다'),
              trailing: DropdownButton<int>(
                value: getIt<SettingsService>().routineCheckInterval,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1초')),
                  DropdownMenuItem(value: 5, child: Text('5초')),
                  DropdownMenuItem(value: 10, child: Text('10초')),
                  DropdownMenuItem(value: 60, child: Text('1분')),
                  DropdownMenuItem(value: 300, child: Text('5분')),
                  DropdownMenuItem(value: 600, child: Text('10분')),
                  DropdownMenuItem(value: 1800, child: Text('30분')),
                  DropdownMenuItem(value: 3600, child: Text('1시간')),
                  DropdownMenuItem(value: 21600, child: Text('6시간')),
                ],
                onChanged: (v) async {
                  if (v != null) {
                    await getIt<SettingsService>().setRoutineCheckInterval(v);
                    setState(() {});
                  }
                },
              ),
            ),
          const Divider(),

          // Weather Section
          _buildSectionHeader('날씨'),
          ListTile(
            title: Text(
              getIt<SettingsService>().weatherLocationName.isNotEmpty
                  ? getIt<SettingsService>().weatherLocationName
                  : '현재 위치',
            ),
            subtitle: Text(
              '위도 ${getIt<SettingsService>().weatherLat.toStringAsFixed(4)}, '
              '경도 ${getIt<SettingsService>().weatherLon.toStringAsFixed(4)}',
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
    final selected = presets.any((p) => p.id == getIt<SettingsService>().voicePreset);
    final current = selected
        ? presets.firstWhere((p) => p.id == getIt<SettingsService>().voicePreset)
        : null;

    return ExpansionTile(
      title: Text(title),
      subtitle: current != null
          ? Text(current.label, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13))
          : null,
      initiallyExpanded: false,
      children: presets.map((p) => _buildVoiceTile(p)).toList(),
    );
  }

  Widget _buildVoiceTile(VoicePreset preset) {
    return RadioListTile<String>(
      title: Text(preset.label),
      subtitle: Text(preset.description),
      value: preset.id,
      groupValue: getIt<SettingsService>().voicePreset,
      secondary: IconButton(
        icon: const Icon(Icons.play_circle_outline),
        tooltip: '미리 듣기',
        onPressed: () async {
          await getIt<TtsService>().applyPreset(preset.id);
          await getIt<TtsService>().speak('안녕! 나는 ${getIt<SettingsService>().characterName}야. 오늘도 파이팅!');
          if (mounted) {
            final used = getIt<TtsService>().lastUsedEdgeTts;
            final err = getIt<TtsService>().lastEdgeError;
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
          await getIt<SettingsService>().setVoicePreset(v);
          await getIt<TtsService>().applyPreset(v);
          setState(() {});
        }
      },
    );
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
      await getIt<SettingsService>().setWeatherLocation(pos.latitude, pos.longitude);
      // Fetch weather to trigger reverse geocoding for location name
      final data = await getIt<WeatherService>().fetch(pos.latitude, pos.longitude);
      if (data != null && data.locationName.isNotEmpty) {
        await getIt<SettingsService>().setWeatherLocationName(data.locationName);
      }
      if (mounted) {
        setState(() {});
        final name = getIt<SettingsService>().weatherLocationName;
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

}
