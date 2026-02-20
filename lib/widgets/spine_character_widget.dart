import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:spine_flutter/spine_flutter.dart';
import '../models/character_config.dart';
import '../models/character_state.dart';
import '../theme/app_colors.dart';

/// Spine 2D character widget driven by CharacterConfig.
class SpineCharacterWidget extends StatefulWidget {
  final CharacterConfig config;
  final CharacterState state;
  final VoidCallback? onTap;
  final bool showBubble;
  final List<String>? customSkins;
  final Map<String, int>? customColors;
  final bool interactive;
  final String? previewAnimation;

  const SpineCharacterWidget({
    super.key,
    required this.config,
    required this.state,
    this.onTap,
    this.showBubble = true,
    this.customSkins,
    this.customColors,
    this.interactive = false,
    this.previewAnimation,
  });

  @override
  State<SpineCharacterWidget> createState() => _SpineCharacterWidgetState();
}

class _SpineCharacterWidgetState extends State<SpineCharacterWidget> {
  SpineWidgetController? _controller;
  SkeletonDrawableFlutter? _drawable;
  bool _initialized = false;
  bool _loading = true;
  String _currentAnimation = '';
  Timer? _lipSyncTimer;
  String? _error;
  String _debugInfo = '';

  // Blink state
  final _random = Random();
  double _nextBlinkTime = 0;
  double _blinkTimer = 0;
  bool _isBlinking = false;
  double _blinkElapsed = 0;
  static const _blinkDuration = 0.15; // seconds

  // Random idle variation
  Timer? _idleVariationTimer;
  bool _isPlayingVariation = false;

  // Touch cooldown
  DateTime _lastTapTime = DateTime(2000);

  // Available animations (cached)
  List<String> _availableAnimations = [];


  @override
  void initState() {
    super.initState();
    _nextBlinkTime = 3.0 + _random.nextDouble() * 3.0;
    _loadSkeleton();
  }

