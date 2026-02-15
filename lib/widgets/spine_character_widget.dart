import 'dart:async';
import 'package:flutter/material.dart';
import 'package:spine_flutter/spine_flutter.dart';
import '../models/character_config.dart';
import '../models/character_state.dart';

/// Spine 2D character widget driven by CharacterConfig.
class SpineCharacterWidget extends StatefulWidget {
  final CharacterConfig config;
  final CharacterState state;
  final VoidCallback? onTap;
  final bool showBubble;

  const SpineCharacterWidget({
    super.key,
    required this.config,
    required this.state,
    this.onTap,
    this.showBubble = true,
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

  @override
  void initState() {
    super.initState();
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
      // Apply combined skins if specified
      if (widget.config.combineSkins.isNotEmpty) {
        final combined = Skin('combined');
        for (final skinName in widget.config.combineSkins) {
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

      // Find a valid idle animation
      final animations = controller.skeletonData.animations;
      final animNames = <String>[];
      for (int i = 0; i < animations.length; i++) {
        final name = animations[i]?.name;
        if (name != null) animNames.add(name);
      }

      String idleAnim = widget.config.idleAnimation;
      if (!animNames.contains(idleAnim) && animNames.isNotEmpty) {
        idleAnim = animNames.first;
      }

      controller.animationState.setAnimation(0, idleAnim, true);
      _currentAnimation = idleAnim;
      setState(() => _initialized = true);
      _applyState();
    } catch (e) {
      setState(() => _error = 'Init: $e\n$_debugInfo');
    }
  }

  void _onBeforeUpdate(SpineWidgetController controller) {
    if (!widget.config.supportsLipSync) return;
    if (_lipSyncTimer != null && _lipSyncTimer!.isActive) {
      final jaw = controller.skeleton.findBone('jaw');
      if (jaw != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final open = (now ~/ 150) % 2 == 0;
        jaw.pose.scaleY = open ? 1.3 : 1.0;
      }
    }
  }

  @override
  void didUpdateWidget(SpineCharacterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _applyState();
    }
  }

  void _applyState() {
    if (!_initialized || _controller == null) return;

    try {
      final config = widget.config;
      String targetAnimation;
      if (widget.state.gesture != 'idle') {
        targetAnimation =
            config.gestureAnimations[widget.state.gesture] ??
                config.idleAnimation;
      } else {
        targetAnimation =
            config.emotionAnimations[widget.state.emotion] ??
                config.idleAnimation;
      }

      // Verify animation exists, fallback to current if not
      final animations = _controller!.skeletonData.animations;
      final animNames = <String>[];
      for (int i = 0; i < animations.length; i++) {
        final name = animations[i]?.name;
        if (name != null) animNames.add(name);
      }
      if (!animNames.contains(targetAnimation)) {
        targetAnimation = _currentAnimation;
      }

      final shouldLoop =
          !config.oneShotAnimations.contains(targetAnimation);

      if (targetAnimation != _currentAnimation) {
        _currentAnimation = targetAnimation;
        if (shouldLoop) {
          _controller!.animationState
              .setAnimation(0, targetAnimation, true);
        } else {
          _controller!.animationState
              .setAnimation(0, targetAnimation, false);
          final fallbackIdle =
              animNames.contains(config.idleAnimation)
                  ? config.idleAnimation
                  : _currentAnimation;
          _controller!.animationState
              .addAnimation(0, fallbackIdle, true, 0);
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
            style: const TextStyle(color: Colors.red, fontSize: 10),
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
          style: const TextStyle(color: Colors.orange, fontSize: 12),
        ),
      );
    }

    // Determine BoundsProvider based on skin config
    final BoundsProvider boundsProvider;
    if (widget.config.combineSkins.isNotEmpty) {
      boundsProvider = SkinAndAnimationBounds(skins: widget.config.combineSkins);
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
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
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
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),

        if (widget.onTap != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.translucent,
            ),
          ),
      ],
    );
  }
}
