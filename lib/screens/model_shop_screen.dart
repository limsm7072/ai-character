import 'package:flutter/material.dart';
import '../data/local_models.dart';
import '../services/coin_service.dart';
import '../services/purchase_service.dart';
import '../widgets/model_viewer_widget.dart';
import '../theme/app_colors.dart';
import '../service_locator.dart';

class ModelShopScreen extends StatefulWidget {
  const ModelShopScreen({super.key});

  @override
  State<ModelShopScreen> createState() => _ModelShopScreenState();
}

class _ModelShopScreenState extends State<ModelShopScreen> {
  String _category = 'all';

  List<LocalModel> get _filtered {
    if (_category == 'all') return localModels;
    return localModels.where((m) => m.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coins = getIt<CoinService>().balance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('상점'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _coinBadge(coins),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _catChip('all', '전체', '🌟'),
                _catChip('character', '캐릭터', '👤'),
                _catChip('deco', '방꾸미기', '🪑'),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) => _buildShopCard(_filtered[i], theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catChip(String key, String label, String emoji) {
    final selected = _category == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text('$emoji $label', style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        selected: selected,
        onSelected: (_) => setState(() => _category = key),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildShopCard(LocalModel model, ThemeData theme) {
    final purchased = getIt<PurchaseService>().isPurchased(model.id);
    return Material(
      color: purchased
          ? AppColors.primary.withValues(alpha: 0.08)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showDetail(model),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: purchased
                ? Border.all(color: AppColors.primary, width: 1.5)
                : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(model.emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                model.nameKo,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: purchased ? AppColors.primary : null,
                ),
              ),
              const SizedBox(height: 4),
              if (model.animated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ANIMATED',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.info, letterSpacing: 0.3),
                  ),
                ),
              const Spacer(),
              if (purchased)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('구매 완료', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monetization_on, size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        '${model.price}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(LocalModel model) {
    final purchased = getIt<PurchaseService>().isPurchased(model.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 3D Preview
            SizedBox(
              height: 220,
              child: ModelViewerWidget(url: model.viewerUrl, height: 220),
            ),
            const SizedBox(height: 16),
            Text(
              '${model.emoji} ${model.nameKo}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(model.name, style: TextStyle(fontSize: 13, color: AppColors.grey500)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _infoBadge('출처', model.source),
                const SizedBox(width: 12),
                _infoBadge('애니메이션', model.animated ? 'O' : 'X'),
              ],
            ),
            const SizedBox(height: 20),
            if (purchased)
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('이미 구매함'),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmPurchase(model);
                  },
                  icon: Icon(Icons.monetization_on, size: 18, color: Colors.white),
                  label: Text('${model.price} 코인으로 구매'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _confirmPurchase(LocalModel model) {
    final coins = getIt<CoinService>().balance;
    if (coins < model.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('코인이 부족합니다 (현재: $coins코인)')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구매 확인'),
        content: Text('${model.emoji} ${model.nameKo}를 ${model.price}코인에 구매하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await getIt<PurchaseService>().purchase(model.id, model.price);
              if (ok) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${model.emoji} ${model.nameKo}를 구매했습니다! 나의 룸에서 확인하세요')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('구매에 실패했습니다')),
                );
              }
            },
            child: const Text('구매'),
          ),
        ],
      ),
    );
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

  Widget _infoBadge(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.grey400)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
