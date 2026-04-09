import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/saved_setting.dart';
import '../providers/settings_provider.dart';
import 'car_selection_page.dart';
import 'car_setting_page.dart';
import 'history_page.dart';
import 'my_garage_page.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _openHistoryTab() {
    setState(() {
      _selectedIndex = 2;
    });
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _DashboardHomeTab(onOpenHistory: _openHistoryTab);
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
    if (_selectedIndex == 0) {
      return _t(isEnglish, 'Home', 'ホーム');
    }
    if (_selectedIndex == 1) {
      return _t(isEnglish, 'My Garage', 'マイガレージ');
    }
    if (_selectedIndex == 2) {
      return _t(isEnglish, 'History', '履歴');
    }
    if (_selectedIndex == 3) {
      return _t(isEnglish, 'Tools', 'ツール');
    }
    if (_selectedIndex == 1) {
      return _t(isEnglish, 'My Garage', 'マイガレージ');
    }
    if (_selectedIndex == 2) {
      return _t(isEnglish, 'Setting History', '設定履歴');
    }
    if (_selectedIndex == 3) {
      return _t(isEnglish, 'Tools', 'ツール');
    }

    switch (_selectedIndex) {
      case 0:
        return _t(isEnglish, 'Home', 'ホーム');
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
              tooltip: _t(isEnglish, 'Create a setting', '新しい設定を作成'),
              onTap: () {
                Navigator.pushNamed(context, '/car-selection');
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _DashboardHomeTab extends StatelessWidget {
  final VoidCallback onOpenHistory;

  const _DashboardHomeTab({
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final savedSettings = settingsProvider.savedSettings;
        final cars = settingsProvider.cars;
        final garageCars = settingsProvider.garageCars;
        final isEnglish = settingsProvider.isEnglish;
        final recentBorder = DateTime.now().subtract(const Duration(days: 30));
        final latestSetting =
            savedSettings.isNotEmpty ? savedSettings.first : null;
        final recentSettings = savedSettings.take(4).toList();
        final recentCars = <Car>[];
        final seenCarIds = <String>{};
        for (final setting in savedSettings) {
          if (seenCarIds.add(setting.car.id)) {
            recentCars.add(setting.car);
          }
          if (recentCars.length >= 3) {
            break;
          }
        }
        final settingsLast30Days = savedSettings
            .where((setting) => setting.createdAt.isAfter(recentBorder))
            .length;
        final activeCars =
            savedSettings.map((setting) => setting.car.id).toSet().length;
        final chassisStats = _collectChassisStats(cars, savedSettings)
            .where((stat) => stat.count > 0)
            .take(3)
            .toList();

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
                        title: _t(isEnglish, 'Overview', '概要'),
                        tone: PanelTone.low,
                        child: Column(
                          children: [
                            _MetricRow(
                              label: _t(
                                isEnglish,
                                'Registered cars',
                                '登録マシン',
                              ),
                              value: cars.length.toString().padLeft(2, '0'),
                            ),
                            const SizedBox(height: 14),
                            _MetricRow(
                              label: _t(
                                isEnglish,
                                'Saved setups',
                                '保存済み設定',
                              ),
                              value: savedSettings.length
                                  .toString()
                                  .padLeft(2, '0'),
                            ),
                            const SizedBox(height: 14),
                            _MetricRow(
                              label: _t(
                                isEnglish,
                                'In garage',
                                'ガレージ登録',
                              ),
                              value:
                                  garageCars.length.toString().padLeft(2, '0'),
                            ),
                            const SizedBox(height: 14),
                            _MetricRow(
                              label: _t(
                                isEnglish,
                                'Last 30 days',
                                '最近30日',
                              ),
                              value:
                                  settingsLast30Days.toString().padLeft(2, '0'),
                              highlight: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionPanel(
                        title: _t(isEnglish, 'Most used cars', 'よく使うマシン'),
                        tone: PanelTone.highest,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FilterRow(
                              label: _t(
                                isEnglish,
                                'Cars with saved history',
                                '履歴があるマシン',
                              ),
                              count: activeCars,
                              active: true,
                            ),
                            const SizedBox(height: 12),
                            if (chassisStats.isEmpty)
                              Text(
                                _t(
                                  isEnglish,
                                  'Save a setup first to see which cars you use most.',
                                  '設定を保存すると、よく使うマシンがここに表示されます。',
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
                            else ...[
                              Text(
                                _t(
                                  isEnglish,
                                  'Sorted by number of saved setups.',
                                  '保存回数が多い順に表示しています。',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              ...chassisStats.map(
                                (stat) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _FilterRow(
                                    label: stat.name,
                                    count: stat.count,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );

                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HomeSectionHeading(
                        isEnglish: isEnglish,
                        showViewAll:
                            savedSettings.length > recentSettings.length,
                        onViewAll: onOpenHistory,
                      ),
                      const SizedBox(height: 20),
                      if (recentSettings.isEmpty)
                        _DashboardEmptyPanel(
                          isEnglish: isEnglish,
                          onCreate: () => _openCarSelection(context),
                        )
                      else
                        ...recentSettings.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _HomeSettingCard(
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
                            _t(isEnglish, 'Open history', '履歴を開く'),
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
                        _RecentCarHeroCard(
                          isEnglish: isEnglish,
                          latestSetting: latestSetting,
                          recentCars: recentCars,
                          totalCars: cars.length,
                          garageCars: garageCars.length,
                          settingsLast30Days: settingsLast30Days,
                          onCreate: () => _openCarSelection(context),
                        ),
                        const SizedBox(height: 28),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 300, child: sidebar),
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

// ignore: unused_element
class _DashboardHeroCard extends StatelessWidget {
  final bool isEnglish;
  final SavedSetting? latestSetting;
  final List<Car> recentCars;
  final int totalCars;
  final int garageCars;
  final int settingsLast30Days;
  final VoidCallback onCreate;

  const _DashboardHeroCard({
    required this.isEnglish,
    required this.latestSetting,
    required this.recentCars,
    required this.totalCars,
    required this.garageCars,
    required this.settingsLast30Days,
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
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerLowest,
            colorScheme.primary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withValues(
              alpha: theme.brightness == Brightness.light ? 0.04 : 0.12,
            ),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;
          final title = latestSetting == null
              ? _t(
                  isEnglish,
                  'Start saving setups for each car',
                  'マシンごとの設定保存を始めましょう',
                )
              : _t(
                  isEnglish,
                  'Continue from your latest saved setup',
                  '前回保存した設定からすぐ再開できます',
                );
          final subtitle = latestSetting == null
              ? _t(
                  isEnglish,
                  'Once you save a setup, this screen becomes a shortcut to your recent work and your car history.',
                  '設定を保存すると、この画面から最近の作業やマシンごとの履歴へすぐ戻れるようになります。',
                )
              : _t(
                  isEnglish,
                  '${latestSetting!.car.name} / ${latestSetting!.name} was saved on ${_formatDate(latestSetting!.createdAt, isEnglish)}.',
                  '${latestSetting!.car.name} / ${latestSetting!.name} を ${_formatDate(latestSetting!.createdAt, isEnglish)} に保存しました。',
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(isEnglish, 'Home overview', 'ホーム概要'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _DashboardStatChip(
                    label: _t(isEnglish, 'Cars', '登録マシン'),
                    value: totalCars.toString().padLeft(2, '0'),
                  ),
                  _DashboardStatChip(
                    label: _t(isEnglish, 'Garage', 'ガレージ'),
                    value: garageCars.toString().padLeft(2, '0'),
                  ),
                  _DashboardStatChip(
                    label: _t(isEnglish, 'Last 30 days', '最近30日'),
                    value: settingsLast30Days.toString().padLeft(2, '0'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TechnicalActionButton(
                      label: _t(
                        isEnglish,
                        'Create a new setting',
                        '新しい設定を作成',
                      ),
                      icon: Icons.add_rounded,
                      onTap: onCreate,
                    ),
                    if (latestSetting != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openSettingEditor(context, latestSetting!),
                        icon: const Icon(Icons.playlist_play_rounded),
                        label: Text(
                          _t(
                            isEnglish,
                            'Open latest setting',
                            '最新の設定を開く',
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    _TechnicalActionButton(
                      label: _t(
                        isEnglish,
                        'Create a new setting',
                        '新しい設定を作成',
                      ),
                      icon: Icons.add_rounded,
                      onTap: onCreate,
                    ),
                    if (latestSetting != null) ...[
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openSettingEditor(context, latestSetting!),
                        icon: const Icon(Icons.playlist_play_rounded),
                        label: Text(
                          _t(
                            isEnglish,
                            'Open latest setting',
                            '最新の設定を開く',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RecentCarHeroCard extends StatelessWidget {
  final bool isEnglish;
  final SavedSetting? latestSetting;
  final List<Car> recentCars;
  final int totalCars;
  final int garageCars;
  final int settingsLast30Days;
  final VoidCallback onCreate;

  const _RecentCarHeroCard({
    required this.isEnglish,
    required this.latestSetting,
    required this.recentCars,
    required this.totalCars,
    required this.garageCars,
    required this.settingsLast30Days,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final latestCar = latestSetting?.car;

    final title = latestCar == null
        ? _t(
            isEnglish,
            'Keep your last car within one tap',
            '前回触ったマシンにすぐ戻れるホーム',
          )
        : _t(
            isEnglish,
            'Jump back into your last car',
            '前回触ったマシンをすぐ開けます',
          );

    final subtitle = latestCar == null
        ? _t(
            isEnglish,
            'As soon as you save a setup, the latest car and recent cars appear here for quick access.',
            '設定を保存すると、最新のマシンと最近触ったマシンをここからすぐ開けるようになります。',
          )
        : _t(
            isEnglish,
            'Your latest saved work was ${latestCar.name} / ${latestSetting!.name} on ${_formatDate(latestSetting!.createdAt, isEnglish)}.',
            '${latestCar.name} / ${latestSetting!.name} を ${_formatDate(latestSetting!.createdAt, isEnglish)} に保存しています。',
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerLowest,
            colorScheme.primary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withValues(
              alpha: theme.brightness == Brightness.light ? 0.04 : 0.12,
            ),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(isEnglish, 'Quick access', 'クイックアクセス'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (latestSetting != null) ...[
            const SizedBox(height: 20),
            _LastCarQuickAccessCard(
              isEnglish: isEnglish,
              latestSetting: latestSetting!,
              onOpenCar: () => _openCarEditor(context, latestSetting!.car),
              onOpenSetting: () => _openSettingEditor(context, latestSetting!),
            ),
          ],
          if (recentCars.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _t(isEnglish, 'Recent cars', '最近触ったマシン'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: recentCars
                  .map(
                    (car) => _RecentCarShortcut(
                      car: car,
                      onTap: () => _openCarEditor(context, car),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DashboardStatChip(
                label: _t(isEnglish, 'Cars', '登録マシン'),
                value: totalCars.toString().padLeft(2, '0'),
              ),
              _DashboardStatChip(
                label: _t(isEnglish, 'Garage', 'ガレージ'),
                value: garageCars.toString().padLeft(2, '0'),
              ),
              _DashboardStatChip(
                label: _t(isEnglish, 'Last 30 days', '最近30日'),
                value: settingsLast30Days.toString().padLeft(2, '0'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _TechnicalActionButton(
            label: _t(isEnglish, 'Create a new setting', '新しい設定を作成'),
            icon: Icons.add_rounded,
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

class _LastCarQuickAccessCard extends StatelessWidget {
  final bool isEnglish;
  final SavedSetting latestSetting;
  final VoidCallback onOpenCar;
  final VoidCallback onOpenSetting;

  const _LastCarQuickAccessCard({
    required this.isEnglish,
    required this.latestSetting,
    required this.onOpenCar,
    required this.onOpenSetting,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(isEnglish, 'Last car', '前回触ったマシン'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latestSetting.car.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            latestSetting.car.manufacturer.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              isEnglish,
              'Latest saved setting: ${latestSetting.name}',
              '最新保存: ${latestSetting.name}',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              isEnglish,
              'Saved on ${_formatDate(latestSetting.createdAt, isEnglish)}',
              '${_formatDate(latestSetting.createdAt, isEnglish)} に保存',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onOpenCar,
                icon: const Icon(Icons.directions_car_filled_rounded),
                label: Text(
                  _t(isEnglish, 'Open this car', 'このマシンを開く'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onOpenSetting,
                icon: const Icon(Icons.playlist_play_rounded),
                label: Text(
                  _t(isEnglish, 'Open latest setting', '最新の設定を開く'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentCarShortcut extends StatelessWidget {
  final Car car;
  final VoidCallback onTap;

  const _RecentCarShortcut({
    required this.car,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(
        Icons.directions_car_filled_rounded,
        size: 18,
        color: colorScheme.primary,
      ),
      label: Text(car.name),
      onPressed: onTap,
      backgroundColor: colorScheme.surfaceContainerLow,
      side: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _DashboardStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _DashboardStatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _HomeSectionHeading extends StatelessWidget {
  final bool isEnglish;
  final bool showViewAll;
  final VoidCallback onViewAll;

  const _HomeSectionHeading({
    required this.isEnglish,
    required this.showViewAll,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(isEnglish, 'Recent setups', '最近保存した設定'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  isEnglish,
                  'Pick up your latest work',
                  '前回の作業をここから再開',
                ),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        if (showViewAll)
          TextButton(
            onPressed: onViewAll,
            child: Text(_t(isEnglish, 'View all', 'すべて見る')),
          ),
      ],
    );
  }
}

class _HomeSettingCard extends StatelessWidget {
  final SavedSetting setting;
  final bool isHighlighted;

  const _HomeSettingCard({
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
        onTap: () => _openSettingEditor(context, setting),
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
                                        'Saved setting',
                                        '保存した設定',
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
                                    _openSettingEditor(context, setting);
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
                                label: _t(isEnglish, 'Saved on', '保存日'),
                                value: _formatDate(
                                  setting.createdAt,
                                  isEnglish,
                                ),
                              ),
                              _CardMetric(
                                icon: Icons.tune_rounded,
                                label: _t(isEnglish, 'Items', '項目数'),
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
          title: Text(_t(isEnglish, 'Delete setting', '設定を削除')),
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

class _DashboardEmptyPanel extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onCreate;

  const _DashboardEmptyPanel({
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
            _t(isEnglish, 'No saved setups yet', '保存済み設定はまだありません'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              isEnglish,
              'Create your first setting so you can compare changes and keep your tuning history in one place.',
              '最初の設定を保存すると、変更点の比較やチューニング履歴の管理がしやすくなります。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _TechnicalActionButton(
            label: _t(isEnglish, 'Create first setting', '最初の設定を作成'),
            icon: Icons.add_rounded,
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
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