  Future<void> _loadSkeleton() async {
    try {
      final drawable = await SkeletonDrawableFlutter.fromAsset(
        widget.config.atlasAsset,
        widget.config.skelAsset,
      );

      if (!mounted) {
        drawable.dispose();
        return;
      }

      // Collect debug info
      final skeletonData = drawable.skeletonData;
      final skins = skeletonData.skins;
      final skinNames = <String>[];
      for (int i = 0; i < skins.length; i++) {
        skinNames.add(skins[i]?.name ?? '(null)');
      }

      final animations = skeletonData.animations;
      final animNames = <String>[];
      for (int i = 0; i < animations.length; i++) {
        animNames.add(animations[i]?.name ?? '(null)');
      }

      _debugInfo =
          'ID: ${widget.config.id}\n'
          'Skins: ${skinNames.join(", ")}\n'
          'Anims: ${animNames.join(", ")}';

      _drawable = drawable;
      _controller = SpineWidgetController(
        onInitialized: _onSpineInitialized,
        onBeforeUpdateWorldTransforms: _onBeforeUpdate,
      );

      setState(() => _loading = false);
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e\n$st';
        });
      }
    }
  }

  void _onSpineInitialized(SpineWidgetController controller) {
    try {
      // Apply custom skins (from dress-up) or default combined skins
      final skinsToApply = widget.customSkins ??
          (widget.config.combineSkins.isNotEmpty ? widget.config.combineSkins : null);

      if (skinsToApply != null && skinsToApply.isNotEmpty) {
        final combined = Skin('combined');
        for (final skinName in skinsToApply) {
          final skin = controller.skeletonData.findSkin(skinName);
          if (skin != null) {
            combined.addSkin(skin);
          }
        }
        controller.skeleton.setSkin2(combined);
        controller.skeleton.setupPoseSlots();
      } else if (widget.config.defaultSkin != null) {
        controller.skeleton.setSkin(widget.config.defaultSkin!);
        controller.skeleton.setupPoseSlots();
      }

      controller.animationState.data.defaultMix = 0.2;

      // Cache available animations
      final animations = controller.skeletonData.animations;
      _availableAnimations = [];
      for (int i = 0; i < animations.length; i++) {
        final name = animations[i]?.name;
        if (name != null) _availableAnimations.add(name);
      }

      String idleAnim = widget.config.idleAnimation;
      if (!_availableAnimations.contains(idleAnim) && _availableAnimations.isNotEmpty) {
        idleAnim = _availableAnimations.first;
      }

      controller.animationState.setAnimation(0, idleAnim, true);
      _currentAnimation = idleAnim;
      setState(() => _initialized = true);

      // Apply preview animation if set, otherwise apply state
      if (widget.previewAnimation != null) {
        _applyPreviewAnimation();
      } else {
        _applyState();
      }

      // Start idle variation timer if interactive
      _startIdleVariationTimer();
    } catch (e) {
      setState(() => _error = 'Init: $e\n$_debugInfo');
    }
  }

  void _onBeforeUpdate(SpineWidgetController controller) {
    const dt = 0.016;
    // Lip sync
    if (widget.config.supportsLipSync &&
        _lipSyncTimer != null && _lipSyncTimer!.isActive) {
      final jaw = controller.skeleton.findBone('jaw');
      if (jaw != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final open = (now ~/ 150) % 2 == 0;
        jaw.pose.scaleY = open ? 1.3 : 1.0;
      }
    }

    // Auto-blink
    _updateBlink(controller);

    // Slot color tinting
    _applySlotColors(controller);
  }

  // --- Slot color tinting ---

  static String? _categorizeSlot(String slotName) {
    final lower = slotName.toLowerCase();
    if (lower.contains('eye-iris')) return 'eyes';
    // Skip eye-white, eyelid, eyebrow, pupil — tinting looks wrong
    if (lower.contains('eye')) return null;
    if (lower.contains('hair')) return 'hair';
    if (lower.contains('arm') || lower.contains('leg') ||
        lower.contains('head') || lower.contains('hand') ||
        lower.contains('ear') || lower.contains('nose') ||
        lower.contains('neck') || lower.contains('finger')) return 'skin';
    if (lower.contains('body') || lower.contains('dress') ||
        lower.contains('sleeve') || lower.contains('collar') ||
        lower.contains('cape') || lower.contains('skirt') ||
        lower.contains('bag') || lower.contains('scarf') ||
        lower.contains('zip') || lower.contains('ribbon') ||
        lower.contains('cloak') || lower.contains('boot') ||
        lower.contains('hat') || lower.contains('pompom') ||
        lower.contains('backpack') || lower.contains('pocket')) return 'clothes';
    return null;
  }

  void _applySlotColors(SpineWidgetController controller) {
    final colors = widget.customColors;
    if (colors == null || colors.isEmpty) return;

    final skeleton = controller.skeleton;
    final slots = skeleton.slots;
    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (slot == null) continue;
      final category = _categorizeSlot(slot.data.name);
      if (category == null) continue;
      final colorInt = colors[category];
      if (colorInt == null) continue;

      final r = ((colorInt >> 16) & 0xFF) / 255.0;
      final g = ((colorInt >> 8) & 0xFF) / 255.0;
      final b = (colorInt & 0xFF) / 255.0;
      slot.pose.color.set(r, g, b, slot.pose.color.a);
    }
  }

  void _updateBlink(SpineWidgetController controller) {
    // Use a rough 16ms delta (60fps)
    const dt = 0.016;
    _blinkTimer += dt;

    if (_isBlinking) {
      _blinkElapsed += dt;
      // Try to find eyelid-related bones for blinking
      final eyelidLeft = controller.skeleton.findBone('eyelid-left');
      final eyelidRight = controller.skeleton.findBone('eyelid-right');

      if (_blinkElapsed < _blinkDuration) {
        // Close eyes
        eyelidLeft?.pose.scaleY = 0.1;
        eyelidRight?.pose.scaleY = 0.1;
      } else {
        // Open eyes
        eyelidLeft?.pose.scaleY = 1.0;
        eyelidRight?.pose.scaleY = 1.0;
        _isBlinking = false;
        _blinkElapsed = 0;
        _blinkTimer = 0;
        _nextBlinkTime = 3.0 + _random.nextDouble() * 3.0;
      }
    } else if (_blinkTimer >= _nextBlinkTime) {
      _isBlinking = true;
      _blinkElapsed = 0;
    }
  }

  void _startIdleVariationTimer() {
    _idleVariationTimer?.cancel();
    if (!widget.interactive) return;

    _scheduleNextIdleVariation();
  }

  void _scheduleNextIdleVariation() {
    final delay = 10 + _random.nextInt(11); // 10~20 seconds
    _idleVariationTimer = Timer(Duration(seconds: delay), () {
      if (!mounted || !_initialized || _controller == null) return;
      if (_isPlayingVariation) return;

      // Only do variation if currently in idle state
      final idleAnim = widget.config.idleAnimation;
      if (_currentAnimation != idleAnim) {
        _scheduleNextIdleVariation();
        return;
      }

      // Pick a random variation: aware or dance (one-shot)
      final variations = <String>[];
      if (_availableAnimations.contains('aware')) variations.add('aware');
      if (_availableAnimations.contains('dance')) variations.add('dance');

      if (variations.isEmpty) {
        _scheduleNextIdleVariation();
        return;
      }

      final picked = variations[_random.nextInt(variations.length)];
      _isPlayingVariation = true;

      _controller!.animationState.setAnimation(0, picked, false);
      _controller!.animationState.addAnimation(0, idleAnim, true, 0);
      _currentAnimation = idleAnim; // Will return to idle

      // Reset variation flag after a reasonable time
      Timer(const Duration(seconds: 3), () {
        _isPlayingVariation = false;
        if (mounted) _scheduleNextIdleVariation();
      });
    });
  }

  void _handleTap() {
    if (!widget.interactive) return;
    if (!_initialized || _controller == null) return;

    // Cooldown check (1 second)
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 1000) return;
    _lastTapTime = now;

    // Pick random reaction from available non-idle animations
    final reactions = <String>[];
    for (final anim in ['dance', 'dress-up', 'aware']) {
      if (_availableAnimations.contains(anim)) reactions.add(anim);
    }
    if (reactions.isEmpty) return;

    final picked = reactions[_random.nextInt(reactions.length)];
    final idleAnim = widget.config.idleAnimation;

    _controller!.animationState.setAnimation(0, picked, false);
    _controller!.animationState.addAnimation(0, idleAnim, true, 0);
    _currentAnimation = idleAnim;
  }

  @override
  void didUpdateWidget(SpineCharacterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.previewAnimation != widget.previewAnimation &&
        widget.previewAnimation != null) {
      _applyPreviewAnimation();
    } else if (oldWidget.state != widget.state) {
      _applyState();
    }

    // Restart idle variation if interactive changed
    if (oldWidget.interactive != widget.interactive) {
      _startIdleVariationTimer();
    }
  }

  void _applyPreviewAnimation() {
    if (!_initialized || _controller == null) return;
    final anim = widget.previewAnimation;
    if (anim == null || !_availableAnimations.contains(anim)) return;

    final isOneShot = widget.config.oneShotAnimations.contains(anim);
    _controller!.animationState.setAnimation(0, anim, !isOneShot);
    _currentAnimation = anim;

    if (isOneShot) {
      final idleAnim = widget.config.idleAnimation;
      _controller!.animationState.addAnimation(0, idleAnim, true, 0);
      _currentAnimation = idleAnim;
    }
  }

  void _applyState() {
    if (!_initialized || _controller == null) return;

    try {
      final config = widget.config;
      String targetAnimation;
      double timeScale = 1.0;

      if (widget.state.gesture != 'idle') {
        targetAnimation =
            config.gestureAnimations[widget.state.gesture] ??
                config.idleAnimation;
        timeScale = config.gestureAnimationSpeeds[widget.state.gesture] ?? 1.0;
      } else {
        targetAnimation =
            config.emotionAnimations[widget.state.emotion] ??
                config.idleAnimation;
        timeScale = config.emotionAnimationSpeeds[widget.state.emotion] ?? 1.0;
      }

      // Verify animation exists, fallback to current if not
      if (!_availableAnimations.contains(targetAnimation)) {
        targetAnimation = _currentAnimation;
      }

      final shouldLoop =
          !config.oneShotAnimations.contains(targetAnimation);

      if (targetAnimation != _currentAnimation) {
        _currentAnimation = targetAnimation;
        if (shouldLoop) {
          final entry = _controller!.animationState
              .setAnimation(0, targetAnimation, true);
          entry.timeScale = timeScale;
        } else {
          final entry = _controller!.animationState
              .setAnimation(0, targetAnimation, false);
          entry.timeScale = timeScale;
          final fallbackIdle =
              _availableAnimations.contains(config.idleAnimation)
                  ? config.idleAnimation
                  : _currentAnimation;
          _controller!.animationState
              .addAnimation(0, fallbackIdle, true, 0);
        }
      } else if (timeScale != 1.0) {
        // Same animation but different speed — update timeScale
        final current = _controller!.animationState.getCurrent(0);
        if (current != null) {
          current.timeScale = timeScale;
        }
      }
    } catch (e) {
      setState(() => _error = 'Apply: $e');
    }

    _stopLipSync();
    if (widget.state.text.isNotEmpty && widget.config.supportsLipSync) {
      _startLipSync(widget.state.text);
    }
  }

  void _startLipSync(String text) {
    final durationMs = text.length * 80;
    _lipSyncTimer = Timer(Duration(milliseconds: durationMs), () {
      _stopLipSync();
    });
  }

  void _stopLipSync() {
    _lipSyncTimer?.cancel();
    _lipSyncTimer = null;
  }

  @override
  void dispose() {
    _stopLipSync();
    _idleVariationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Error: $_error\n\n$_debugInfo',
            style: const TextStyle(color: AppColors.error, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_drawable == null || _controller == null) {
      return Center(
        child: Text(
          'Failed to load: ${widget.config.id}',
          style: const TextStyle(color: AppColors.warning, fontSize: 12),
        ),
      );
    }

    // Determine BoundsProvider based on skin config
    final BoundsProvider boundsProvider;
    final activeSkins = widget.customSkins ?? widget.config.combineSkins;
    if (activeSkins.isNotEmpty) {
      boundsProvider = SkinAndAnimationBounds(skins: activeSkins);
    } else if (widget.config.defaultSkin != null) {
      boundsProvider = SkinAndAnimationBounds(skins: [widget.config.defaultSkin!]);
    } else {
      boundsProvider = const SetupPoseBounds();
    }

    return Stack(
      children: [
        SpineWidget.fromDrawable(
          _drawable!,
          _controller!,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          boundsProvider: boundsProvider,
        ),

        if (!_initialized)
          const Center(child: CircularProgressIndicator()),

        if (widget.showBubble && widget.state.text.isNotEmpty)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.state.text,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.black87,
                  ),
                ),
              ),
            ),
          ),

        // Tap handler: interactive touch or custom onTap
        if (widget.interactive || widget.onTap != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.interactive ? _handleTap : widget.onTap,
              behavior: HitTestBehavior.translucent,
            ),
          ),
      ],
    );
  }
}
