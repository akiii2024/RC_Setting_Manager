import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/saved_setting.dart';
import '../providers/settings_provider.dart';
import 'car_selection_page.dart';
import 'car_setting_page.dart';
import 'history_page.dart';
import 'tools_page.dart';

const _blueShiftGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF005BCF),
    Color(0xFF1A73E8),
  ],
);

String _t(bool isEnglish, String en, String ja) => isEnglish ? en : ja;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _openHistoryTab() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _HomeTab(onOpenHistory: _openHistoryTab);
      case 1:
        return const HistoryPage();
      case 2:
        return const ToolsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  String _pageTitle(bool isEnglish) {
    switch (_selectedIndex) {
      case 0:
        return 'ENGINEERING PRECISION';
      case 1:
        return _t(isEnglish, 'Setting History', '設定履歴');
      case 2:
        return _t(isEnglish, 'Tools', 'ツール');
      default:
        return 'ENGINEERING PRECISION';
    }
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
            icon: const Icon(Icons.directions_car_outlined),
            selectedIcon: const Icon(Icons.directions_car_filled_rounded),
            label: _t(isEnglish, 'Fleet', 'ホーム'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            selectedIcon: const Icon(Icons.history_toggle_off_rounded),
            label: _t(isEnglish, 'Logs', '履歴'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.build_outlined),
            selectedIcon: const Icon(Icons.build_rounded),
            label: _t(isEnglish, 'Tools', 'ツール'),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? _GradientFab(
              tooltip: _t(isEnglish, 'New calibration', '新規設定'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CarSelectionPage(),
                  ),
                );
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _HomeTab extends StatelessWidget {
  final VoidCallback onOpenHistory;

  const _HomeTab({
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final savedSettings = settingsProvider.savedSettings;
        final cars = settingsProvider.cars;
        final isEnglish = settingsProvider.isEnglish;
        final latestSetting =
            savedSettings.isNotEmpty ? savedSettings.first : null;
        final activeCarIds =
            savedSettings.map((setting) => setting.car.id).toSet();
        final activeCoverage = cars.isEmpty
            ? 0
            : ((activeCarIds.length / cars.length) * 100).round();
        final chassisStats = _collectChassisStats(cars, savedSettings);
        final recentSettings = savedSettings.take(4).toList();

        return Stack(
          children: [
            const Positioned(
              top: 12,
              right: -52,
              child: _BackgroundHalo(
                size: 184,
                colors: [
                  Color(0x12005BCF),
                  Color(0x001A73E8),
                ],
              ),
            ),
            const Positioned(
              top: 320,
              left: -80,
              child: _BackgroundHalo(
                size: 220,
                colors: [
                  Color(0x0E9E4300),
                  Color(0x00C55500),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 960;

                  final sidebar = Column(
                    children: [
                      _SectionPanel(
                        title: _t(isEnglish, 'FLEET METRICS', 'フリート指標'),
                        tone: PanelTone.low,
                        child: Column(
                          children: [
                            _MetricRow(
                              label: _t(isEnglish, 'TOTAL UNITS', '総マシン数'),
                              value: cars.length.toString().padLeft(2, '0'),
                            ),
                            const SizedBox(height: 14),
                            _MetricRow(
                              label: _t(isEnglish, 'CALIBRATIONS', '保存設定'),
                              value: savedSettings.length
                                  .toString()
                                  .padLeft(2, '0'),
                            ),
                            const SizedBox(height: 14),
                            _MetricRow(
                              label: _t(isEnglish, 'ACTIVE COVERAGE', '稼働率'),
                              value: '$activeCoverage%',
                              highlight: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionPanel(
                        title: _t(isEnglish, 'ACTIVE CHASSIS', '稼働シャーシ'),
                        tone: PanelTone.highest,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FilterRow(
                              label: _t(isEnglish, 'ALL MACHINES', '全マシン'),
                              count: cars.length,
                              active: true,
                            ),
                            const SizedBox(height: 12),
                            if (chassisStats.isEmpty)
                              Text(
                                _t(
                                  isEnglish,
                                  'No chassis registered yet.',
                                  'まだシャーシが登録されていません。',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              )
                            else
                              ...chassisStats.take(3).map(
                                    (stat) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _FilterRow(
                                        label: stat.name,
                                        count: stat.count,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t(
                                    isEnglish,
                                    'RECENT CALIBRATIONS',
                                    '最近のキャリブレーション',
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _t(
                                    isEnglish,
                                    'Latest saved setup sheets',
                                    '最新の保存セットアップ',
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          if (savedSettings.length > recentSettings.length)
                            TextButton(
                              onPressed: onOpenHistory,
                              child: Text(
                                _t(isEnglish, 'VIEW ALL', 'すべて見る'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (recentSettings.isEmpty)
                        _EmptyCalibrationPanel(
                          isEnglish: isEnglish,
                          onCreate: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CarSelectionPage(),
                              ),
                            );
                          },
                        )
                      else
                        ...recentSettings.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: SettingCard(
                                  setting: entry.value,
                                  isHighlighted: entry.key == 0,
                                ),
                              ),
                            ),
                      if (savedSettings.length > recentSettings.length) ...[
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: onOpenHistory,
                          icon: const Icon(Icons.history_rounded),
                          label: Text(
                            _t(
                              isEnglish,
                              'OPEN FULL HISTORY',
                              '履歴を開く',
                            ),
                          ),
                        ),
                      ],
                    ],
                  );

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      24,
                      16,
                      isWide ? 32 : 120,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DashboardHeader(
                          isEnglish: isEnglish,
                          latestSetting: latestSetting,
                          showAction: isWide,
                          onCreate: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CarSelectionPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 280,
                                child: sidebar,
                              ),
                              const SizedBox(width: 24),
                              Expanded(child: content),
                            ],
                          )
                        else ...[
                          sidebar,
                          const SizedBox(height: 24),
                          content,
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<_ChassisStat> _collectChassisStats(
    List<Car> cars,
    List<SavedSetting> savedSettings,
  ) {
    final counts = <String, int>{};

    for (final car in cars) {
      counts[car.name] = 0;
    }

    for (final setting in savedSettings) {
      counts[setting.car.name] = (counts[setting.car.name] ?? 0) + 1;
    }

    final stats = counts.entries
        .map((entry) => _ChassisStat(name: entry.key, count: entry.value))
        .toList()
      ..sort((a, b) {
        final countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.name.compareTo(b.name);
      });

    return stats;
  }
}

class _DashboardHeader extends StatelessWidget {
  final bool isEnglish;
  final SavedSetting? latestSetting;
  final bool showAction;
  final VoidCallback onCreate;

  const _DashboardHeader({
    required this.isEnglish,
    required this.latestSetting,
    required this.showAction,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(isEnglish, 'OPERATIONAL FLEET', 'オペレーションフリート'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(isEnglish, 'My Machines', 'マイマシン'),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                latestSetting != null
                    ? _t(
                        isEnglish,
                        'Latest calibration: ${latestSetting!.name}',
                        '最新キャリブレーション: ${latestSetting!.name}',
                      )
                    : _t(
                        isEnglish,
                        'No saved calibrations yet. Start a new chassis profile.',
                        '保存済みキャリブレーションはまだありません。新しいシャーシプロファイルを作成しましょう。',
                      ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (showAction) ...[
          const SizedBox(width: 20),
          _TechnicalActionButton(
            label: _t(isEnglish, 'NEW CALIBRATION', '新規キャリブレーション'),
            icon: Icons.add_rounded,
            onTap: onCreate,
          ),
        ],
      ],
    );
  }
}

enum PanelTone { low, highest }

class _SectionPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final PanelTone tone;

  const _SectionPanel({
    required this.title,
    required this.child,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tone == PanelTone.low
            ? colorScheme.surfaceContainerLow
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MetricRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: highlight ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String label;
  final int count;
  final bool active;

  const _FilterRow({
    required this.label,
    required this.count,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? colorScheme.primary : colorScheme.outlineVariant,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color:
                  active ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          count.toString().padLeft(2, '0'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyCalibrationPanel extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onCreate;

  const _EmptyCalibrationPanel({
    required this.isEnglish,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withValues(
              alpha: theme.brightness == Brightness.light ? 0.04 : 0.12,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.directions_car_filled_rounded,
              size: 32,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _t(isEnglish, 'No calibration history yet', 'まだ保存設定がありません'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              isEnglish,
              'Create your first setup sheet to start tracking machine changes and archives.',
              '最初のセットアップシートを作成して、マシンごとの変更履歴を残しましょう。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _TechnicalActionButton(
            label: _t(isEnglish, 'CREATE FIRST SHEET', '最初のシートを作成'),
            icon: Icons.add_rounded,
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

class SettingCard extends StatelessWidget {
  final SavedSetting setting;
  final bool isHighlighted;

  const SettingCard({
    super.key,
    required this.setting,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
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
        },
        child: Ink(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colorScheme.onSurface.withValues(
                  alpha: theme.brightness == Brightness.light ? 0.04 : 0.14,
                ),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: isHighlighted ? _blueShiftGradient : null,
                    color: isHighlighted
                        ? null
                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TechnicalThumbnail(
                      accentColor: isHighlighted
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _t(
                                        isEnglish,
                                        'CHASSIS PROFILE',
                                        'シャーシプロファイル',
                                      ),
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: isHighlighted
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      setting.car.name,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      setting.name,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
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
                                  } else if (value == 'delete') {
                                    _showDeleteConfirmationDialog(
                                      context,
                                      setting,
                                    );
                                  }
                                },
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                itemBuilder: (context) => [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit_rounded,
                                          size: 18,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(_t(isEnglish, 'Edit', '編集')),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_rounded,
                                          size: 18,
                                          color: colorScheme.error,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _t(isEnglish, 'Delete', '削除'),
                                          style: TextStyle(
                                            color: colorScheme.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 28,
                            runSpacing: 12,
                            children: [
                              _CardMetric(
                                icon: Icons.calendar_today_outlined,
                                label: _t(
                                  isEnglish,
                                  'LAST SAVED',
                                  '最終保存',
                                ),
                                value:
                                    _formatDate(setting.createdAt, isEnglish),
                              ),
                              _CardMetric(
                                icon: Icons.tune_rounded,
                                label: _t(
                                  isEnglish,
                                  'FIELDS',
                                  '項目数',
                                ),
                                value: setting.settings.length
                                    .toString()
                                    .padLeft(2, '0'),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  void _showDeleteConfirmationDialog(
    BuildContext context,
    SavedSetting setting,
  ) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_t(isEnglish, 'Delete Setting', '設定を削除')),
          content: Text(
            _t(
              isEnglish,
              'Delete "${setting.name}"? This action cannot be undone.',
              '「${setting.name}」を削除しますか？この操作は元に戻せません。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(_t(isEnglish, 'Cancel', 'キャンセル')),
            ),
            TextButton(
              onPressed: () {
                settingsProvider.deleteSetting(setting.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _t(isEnglish, 'Setting deleted', '設定を削除しました'),
                    ),
                  ),
                );
              },
              child: Text(
                _t(isEnglish, 'Delete', '削除'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TechnicalThumbnail extends StatelessWidget {
  final Color accentColor;

  const _TechnicalThumbnail({
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 12,
            right: 12,
            top: 18,
            child: Container(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 18,
            child: Container(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          Positioned(
            top: 12,
            bottom: 12,
            left: 22,
            child: Container(
              width: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          Positioned(
            top: 12,
            bottom: 12,
            right: 22,
            child: Container(
              width: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          Center(
            child: Icon(
              Icons.directions_car_filled_rounded,
              size: 36,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CardMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TechnicalActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TechnicalActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(10);
    final shadowColor = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: Theme.of(context).brightness == Brightness.light ? 0.08 : 0.18,
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _blueShiftGradient,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientFab extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;

  const _GradientFab({
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shadowColor = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: Theme.of(context).brightness == Brightness.light ? 0.12 : 0.22,
        );

    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _blueShiftGradient,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: 58,
              height: 58,
              child: Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundHalo extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _BackgroundHalo({
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _ChassisStat {
  final String name;
  final int count;

  const _ChassisStat({
    required this.name,
    required this.count,
  });
}
