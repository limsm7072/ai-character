import 'package:flutter/material.dart';
import '../data/local_models.dart';
import '../widgets/model_viewer_widget.dart';
import '../theme/app_colors.dart';

class LocalModelScreen extends StatefulWidget {
  const LocalModelScreen({super.key});

  @override
  State<LocalModelScreen> createState() => _LocalModelScreenState();
}

class _LocalModelScreenState extends State<LocalModelScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final model = localModels[_selectedIndex];
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('3D 모델'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 3D Viewer
          Expanded(
            child: ModelViewerWidget(
              key: ValueKey(model.id),
              url: model.viewerUrl,
            ),
          ),
          // Model info
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                Text(
                  '${model.emoji} ${model.nameKo}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      model.name,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    if (model.animated) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ANIMATED',
                          style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Model selector
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: localModels.length,
              itemBuilder: (ctx, i) {
                final m = localModels[i];
                final selected = i == _selectedIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(m.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 2),
                        Text(
                          m.nameKo,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white54,
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 8),
        ],
      ),
    );
  }
}
