import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_state.dart';
import '../models/character_config.dart';
import '../models/character_registry.dart';
import 'spine_character_widget.dart';

/// The overlay entry point widget.
/// This is displayed as a system overlay when the user is distracted.
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
  late AnimationController _entranceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  String _debugCharId = '';
  String _debugSource = '';

  @override
  void initState() {
    super.initState();
    _config = CharacterRegistry.getById(widget.initialCharacterId);
    _debugCharId = widget.initialCharacterId;
    _debugSource = 'init';

    // Also try reading SharedPreferences directly with reload
    _loadCharacterFromPrefs();

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

    // Listen for data from the main app
    FlutterOverlayWindow.overlayListener.listen((data) {
      print('[OVERLAY] Received data: $data');
      if (data is String && data.isNotEmpty) {
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final state = CharacterState.fromJson(json);
          final charId = state.characterId ?? 'chibi-stickers';
          print('[OVERLAY] Parsed characterId=$charId');
          setState(() {
            _state = state;
            _config = CharacterRegistry.getById(charId);
            _debugCharId = charId;
            _debugSource = 'stream';
          });
          _entranceController.forward(from: 0);
        } catch (e) {
          print('[OVERLAY] Parse error: $e');
          setState(() {
            _debugSource = 'error: $e';
          });
        }
      }
    });

    _entranceController.forward();
  }

  Future<void> _loadCharacterFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Force fresh read from disk
      final id = prefs.getString('selected_character') ?? 'chibi-stickers';
      print('[OVERLAY] SharedPrefs characterId=$id');
      if (mounted) {
        setState(() {
          _config = CharacterRegistry.getById(id);
          _debugCharId = id;
          _debugSource = 'prefs';
        });
      }
    } catch (e) {
      print('[OVERLAY] SharedPrefs error: $e');
    }
  }

  @override
  void dispose() {
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  SpineCharacterWidget(
                    key: ValueKey(_config.id),
                    config: _config,
                    state: _state,
                  ),
                  // Debug indicator - shows which character is loaded
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'CHAR: $_debugCharId\nSRC: $_debugSource',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
