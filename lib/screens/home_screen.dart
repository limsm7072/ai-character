import 'package:flutter/material.dart';
import '../service_locator.dart';
import '../services/settings_service.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'character_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onCompletionUnchecked;

  const HomeScreen({
    super.key,
    this.onCompletionUnchecked,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _dashboardKey = GlobalKey<DashboardScreenState>();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            key: _dashboardKey,
            onCompletionUnchecked: widget.onCompletionUnchecked,
          ),
          CharacterChatScreen(
            onRoutinesChanged: () => _dashboardKey.currentState?.refresh(),
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if (i == 0) _dashboardKey.currentState?.refresh();
          setState(() => _currentIndex = i);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home), label: '홈'),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: getIt<SettingsService>().characterName,
          ),
          const NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    ),
    );
  }
}
