import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spine_flutter/spine_flutter.dart';
import 'screens/home_screen.dart';
import 'services/routine_service.dart';
import 'services/settings_service.dart';
import 'services/gemini_service.dart';
import 'services/tts_service.dart';
import 'services/overlay_service.dart';
import 'services/app_detection_service.dart';
import 'services/character_controller.dart';
import 'services/routine_monitor.dart';
import 'services/distraction_log_service.dart';
import 'services/routine_completion_service.dart';
import 'services/accessory_service.dart';
import 'widgets/overlay_character.dart';

/// Entry point for the overlay window (displayed on top of other apps).
@pragma('vm:entry-point')
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSpineFlutter(enableMemoryDebugging: false);

  // Read selected character before creating widget
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // Force fresh read from disk
  final characterId = prefs.getString('selected_character') ?? 'chibi-stickers';
  print('[OVERLAY] overlayMain characterId=$characterId');

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayCharacter(initialCharacterId: characterId),
  ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSpineFlutter(enableMemoryDebugging: false);

  final prefs = await SharedPreferences.getInstance();
  final routineService = RoutineService(prefs);
  final settingsService = SettingsService(prefs);
  final distractionLogService = DistractionLogService(prefs);
  final completionService = RoutineCompletionService(prefs);
  final accessoryService = AccessoryService(prefs);

  final geminiService = GeminiService();
  final ttsService = TtsService();
  final overlayService = OverlayService();
  final appDetectionService = AppDetectionService();

  final apiKey = settingsService.apiKey;
  if (apiKey.isNotEmpty) {
    geminiService.initialize(apiKey);
  }

  await ttsService.initialize();
  await ttsService.applyPreset(settingsService.voicePreset);

  final characterController = CharacterController(
    gemini: geminiService,
    tts: ttsService,
    overlay: overlayService,
    settings: settingsService,
    completionService: completionService,
  );

  final routineMonitor = RoutineMonitor(
    routineService: routineService,
    appDetection: appDetectionService,
    characterController: characterController,
    completionService: completionService,
  );

  runApp(AiCharacterApp(
    routineService: routineService,
    settingsService: settingsService,
    routineMonitor: routineMonitor,
    appDetection: appDetectionService,
    distractionLogService: distractionLogService,
    completionService: completionService,
    ttsService: ttsService,
    accessoryService: accessoryService,
  ));
}

class AiCharacterApp extends StatefulWidget {
  final RoutineService routineService;
  final SettingsService settingsService;
  final RoutineMonitor routineMonitor;
  final AppDetectionService appDetection;
  final DistractionLogService distractionLogService;
  final RoutineCompletionService completionService;
  final TtsService ttsService;
  final AccessoryService accessoryService;

  const AiCharacterApp({
    super.key,
    required this.routineService,
    required this.settingsService,
    required this.routineMonitor,
    required this.appDetection,
    required this.distractionLogService,
    required this.completionService,
    required this.ttsService,
    required this.accessoryService,
  });

  @override
  State<AiCharacterApp> createState() => _AiCharacterAppState();
}

class _AiCharacterAppState extends State<AiCharacterApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionsAndStart();
  }

  Future<void> _requestPermissionsAndStart() async {
    // Request notification permission (Android 13+)
    const channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
    try {
      await channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}

    // Small delay to let permission dialog complete
    await Future.delayed(const Duration(seconds: 1));

    // Start monitoring
    await widget.routineMonitor.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.routineMonitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 루틴 잔소리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: HomeScreen(
        routineService: widget.routineService,
        settingsService: widget.settingsService,
        appDetection: widget.appDetection,
        distractionLogService: widget.distractionLogService,
        completionService: widget.completionService,
        ttsService: widget.ttsService,
        accessoryService: widget.accessoryService,
        onCompletionUnchecked: widget.routineMonitor.forceCheck,
      ),
    );
  }
}
