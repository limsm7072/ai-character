import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/local_models.dart';
import '../services/coin_service.dart';
import '../services/purchase_service.dart';
import '../theme/app_colors.dart';
import '../service_locator.dart';
import 'model_shop_screen.dart';

class MyRoomScreen extends StatefulWidget {
  const MyRoomScreen({super.key});

  @override
  State<MyRoomScreen> createState() => _MyRoomScreenState();
}

class _MyRoomScreenState extends State<MyRoomScreen> {
  bool _loaded = false;
  String? _tappedModelName;
  MethodChannel? _channel;

  String get _roomUrl {
    final purchased = getIt<PurchaseService>().purchasedIds;
    final models = localModels.where((m) => purchased.contains(m.id)).toList();
    if (models.isEmpty) {
      return 'file:///android_asset/room.html#empty=1';
    }
    final fileNames = models.map((m) => m.fileName).join(',');
    final names = models.map((m) => Uri.encodeComponent(m.nameKo)).join(',');
    final animated = models.map((m) => m.animated ? '1' : '0').join(',');
    return 'file:///android_asset/room.html#models=$fileNames&names=$names&animated=$animated';
  }

  @override
  Widget build(BuildContext context) {
    final coins = getIt<CoinService>().balance;
    final purchasedCount = getIt<PurchaseService>().purchasedCount;

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('나의 룸'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _coinBadge(coins),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ModelShopScreen(),
              ));
              setState(() {}); // Refresh after possible purchase
            },
            icon: const Icon(Icons.storefront, color: Colors.white70),
            tooltip: '상점',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 3D Room WebView
          Positioned.fill(
            child: AndroidView(
              viewType: 'model-webview',
              key: ValueKey(_roomUrl),
              creationParams: {
                'url': _roomUrl,
                'bgColor': '#1a1a2e',
              },
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onPlatformViewCreated,
            ),
          ),

          // Loading overlay
          if (!_loaded)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF1a1a2e),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 36, height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '3D 공간 준비 중...',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Tapped model info card
          if (_tappedModelName != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _tappedModelName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom info bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewPadding.bottom + 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF1a1a2e).withValues(alpha: 0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '$purchasedCount/${localModels.length} 캐릭터',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ModelShopScreen(),
                      ));
                      setState(() {});
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('캐릭터 추가'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPlatformViewCreated(int viewId) {
    _channel = MethodChannel('model_webview_$viewId');
    _channel!.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onLoaded':
        case 'onSceneReady':
          if (mounted) setState(() => _loaded = true);
          break;
        case 'onModelTapped':
          final args = call.arguments as Map?;
          if (args != null && mounted) {
            setState(() => _tappedModelName = args['name'] as String?);
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _tappedModelName = null);
            });
          }
          break;
      }
    });
  }

  Widget _coinBadge(int balance) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, size: 16, color: AppColors.accent),
            const SizedBox(width: 4),
            Text('$balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }
}
