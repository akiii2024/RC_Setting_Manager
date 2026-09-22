import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/saved_setting.dart';
import '../models/settings_operation_result.dart';
import '../providers/settings_provider.dart';
import '../repositories/tutorial_preferences_repository.dart';
import '../utils/app_logger.dart';
import '../utils/settings_operation_feedback.dart';
import '../widgets/tutorial_overlay.dart';
import 'car_selection_page.dart';
import 'car_setting_page.dart';
import 'history_page.dart';
import 'my_garage_page.dart';
import 'quick_run_log_page.dart';
import 'quick_run_log_launcher_page.dart';
import 'tools_page.dart';

part 'home_page_dashboard.dart';
part 'home_page_shared_widgets.dart';

LinearGradient _expressiveGradient(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      colorScheme.primary,
      colorScheme.secondary,
    ],
  );
}

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

void _openTelemetryRunLog(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const QuickRunLogLauncherPage(),
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
              ListTile(
                leading: const Icon(Icons.monitor_heart_rounded),
                title: Text(_t(
                  isEnglish,
                  'Run Memo with Telemetry',
                  'テレメトリー付き走行メモ',
                )),
                subtitle: Text(_t(
                  isEnglish,
                  'Attach and preview SANWA data before recording the memo.',
                  'SANWAデータを添付・確認してから走行メモを記録します。',
                )),
                onTap: () {
                  Navigator.pop(context);
                  _openTelemetryRunLog(context);
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
  const HomePage({
    super.key,
    this.tutorialLaunchMode = TutorialLaunchMode.automatic,
    this.tutorialPreferencesRepository,
  });

  final TutorialLaunchMode tutorialLaunchMode;
  final TutorialPreferencesRepository? tutorialPreferencesRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

enum TutorialLaunchMode {
  automatic,
  manualReplay,
}

class _TutorialStepData {
  const _TutorialStepData({
    required this.title,
    required this.description,
    this.targetKey,
  });

  final String title;
  final String description;
  final GlobalKey? targetKey;
}

class _HomePageState extends State<HomePage> {
  static const int _tutorialStepCount = 8;

  final GlobalKey _settingsButtonKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final List<GlobalKey> _navigationKeys = List<GlobalKey>.generate(
    4,
    (_) => GlobalKey(),
  );

  late final TutorialPreferencesRepository _tutorialPreferencesRepository =
      widget.tutorialPreferencesRepository ??
          SharedPreferencesTutorialPreferencesRepository();

  int _selectedIndex = 0;
  int _tutorialStep = 0;
  bool _tutorialActive = false;
  bool _tutorialClosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeTutorial());
    });
  }

  Future<void> _initializeTutorial() async {
    if (widget.tutorialLaunchMode == TutorialLaunchMode.manualReplay) {
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
          _tutorialStep = 0;
          _tutorialActive = true;
        });
      }
      return;
    }

    try {
      final completed = await _tutorialPreferencesRepository.load();
      if (mounted && completed != true) {
        setState(() {
          _selectedIndex = 0;
          _tutorialStep = 0;
          _tutorialActive = true;
        });
      }
    } catch (error, stackTrace) {
      debugLog('Tutorial completion state could not be loaded: $error');
      debugLog('Stack trace: $stackTrace');
    }
  }

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

  List<_TutorialStepData> _tutorialSteps(bool isEnglish) {
    return [
      _TutorialStepData(
        title: _t(isEnglish, 'Quick tour', '使い方を確認'),
        description: _t(
          isEnglish,
          'Learn how to manage a car, create settings, record a run, and '
              'review your results. This tour does not change your data.',
          '車両の管理、セッティング作成、走行メモ、結果の振り返りまでを案内します。'
              'このガイドではデータを変更しません。',
        ),
      ),
      _TutorialStepData(
        title: _t(isEnglish, 'Manage your garage', 'ガレージで車両を管理'),
        description: _t(
          isEnglish,
          'Keep the cars and parts you use together in Garage. Add a car '
              'from the model list when you are ready.',
          'ガレージでは、使用する車両とパーツをまとめて管理できます。'
              '車種一覧から使う車両を追加します。',
        ),
        targetKey: _navigationKeys[1],
      ),
      _TutorialStepData(
        title: _t(isEnglish, 'Create a setting', 'セッティングを作成'),
        description: _t(
          isEnglish,
          'After the tour, tap Add and choose Create Setting. Select the '
              'manufacturer and model, enter the values, then save.',
          'ガイド終了後に追加ボタンから「設定作成」を選びます。メーカーと車種を選び、'
              '値を入力して保存します。',
        ),
        targetKey: _fabKey,
      ),
      _TutorialStepData(
        title: _t(isEnglish, 'Record a run memo', '走行メモを記録'),
        description: _t(
          isEnglish,
          'The same Add button opens Run Memo, where you can record lap '
              'times, driving feel, and setup changes.',
          '同じ追加ボタンから「走行メモ」を開き、ラップタイム、走行フィーリング、'
              'セッティング変更を記録できます。',
        ),
        targetKey: _fabKey,
      ),
      _TutorialStepData(
        title: _t(isEnglish, 'Check your home', 'ホームで状況を確認'),
        description: _t(
          isEnglish,
          'Home shows the cars and settings you used most recently, so you '
              'can continue your work quickly.',
          'ホームには最近使った車両と設定が表示され、作業をすぐに再開できます。',
        ),
        targetKey: _navigationKeys[0],
      ),
      _TutorialStepData(
        title: _t(isEnglish, 'Review your history', '履歴を振り返る'),
        description: _t(
          isEnglish,
          'History keeps saved settings and run records together for later '
              'comparison.',
          '履歴では、保存したセッティングと走行記録をまとめて確認・比較できます。',
        ),
        targetKey: _navigationKeys[2],
      ),
      _TutorialStepData(
        title: _t(isEnglish, 'Use the tools', 'ツールを活用'),
        description: _t(
          isEnglish,
          'Tools includes backup and restore, calculators, telemetry '
              'analysis, sharing, and statistics.',
          'ツールでは、バックアップと復元、計算、テレメトリー分析、共有、統計を'
              '利用できます。',
        ),
        targetKey: _navigationKeys[3],
      ),
      _TutorialStepData(
        title: _t(isEnglish, 'Open settings', '設定を開く'),
        description: _t(
          isEnglish,
          'Change the theme, language, and service options here. You can '
              'also replay this tutorial at any time.',
          'テーマ、言語、各種サービスを設定できます。このチュートリアルもいつでも'
              '見直せます。',
        ),
        targetKey: _settingsButtonKey,
      ),
    ];
  }

  void _showNextTutorialStep() {
    if (!_tutorialActive || _tutorialClosing) return;
    if (_tutorialStep >= _tutorialStepCount - 1) {
      unawaited(_completeTutorial());
      return;
    }

    final nextStep = _tutorialStep + 1;
    final destinationIndex = switch (nextStep) {
      1 || 2 || 3 => 1,
      4 => 0,
      5 => 2,
      6 || 7 => 3,
      _ => 0,
    };
    setState(() {
      _tutorialStep = nextStep;
      _selectedIndex = destinationIndex;
    });
  }

  Future<void> _completeTutorial() async {
    if (!_tutorialActive || _tutorialClosing) return;

    final messenger = ScaffoldMessenger.of(context);
    final isEnglish =
        Provider.of<SettingsProvider>(context, listen: false).isEnglish;
    final shouldPop =
        widget.tutorialLaunchMode == TutorialLaunchMode.manualReplay;
    Object? saveError;

    setState(() {
      _tutorialClosing = true;
      _tutorialActive = false;
      _tutorialStep = 0;
      _selectedIndex = 0;
    });

    try {
      final didSave = await _tutorialPreferencesRepository.save(true);
      if (!didSave) {
        throw StateError('Tutorial preferences writer returned false.');
      }
    } catch (error, stackTrace) {
      saveError = error;
      debugLog('Tutorial completion state could not be saved: $error');
      debugLog('Stack trace: $stackTrace');
    }

    if (!mounted) return;

    if (shouldPop && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      setState(() => _tutorialClosing = false);
    }

    if (saveError != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _t(
              isEnglish,
              'The tutorial status could not be saved. It may appear again '
                  'next time.',
              'チュートリアルの完了状態を保存できませんでした。次回も表示される場合があります。',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final theme = Theme.of(context);

    final tutorialSteps = _tutorialSteps(isEnglish);
    final currentTutorialStep = tutorialSteps[_tutorialStep];
    final scaffold = Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Text(
          _pageTitle(isEnglish),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton.filledTonal(
            key: _settingsButtonKey,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: _t(isEnglish, 'Settings', '設定'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
              alignment: Alignment.topCenter,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: _buildCurrentPage(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            key: _navigationKeys[0],
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: _t(isEnglish, 'Home', 'ホーム'),
          ),
          NavigationDestination(
            key: _navigationKeys[1],
            icon: const Icon(Icons.garage_outlined),
            selectedIcon: const Icon(Icons.garage_rounded),
            label: _t(isEnglish, 'Garage', 'ガレージ'),
          ),
          NavigationDestination(
            key: _navigationKeys[2],
            icon: const Icon(Icons.history_rounded),
            selectedIcon: const Icon(Icons.history_toggle_off_rounded),
            label: _t(isEnglish, 'History', '履歴'),
          ),
          NavigationDestination(
            key: _navigationKeys[3],
            icon: const Icon(Icons.build_outlined),
            selectedIcon: const Icon(Icons.build_rounded),
            label: _t(isEnglish, 'Tools', 'ツール'),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 || _selectedIndex == 1
          ? _GradientFab(
              key: _fabKey,
              tooltip: _t(isEnglish, 'Add', '追加'),
              onTap: () => _showCreateActionSheet(context, isEnglish),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );

    return PopScope(
      canPop: !_tutorialActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _tutorialActive) {
          unawaited(_completeTutorial());
        }
      },
      child: Stack(
        children: [
          scaffold,
          if (_tutorialActive)
            TutorialOverlay(
              title: currentTutorialStep.title,
              description: currentTutorialStep.description,
              step: _tutorialStep + 1,
              totalSteps: _tutorialStepCount,
              skipLabel: _t(isEnglish, 'Skip', 'スキップ'),
              nextLabel: _tutorialStep == _tutorialStepCount - 1
                  ? _t(isEnglish, 'Finish', '完了')
                  : _t(isEnglish, 'Next', '次へ'),
              targetKey: currentTutorialStep.targetKey,
              onSkip: () => unawaited(_completeTutorial()),
              onNext: _showNextTutorialStep,
            ),
        ],
      ),
    );
  }
}
