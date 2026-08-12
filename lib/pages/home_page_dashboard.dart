part of 'home_page.dart';

class _DashboardHomeTab extends StatelessWidget {
  const _DashboardHomeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final cars = settingsProvider.cars;
        final savedSettings = List<SavedSetting>.from(
          settingsProvider.savedSettings,
        )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final isEnglish = settingsProvider.isEnglish;

        if (cars.isEmpty) {
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _SimpleHomeEmptyState(
                    title: _t(isEnglish, 'No machines yet', 'マシンがまだありません'),
                    message: _t(
                      isEnglish,
                      'Add your first machine to start from a simpler home screen.',
                      '最初のマシンを追加すると、この画面からすぐ開けるようになります。',
                    ),
                    actionLabel: _t(isEnglish, 'Select a machine', 'マシンを選ぶ'),
                    onCreate: () => _openCarSelection(context),
                  ),
                ),
              ),
            ),
          );
        }

        final latestSettingByCarId = <String, SavedSetting>{};
        for (final setting in savedSettings) {
          latestSettingByCarId.putIfAbsent(setting.car.id, () => setting);
        }

        final activities = [
          for (var index = 0; index < cars.length; index++)
            _HomeCarActivity(
              car: cars[index],
              latestSetting: latestSettingByCarId[cars[index].id],
              originalIndex: index,
            ),
        ]..sort(_compareHomeCarActivity);

        final recentActivities = activities
            .where((activity) => activity.latestSetting != null)
            .take(3)
            .toList(growable: false);

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SimpleHomeSectionHeader(
                      title: _t(isEnglish, 'Recent machines', '最近触ったマシン'),
                      subtitle: _t(
                        isEnglish,
                        'Open the machines you touched most recently.',
                        '最近触ったマシンからすぐ開けます。',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (recentActivities.isEmpty)
                      _SimpleHomeEmptyState(
                        title:
                            _t(isEnglish, 'No recent work yet', 'まだ保存履歴がありません'),
                        message: _t(
                          isEnglish,
                          'Save a setting and your latest machines will appear here.',
                          '設定を保存すると、ここに最近触ったマシンが並びます。',
                        ),
                        actionLabel: _t(isEnglish, 'Create a setting', '設定を作る'),
                        onCreate: () => _openCarSelection(context),
                        compact: true,
                      )
                    else
                      ...recentActivities.asMap().entries.map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(
                                bottom: entry.key == recentActivities.length - 1
                                    ? 0
                                    : 12,
                              ),
                              child: _RecentMachineCard(
                                activity: entry.value,
                                isEnglish: isEnglish,
                                isPrimary: entry.key == 0,
                                onTap: () =>
                                    _openCarEditor(context, entry.value.car),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

int _compareHomeCarActivity(_HomeCarActivity a, _HomeCarActivity b) {
  final aLastUsed = a.latestSetting?.createdAt;
  final bLastUsed = b.latestSetting?.createdAt;

  if (aLastUsed != null && bLastUsed != null) {
    final compare = bLastUsed.compareTo(aLastUsed);
    if (compare != 0) {
      return compare;
    }
  } else if (aLastUsed != null) {
    return -1;
  } else if (bLastUsed != null) {
    return 1;
  }

  return a.originalIndex.compareTo(b.originalIndex);
}

String _latestSettingLabel(SavedSetting? setting, bool isEnglish) {
  if (setting == null) {
    return _t(isEnglish, 'No saved settings yet', '保存履歴なし');
  }

  return _t(
    isEnglish,
    'Latest setting: ${setting.name}',
    '最新設定: ${setting.name}',
  );
}

String _lastSavedLabel(SavedSetting? setting, bool isEnglish) {
  if (setting == null) {
    return _t(isEnglish, 'Ready for the first save', '最初の保存待ち');
  }

  return _t(
    isEnglish,
    'Last saved ${_formatDate(setting.createdAt, isEnglish)}',
    '最終保存: ${_formatDate(setting.createdAt, isEnglish)}',
  );
}

class _HomeCarActivity {
  final Car car;
  final SavedSetting? latestSetting;
  final int originalIndex;

  const _HomeCarActivity({
    required this.car,
    required this.latestSetting,
    required this.originalIndex,
  });
}

class _SimpleHomeSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SimpleHomeSectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RecentMachineCard extends StatelessWidget {
  final _HomeCarActivity activity;
  final bool isEnglish;
  final bool isPrimary;
  final VoidCallback onTap;

  const _RecentMachineCard({
    required this.activity,
    required this.isEnglish,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final latestSetting = activity.latestSetting!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.all(isPrimary ? 20 : 16),
          decoration: BoxDecoration(
            color: isPrimary
                ? colorScheme.surfaceContainerLow
                : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: isPrimary ? 0.45 : 0.3,
              ),
            ),
          ),
          child: Row(
            children: [
              _HomeMachineLeading(
                label: isPrimary ? _t(isEnglish, 'Latest', '最新') : null,
                emphasize: isPrimary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.car.name,
                      style: (isPrimary
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.titleLarge)
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity.car.manufacturer.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _latestSettingLabel(latestSetting, isEnglish),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastSavedLabel(latestSetting, isEnglish),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMachineLeading extends StatelessWidget {
  final String? label;
  final bool emphasize;

  const _HomeMachineLeading({
    this.label,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: emphasize ? 56 : 48,
      height: emphasize ? 56 : 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: emphasize
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: label == null
          ? Icon(
              Icons.directions_car_filled_rounded,
              color: colorScheme.primary,
            )
          : Text(
              label!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _SimpleHomeEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onCreate;
  final bool compact;

  const _SimpleHomeEmptyState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onCreate,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 48 : 56,
            height: compact ? 48 : 56,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
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

// ignore: unused_element
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

// ignore: unused_element
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

// ignore: unused_element
class _HomeSettingCard extends StatelessWidget {
  final SavedSetting setting;
  final bool isHighlighted;

  const _HomeSettingCard({
    required this.setting,
  }) : isHighlighted = false;

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

// ignore: unused_element
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
