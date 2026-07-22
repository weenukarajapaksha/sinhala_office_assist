import 'package:flutter/material.dart';

import '../services/session_selection_controller.dart';
import '../services/theme_controller.dart';
import 'documents_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({required this.themeController, super.key});

  final ThemeController themeController;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final SessionSelectionController _selectionController =
      SessionSelectionController();
  int _index = 0;

  late final List<Widget> _screens = [
    HomeScreen(selectionController: _selectionController),
    DocumentsScreen(selectionController: _selectionController),
    SettingsScreen(themeController: widget.themeController),
  ];

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'පටිගත කිරීම්',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner_rounded),
            label: 'ලේඛන',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'සැකසුම්',
          ),
        ],
      ),
    );
  }
}
