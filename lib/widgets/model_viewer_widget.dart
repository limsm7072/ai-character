import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class ModelViewerWidget extends StatefulWidget {
  final String url;
  final String bgColor;
  final double? height;

  const ModelViewerWidget({
    super.key,
    required this.url,
    this.bgColor = '#1a1a2e',
    this.height,
  });

  @override
  State<ModelViewerWidget> createState() => _ModelViewerWidgetState();
}

class _ModelViewerWidgetState extends State<ModelViewerWidget> {
  bool _loaded = false;
  int _progress = 0;
  MethodChannel? _channel;

  @override
  Widget build(BuildContext context) {
    final viewerBox = SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          AndroidView(
            viewType: 'model-webview',
            creationParams: {
              'url': widget.url,
              'bgColor': widget.bgColor,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          ),
          if (!_loaded)
            Positioned.fill(
              child: Container(
                color: Color(0xFF1a1a2e),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          value: _progress > 0 ? _progress / 100 : null,
                          strokeWidth: 3,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _progress > 0
                            ? '3D 모델 로딩 중... $_progress%'
                            : '3D 모델 로딩 중...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: viewerBox,
    );
  }

  void _onPlatformViewCreated(int viewId) {
    _channel = MethodChannel('model_webview_$viewId');
    _channel!.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onLoaded':
          if (mounted) setState(() => _loaded = true);
          break;
        case 'onProgress':
          final p = call.arguments as int? ?? 0;
          if (mounted) setState(() => _progress = p);
          break;
      }
    });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }
}
