import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/asset_item.dart';
import '../data/asset_catalog.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../service_locator.dart';
import '../widgets/model_viewer_widget.dart';
import 'model_viewer_screen.dart';

class AssetGalleryScreen extends StatefulWidget {
  const AssetGalleryScreen({super.key});

  @override
  State<AssetGalleryScreen> createState() => _AssetGalleryScreenState();
}

class _AssetGalleryScreenState extends State<AssetGalleryScreen> {
  String _selectedCategory = 'all';
  String? _selectedAssetId;

  @override
  void initState() {
    super.initState();
    _selectedAssetId = getIt<SettingsService>().selectedGrowthAsset;
  }

  List<AssetItem> get _filtered {
    if (_selectedCategory == 'all') return assetCatalog;
    return assetCatalog.where((a) => a.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('에셋 보관함'),
        centerTitle: true,
        actions: [
          if (_selectedAssetId != null)
            TextButton(
              onPressed: () {
                getIt<SettingsService>().setSelectedGrowthAsset('');
                setState(() => _selectedAssetId = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('성장 캐릭터가 해제되었습니다')),
                );
              },
              child: const Text('해제'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _categoryChip('all', '전체', '🌟'),
                ...AssetItem.categoryLabels.entries.map((e) =>
                  _categoryChip(e.key, e.value, AssetItem.categoryEmojis[e.key] ?? ''),
                ),
              ],
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_filtered.length}개 에셋',
                  style: TextStyle(fontSize: 12, color: AppColors.grey500),
                ),
                const Spacer(),
                if (_selectedAssetId != null)
                  Text(
                    '선택됨: ${assetCatalog.firstWhere((a) => a.id == _selectedAssetId, orElse: () => assetCatalog.first).nameKo}',
                    style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) => _buildAssetCard(_filtered[i], theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String key, String label, String emoji) {
    final selected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text('$emoji $label', style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategory = key),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildAssetCard(AssetItem asset, ThemeData theme) {
    final isSelected = _selectedAssetId == asset.id;
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _selectAsset(asset),
        onLongPress: () => _showAssetDetail(asset),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 2)
                : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji
              Text(asset.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 4),
              // Name
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    asset.nameKo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : null,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectAsset(AssetItem asset) {
    setState(() => _selectedAssetId = asset.id);
    getIt<SettingsService>().setSelectedGrowthAsset(asset.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${asset.emoji} ${asset.nameKo} 선택!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showAssetDetail(AssetItem asset) {
    final viewerUrl = asset.viewerUrl;
    showModalBottomSheet(
      context: context,
      isScrollControlled: viewerUrl != null,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (viewerUrl != null)
              SizedBox(
                height: 220,
                child: ModelViewerWidget(url: viewerUrl, height: 220),
              )
            else
              Text(asset.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(asset.nameKo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(asset.name, style: TextStyle(fontSize: 14, color: AppColors.grey500)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _infoBadge('출처', asset.source),
                const SizedBox(width: 12),
                _infoBadge('라이선스', asset.license),
                const SizedBox(width: 12),
                _infoBadge('카테고리', AssetItem.categoryLabels[asset.category] ?? asset.category),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (viewerUrl != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ModelViewerScreen(
                            url: viewerUrl,
                            title: asset.nameKo,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.fullscreen, size: 18),
                      label: const Text('전체 화면'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        const channel = MethodChannel('com.aicharacter.ai_character/usage_stats');
                        try {
                          await channel.invokeMethod('openUrl', {'url': asset.sourceUrl});
                        } catch (_) {}
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      label: const Text('3D 보기'),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _selectAsset(asset);
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('선택'),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom + 8),
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
