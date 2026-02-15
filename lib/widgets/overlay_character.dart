import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_state.dart';
import '../models/character_config.dart';
import '../models/character_registry.dart';
import '../services/accessory_service.dart';
import 'spine_character_widget.dart';


/// The overlay entry point widget.
/// Displayed as a system overlay when the user is distracted.
/// Reads nag state from SharedPreferences (written by native NagOverlay).
class OverlayCharacter extends StatefulWidget {
  final String initialCharacterId;

  const OverlayCharacter({
    super.key,
    this.initialCharacterId = 'chibi-stickers',
  });

  @override
  State<OverlayCharacter> createState() => _OverlayCharacterState();
}

class _OverlayCharacterState extends State<OverlayCharacter>
    with SingleTickerProviderStateMixin {
  CharacterState _state = const CharacterState();
  late CharacterConfig _config;
  List<String>? _customSkins;
  late AnimationController _entranceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _config = CharacterRegistry.getById(widget.initialCharacterId);

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.5),
      ),
    );

    // Read initial state from SharedPreferences
    _loadStateFromPrefs();

    // Poll SharedPreferences for updates from native NagOverlay
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _loadStateFromPrefs();
    });

    // Also listen for data from Flutter's shareData (backup channel)
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is String && data.isNotEmpty) {
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          _applyState(json);
        } catch (_) {}
      }
    });

    _entranceController.forward();
  }

  String _lastNagState = '';

  Future<void> _loadStateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      // Read nag state written by native NagOverlay
      final nagState = prefs.getString('nag_state') ?? '';
      if (nagState.isNotEmpty && nagState != _lastNagState) {
        _lastNagState = nagState;
        final json = jsonDecode(nagState) as Map<String, dynamic>;
        _applyState(json);
      }

      // Also check character selection (in case nag_state doesn't have it yet)
      final charId = prefs.getString('selected_character') ?? 'chibi-stickers';
      if (charId != _config.id && _lastNagState.isEmpty) {
        if (mounted) {
          setState(() {
            _config = CharacterRegistry.getById(charId);
          });
        }
      }

      // Load custom skins
      final accessory = AccessoryService(prefs);
      final skins = accessory.getSelectedSkins(_config.id);
      if (mounted && skins.isNotEmpty) {
        final changed = _customSkins == null ||
            _customSkins!.length != skins.length ||
            _customSkins!.join(',') != skins.join(',');
        if (changed) {
          setState(() => _customSkins = skins);
        }
      }
    } catch (_) {}
  }

  void _applyState(Map<String, dynamic> json) {
    if (!mounted) return;
    final state = CharacterState.fromJson(json);
    final charId = state.characterId ?? _config.id;
    final newConfig = CharacterRegistry.getById(charId);

    setState(() {
      _state = state;
      if (newConfig.id != _config.id) {
        _config = newConfig;
      }
    });

    // Re-trigger entrance animation on new text
    if (state.text.isNotEmpty) {
      _entranceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: () async {
              await FlutterOverlayWindow.closeOverlay();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SpineCharacterWidget(
                key: ValueKey('${_config.id}_${_customSkins?.join("_") ?? ""}'),
                config: _config,
                state: _state,
                showBubble: false,
                customSkins: _customSkins,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
