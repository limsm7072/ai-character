import 'dart:math';
import 'package:flutter/material.dart';
import 'package:spine_flutter/spine_flutter.dart';
import '../models/character_config.dart';
import '../models/character_state.dart';
import '../services/accessory_service.dart';
import '../widgets/spine_character_widget.dart';

/// Category label mapping for skin name prefixes.
const _categoryLabels = <String, String>{
  'full-skins': '전체 스타일',
  'clothes': '의상',
  'eyes': '눈',
  'eyelids': '눈꺼풀',
  'hair': '머리',
  'nose': '코',
  'accessories': '액세서리',
  'lips': '입술',
  'mouth': '입',
};

/// Formats a skin name for display (e.g., 'clothes/dress-blue' -> 'dress-blue').
String _skinDisplayName(String skinName) {
  final idx = skinName.indexOf('/');
  if (idx >= 0) return skinName.substring(idx + 1);
  return skinName;
}

class DressUpScreen extends StatefulWidget {
  final CharacterConfig config;
  final AccessoryService accessoryService;

  const DressUpScreen({
    super.key,
    required this.config,
    required this.accessoryService,
  });

  @override
  State<DressUpScreen> createState() => _DressUpScreenState();
}

class _DressUpScreenState extends State<DressUpScreen> {
  /// Discovered skin categories: { category -> [skin names] }
  Map<String, List<String>> _categories = {};

  /// Currently selected skin per category.
  final Map<String, String?> _selections = {};

  bool _loading = true;
  String? _error;
  String _selectedCategory = '';

  /// Currently active full-skin (null if using individual parts).
  String? _activeFullSkin;

  /// Preview animation name (null = idle).
  String? _previewAnimation;

  final _random = Random();

  @override
  void initState() {
    super.initState();
    _discoverSkins();
  }

