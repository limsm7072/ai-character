import 'dart:async';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Manages the overlay window for displaying the character.
class OverlayService {
  bool _isShowing = false;

  bool get isShowing => _isShowing;

  /// Check if overlay permission is granted.
  Future<bool> hasPermission() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  /// Request overlay permission.
  Future<bool> requestPermission() async {
    final result = await FlutterOverlayWindow.requestPermission();
    return result ?? false;
  }

  /// Show the overlay window with the character.
  Future<void> show({
    int width = 300,
    int height = 400,
    String? initialData,
  }) async {
    if (_isShowing) return;

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'AI Character',
      overlayContent: '',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: height,
      width: width,
    );
    _isShowing = true;

    // Send initial data after overlay has time to initialize
    if (initialData != null) {
      await Future.delayed(const Duration(milliseconds: 800));
      await FlutterOverlayWindow.shareData(initialData);
    }
  }

  /// Hide the overlay window.
  Future<void> hide() async {
    if (!_isShowing) return;
    await FlutterOverlayWindow.closeOverlay();
    _isShowing = false;
  }

  /// Send data to the overlay.
  Future<void> sendToOverlay(String data) async {
    await FlutterOverlayWindow.shareData(data);
  }

  /// Check if overlay is currently active.
  Future<bool> isOverlayActive() async {
    return await FlutterOverlayWindow.isActive();
  }
}
