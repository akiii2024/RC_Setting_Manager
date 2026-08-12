import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/saved_setting.dart';
import '../providers/settings_provider.dart';
import 'car_selection_page.dart';
import 'car_setting_page.dart';
import 'history_page.dart';
import 'my_garage_page.dart';
import 'quick_run_log_page.dart';
import 'tools_page.dart';

part 'home_page_dashboard.dart';
part 'home_page_shared_widgets.dart';

const _blueShiftGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF005BCF),
    Color(0xFF1A73E8),
  ],
);

String _t(bool isEnglish, String en, String ja) => isEnglish ? en : ja;

String _formatDate(DateTime date, bool isEnglish) {
  if (isEnglish) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  return '${date.year}/${date.month}/${date.day}';
}

void _openSettingEditor(BuildContext context, SavedSetting setting) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CarSettingPage(
        originalCar: setting.car,
        savedSettings: setting.settings,
        settingName: setting.name,
        savedSettingId: setting.id,
      ),
    ),
  );
}

void _openCarSelection(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const CarSelectionPage(),
    ),
  );
}

void _openCarEditor(BuildContext context, Car car) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CarSettingPage(originalCar: car),
    ),
  );
}

void _openQuickRunLog(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const QuickRunLogPage(),
    ),
  );
}

void _showCreateActionSheet(BuildContext context, bool isEnglish) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: Text(_t(isEnglish, 'Create Setting', '設定作成')),
                subtitle: Text(_t(
                  isEnglish,
                  'Create or edit a setup sheet.',
                  'セッティングシートを作成・編集します。',
                )),
                onTap: () {
                  Navigator.pop(context);
                  _openCarSelection(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_rounded),
                title: Text(_t(isEnglish, 'Run Memo', '走行メモ')),
                subtitle: Text(_t(
                  isEnglish,
                  'Record lap time, feel, and setup changes.',
                  'タイム、感触、変更点をすばやく記録します。',
                )),
                onTap: () {
                  Navigator.pop(context);
                  _openQuickRunLog(context);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return const _DashboardHomeTab();
      case 1:
        return const MyGaragePage(embedded: true);
      case 2:
        return const HistoryPage();
      case 3:
        return const ToolsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  String _pageTitle(bool isEnglish) {
    return switch (_selectedIndex) {
      0 => _t(isEnglish, 'Home', 'ホーム'),
      1 => _t(isEnglish, 'My Garage', 'マイガレージ'),
      2 => _t(isEnglish, 'History', '履歴'),
      3 => _t(isEnglish, 'Tools', 'ツール'),
      _ => 'ENGINEERING PRECISION',
    };
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Text(
          _pageTitle(isEnglish),
          style: _selectedIndex == 0
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                )
              : theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: _t(isEnglish, 'Settings', '設定'),
          ),
        ],
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: _t(isEnglish, 'Home', 'ホーム'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.garage_outlined),
            selectedIcon: const Icon(Icons.garage_rounded),
            label: _t(isEnglish, 'Garage', 'ガレージ'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            selectedIcon: const Icon(Icons.history_toggle_off_rounded),
            label: _t(isEnglish, 'History', '履歴'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.build_outlined),
            selectedIcon: const Icon(Icons.build_rounded),
            label: _t(isEnglish, 'Tools', 'ツール'),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 || _selectedIndex == 1
          ? _GradientFab(
              tooltip: _t(isEnglish, 'Add', '追加'),
              onTap: () => _showCreateActionSheet(context, isEnglish),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