  Future<void> _discoverSkins() async {
    try {
      final drawable = await SkeletonDrawableFlutter.fromAsset(
        widget.config.atlasAsset,
        widget.config.skelAsset,
      );

      final skins = drawable.skeletonData.skins;
      final categories = <String, List<String>>{};

      for (int i = 0; i < skins.length; i++) {
        final name = skins[i]?.name;
        if (name == null) continue;

        // Skip base skins
        if (widget.config.baseSkins.contains(name)) continue;
        // Skip 'default' skin
        if (name == 'default') continue;

        final slashIdx = name.indexOf('/');
        if (slashIdx > 0) {
          final category = name.substring(0, slashIdx);
          categories.putIfAbsent(category, () => []).add(name);
        } else {
          categories.putIfAbsent('base', () => []).add(name);
        }
      }

      drawable.dispose();

      // Reorder: put 'full-skins' first if it exists
      final orderedCategories = <String, List<String>>{};
      if (categories.containsKey('full-skins')) {
        orderedCategories['full-skins'] = categories['full-skins']!;
      }
      for (final entry in categories.entries) {
        if (entry.key != 'full-skins') {
          orderedCategories[entry.key] = entry.value;
        }
      }

      // Load saved selections
      final savedSkins = widget.accessoryService.getSelectedSkins(widget.config.id);
      for (final skinName in savedSkins) {
        if (widget.config.baseSkins.contains(skinName)) continue;
        final slashIdx = skinName.indexOf('/');
        if (slashIdx > 0) {
          final category = skinName.substring(0, slashIdx);
          if (category == 'full-skins') {
            _activeFullSkin = skinName;
          }
          _selections[category] = skinName;
        } else {
          _selections['base'] = skinName;
        }
      }

      // If no saved selections, use default combineSkins
      if (savedSkins.isEmpty && widget.config.combineSkins.isNotEmpty) {
        for (final skinName in widget.config.combineSkins) {
          if (widget.config.baseSkins.contains(skinName)) continue;
          final slashIdx = skinName.indexOf('/');
          if (slashIdx > 0) {
            final category = skinName.substring(0, slashIdx);
            _selections[category] = skinName;
          } else {
            _selections['base'] = skinName;
          }
        }
      }

      if (mounted) {
        setState(() {
          _categories = orderedCategories;
          _selectedCategory = orderedCategories.keys.isNotEmpty
              ? orderedCategories.keys.first
              : '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  List<String> _buildCurrentSkins() {
    if (_activeFullSkin != null) {
      // Full-skin mode: only base + full-skin
      return <String>[...widget.config.baseSkins, _activeFullSkin!];
    }
    final skins = <String>[...widget.config.baseSkins];
    for (final entry in _selections.entries) {
      if (entry.key == 'full-skins') continue; // Skip full-skins in part mode
      if (entry.value != null) skins.add(entry.value!);
    }
    return skins;
  }

  void _selectFullSkin(String skinName) {
    setState(() {
      _activeFullSkin = skinName;
      // Clear individual selections
      _selections.clear();
      _selections['full-skins'] = skinName;
    });
  }

  void _clearFullSkin() {
    setState(() {
      _activeFullSkin = null;
      _selections.remove('full-skins');
    });
  }

  void _selectPartSkin(String category, String? skinName) {
    setState(() {
      // Switching to part mode clears full-skin
      if (_activeFullSkin != null) {
        _activeFullSkin = null;
        _selections.remove('full-skins');
      }
      if (skinName == null) {
        _selections.remove(category);
      } else {
        _selections[category] = skinName;
      }
    });
  }

  void _randomOutfit() {
    setState(() {
      _activeFullSkin = null;
      _selections.clear();
      for (final entry in _categories.entries) {
        if (entry.key == 'full-skins') continue;
        if (entry.value.isNotEmpty) {
          _selections[entry.key] =
              entry.value[_random.nextInt(entry.value.length)];
        }
      }
    });
  }

  Future<void> _save() async {
    await widget.accessoryService.setSelectedSkins(
      widget.config.id,
      _buildCurrentSkins(),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('꾸미기')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('꾸미기')),
        body: Center(child: Text('오류: $_error')),
      );
    }

    if (_categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('꾸미기')),
        body: const Center(child: Text('이 캐릭터는 꾸미기 아이템이 없습니다')),
      );
    }

    final currentSkins = _buildCurrentSkins();

    return Scaffold(
      appBar: AppBar(
        title: const Text('꾸미기'),
        actions: [
          IconButton(
            onPressed: _randomOutfit,
            icon: const Text('🎲', style: TextStyle(fontSize: 22)),
            tooltip: '랜덤 코디',
          ),
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('저장'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Character preview
          SizedBox(
            height: 240,
            child: SpineCharacterWidget(
              key: ValueKey('dressup_${currentSkins.join("_")}_$_previewAnimation'),
              config: widget.config,
              state: const CharacterState(
                emotion: 'happy',
                gesture: 'idle',
              ),
              customSkins: currentSkins,
              showBubble: false,
              previewAnimation: _previewAnimation,
            ),
          ),

          // Animation preview buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAnimButton('idle', 'idle'),
                const SizedBox(width: 8),
                _buildAnimButton('dance', 'dance'),
                const SizedBox(width: 8),
                _buildAnimButton('walk', 'walk'),
              ],
            ),
          ),

          const Divider(height: 1),

          // Category chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _categories.keys.map((category) {
                final isSelected = category == _selectedCategory;
                final label = _categoryLabels[category] ?? category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Item grid
          Expanded(
            child: _buildItemGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimButton(String label, String animName) {
    final isActive = _previewAnimation == animName ||
        (_previewAnimation == null && animName == 'idle');
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _previewAnimation = animName == 'idle' ? null : animName;
        });
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        backgroundColor: isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        side: isActive
            ? BorderSide(color: Theme.of(context).colorScheme.primary)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildItemGrid() {
    final items = _categories[_selectedCategory] ?? [];
    final isFullSkinCategory = _selectedCategory == 'full-skins';
    final currentSelection = isFullSkinCategory
        ? _activeFullSkin
        : _selections[_selectedCategory];

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length + 1, // +1 for "none" option
      itemBuilder: (context, index) {
        if (index == 0) {
          final isSelected = isFullSkinCategory
              ? _activeFullSkin == null
              : currentSelection == null;
          return _buildItemCard(
            label: '없음',
            isSelected: isSelected,
            onTap: () {
              if (isFullSkinCategory) {
                _clearFullSkin();
              } else {
                _selectPartSkin(_selectedCategory, null);
              }
            },
          );
        }

        final skinName = items[index - 1];
        final isSelected = currentSelection == skinName;
        final displayName = _skinDisplayName(skinName);

        return _buildItemCard(
          label: displayName,
          isSelected: isSelected,
          onTap: () {
            if (isFullSkinCategory) {
              _selectFullSkin(skinName);
            } else {
              _selectPartSkin(_selectedCategory, skinName);
            }
          },
        );
      },
    );
  }

  Widget _buildItemCard({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
