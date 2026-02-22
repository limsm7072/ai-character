import 'package:flutter/material.dart';
import '../widgets/model_viewer_widget.dart';

class ModelViewerScreen extends StatelessWidget {
  final String url;
  final String title;

  const ModelViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ModelViewerWidget(url: url),
    );
  }
}
