import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/run_feel_tags.dart';
import '../models/run_log.dart';
import '../models/run_log_statistics.dart';
import '../models/saved_setting.dart';
import '../models/setting_statistics.dart';
import '../providers/settings_provider.dart';
import '../utils/run_log_formatters.dart';
import 'car_selection_page.dart';

class StatisticsPage extends StatelessWidget {
  static const int _recentDays = 30;
  static const int _monthWindow = 6;

  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final isEnglish = settingsProvider.isEnglish;

        if (!settingsProvider.isInitialized) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_text(isEnglish, 'Statistics', '統計情報')),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final now = DateTime.now();
        final statistics = SettingStatistics.fromSavedSettings(
          settingsProvider.savedSettings,
          totalRegisteredCars: settingsProvider.cars.length,
          now: now,
          recentDays: _recentDays,
          monthWindow: _monthWindow,
        );
        final runStatistics = RunLogStatistics.fromRunLogs(
          settingsProvider.runLogs,
          now: now,
          recentDays: _recentDays,
        );
        final hasSettingStatistics = statistics.totalSettings > 0;
        final hasRunStatistics = runStatistics.totalRuns > 0;

        return Scaffold(
          appBar: AppBar(
            title: Text(_text(isEnglish, 'Statistics', '統計情報')),
          ),
          body: !hasSettingStatistics && !hasRunStatistics
              ? _buildEmptyState(context, isEnglish)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (hasRunStatistics) ...[
                      _buildRunPerformanceHero(
                        context,
                        runStatistics,
                        isEnglish,
                        now,
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: _text(
                          isEnglish,
                          'Run Performance',
                          '走行パフォーマンス',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRunOverview(context, runStatistics, isEnglish),
                      const SizedBox(height: 20),
                      _buildFastestRuns(context, runStatistics, isEnglish),
                      const SizedBox(height: 20),
                      _buildSettingPerformance(
                        context,
                        runStatistics,
                        isEnglish,
                        now,
                      ),
                      const SizedBox(height: 20),
                      _buildChangePerformance(
                        context,
                        runStatistics,
                        isEnglish,
                        now,
                      ),
                      const SizedBox(height: 20),
                      _buildFeelTagPerformance(
                        context,
                        runStatistics,
                        isEnglish,
                      ),
                    ],
                    if (hasSettingStatistics) ...[
                      if (hasRunStatistics) const SizedBox(height: 28),
                      _buildHero(context, statistics, isEnglish, now),
                      const SizedBox(height: 20),
                      _SectionTitle(title: _text(isEnglish, 'Overview', '概要')),
                      const SizedBox(height: 12),
                      _buildOverview(context, statistics, isEnglish),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title:
                            _text(isEnglish, 'Monthly Activity', '月別アクティビティ'),
                      ),
                      const SizedBox(height: 12),
                      _buildMonthlyActivity(
                          context, statistics, isEnglish, now),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: _text(isEnglish, 'Usage Breakdown', '使用状況の内訳'),
                      ),
                      const SizedBox(height: 12),
                      _buildUsageBreakdown(context, statistics, isEnglish, now),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: _text(isEnglish, 'Recent Activity', '最近の保存履歴'),
                      ),
                      const SizedBox(height: 12),
                      _buildRecentActivity(context, statistics, isEnglish),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRunPerformanceHero(
    BuildContext context,
    RunLogStatistics statistics,
    bool isEnglish,
    DateTime now,
  ) {
    final theme = Theme.of(context);
    final bestRun = statistics.bestRun;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.tertiary,
            theme.colorScheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text(
              isEnglish,
              'Find setups that produce lap time',
              'タイムが出るセットを探す',
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _text(
              isEnglish,
              'Run logs are ranked by best lap, setup, feel, and changed setting items.',
              '走行ログをベストラップ、セット、フィーリング、変更項目ごとに集計します。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoChip(
                label: _text(isEnglish, 'Runs', '走行ログ'),
                value: '${statistics.totalRuns}',
              ),
              _InfoChip(
                label: _text(isEnglish, 'Timed', 'タイム有り'),
                value: '${statistics.timedRuns}',
              ),
              _InfoChip(
                label: _text(isEnglish, 'Last 30 days', '直近30日'),
                value: '${statistics.runsLast30Days}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _FrostedPanel(
                  label: _text(isEnglish, 'Best lap', 'ベストラップ'),
                  value: bestRun == null
                      ? _text(isEnglish, 'No time', 'タイムなし')
                      : formatBestLapMillis(bestRun.bestLapMillis),
                  subtitle: bestRun == null
                      ? null
                      : '${bestRun.car.name} / ${_formatDate(bestRun.runAt, isEnglish)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FrostedPanel(
                  label: _text(isEnglish, 'Fastest setup', '最速セット'),
                  value: bestRun?.resultSettingName ??
                      bestRun?.baseSettingName ??
                      _text(isEnglish, 'Unlinked', '未紐づけ'),
                  subtitle: statistics.latestRunAt == null
                      ? null
                      : _text(
                          isEnglish,
                          'Latest ${_formatRelativeTime(statistics.latestRunAt, now, isEnglish)}',
                          '最新 ${_formatRelativeTime(statistics.latestRunAt, now, isEnglish)}',
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRunOverview(
    BuildContext context,
    RunLogStatistics statistics,
    bool isEnglish,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.18,
      children: [
        _MetricTile(
          icon: Icons.timer_rounded,
          title: _text(isEnglish, 'Best lap', 'ベストラップ'),
          value: statistics.bestRun == null
              ? _text(isEnglish, 'No time', 'タイムなし')
              : formatBestLapMillis(statistics.bestRun!.bestLapMillis),
          detail: statistics.bestRun?.car.name ??
              _text(isEnglish, 'Record a timed run', 'タイムを記録してください'),
        ),
        _MetricTile(
          icon: Icons.speed_rounded,
          title: _text(isEnglish, 'Average lap', '平均タイム'),
          value: statistics.averageBestLapMillis <= 0
              ? '-'
              : formatBestLapMillis(statistics.averageBestLapMillis),
          detail: _text(
            isEnglish,
            '${statistics.timedRuns} timed runs',
            '${statistics.timedRuns}件のタイム',
          ),
        ),
        _MetricTile(
          icon: Icons.tune_rounded,
          title: _text(isEnglish, 'Ranked setups', '集計セット数'),
          value: '${statistics.settingPerformance.length}',
          detail: _text(isEnglish, 'linked to run logs', '走行ログに紐づくセット'),
        ),
        _MetricTile(
          icon: Icons.edit_note_rounded,
          title: _text(isEnglish, 'Changed items', '変更項目'),
          value: '${statistics.changePerformance.length}',
          detail: _text(isEnglish, 'with lap data', 'タイム付きで集計'),
        ),
      ],
    );
  }

  Widget _buildFastestRuns(
    BuildContext context,
    RunLogStatistics statistics,
    bool isEnglish,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(isEnglish, 'Fastest runs', '速い走行ログ'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                isEnglish,
                'Best laps are listed first so the setup behind each run is easy to inspect.',
                'ベストラップ順に並べ、どのセットで出たタイムかを確認できます。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.72),
                  ),
            ),
            const SizedBox(height: 16),
            if (statistics.fastestRuns.isEmpty)
              Text(_text(
                  isEnglish, 'No timed run logs yet.', 'タイム付き走行ログがありません。'))
            else
              for (var index = 0;
                  index < statistics.fastestRuns.length;
                  index++) ...[
                if (index > 0) const Divider(height: 24),
                _FastestRunTile(
                  rank: index + 1,
                  runLog: statistics.fastestRuns[index],
                  isEnglish: isEnglish,
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingPerformance(
    BuildContext context,
    RunLogStatistics statistics,
    bool isEnglish,
    DateTime now,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(isEnglish, 'Setup ranking', 'セット別ランキング'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                isEnglish,
                'Linked base/result setups are ranked by their fastest logged lap.',
                '走行ログに紐づいたベース/結果セットを最速タイム順に並べます。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.72),
                  ),
            ),
            const SizedBox(height: 16),
            if (statistics.settingPerformance.isEmpty)
              Text(_text(
                isEnglish,
                'No linked timed setups yet.',
                'タイム付きで紐づくセットがまだありません。',
              ))
            else
              for (var index = 0;
                  index < statistics.settingPerformance.length;
                  index++) ...[
                if (index > 0) const Divider(height: 24),
                _SettingPerformanceTile(
                  rank: index + 1,
                  stat: statistics.settingPerformance[index],
                  isEnglish: isEnglish,
                  now: now,
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildChangePerformance(
    BuildContext context,
    RunLogStatistics statistics,
    bool isEnglish,
    DateTime now,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(isEnglish, 'Changed item ranking', '変更項目ランキング'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                isEnglish,
                'Changed setting items are grouped with the lap times recorded after the change.',
                '変更した項目ごとに、その変更後に記録したタイムを集計します。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.72),
                  ),
            ),
            const SizedBox(height: 16),
            if (statistics.changePerformance.isEmpty)
              Text(_text(
                isEnglish,
                'No changed items with lap data yet.',
                'タイム付きで集計できる変更項目がまだありません。',
              ))
            else
              for (var index = 0;
                  index < statistics.changePerformance.length;
                  index++) ...[
                if (index > 0) const Divider(height: 24),
                _ChangePerformanceTile(
                  rank: index + 1,
                  stat: statistics.changePerformance[index],
                  isEnglish: isEnglish,
                  now: now,
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeelTagPerformance(
    BuildContext context,
    RunLogStatistics statistics,
    bool isEnglish,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(isEnglish, 'Feel tags', 'フィーリングタグ'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                isEnglish,
                'Use tag performance as a hint, then confirm against track conditions.',
                'タグ別のタイム傾向を確認し、路面条件と合わせて判断してください。',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.72),
                  ),
            ),
            const SizedBox(height: 16),
            if (statistics.feelTagPerformance.isEmpty)
              Text(_text(
                isEnglish,
                'No tagged timed run logs yet.',
                'タグ付きのタイム記録がまだありません。',
              ))
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final tagPerformance in statistics.feelTagPerformance)
                    _FeelTagPerformancePill(
                      stat: tagPerformance,
                      isEnglish: isEnglish,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    SettingStatistics statistics,
    bool isEnglish,
    DateTime now,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text(
              isEnglish,
              'Your setting activity at a glance',
              '保存してきたセッティングをひと目で確認',
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _text(
              isEnglish,
              'Track save volume, recent momentum, and the chassis you tune most.',
              '保存件数、直近の更新頻度、よく使うシャーシをまとめて表示します。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoChip(
                label: _text(isEnglish, 'Total', '総保存数'),
                value: '${statistics.totalSettings}',
              ),
              _InfoChip(
                label: _text(isEnglish, 'Last 30 days', '直近30日'),
                value: '${statistics.settingsLast30Days}',
              ),
              _InfoChip(
                label: _text(isEnglish, 'Cars in use', '利用中の車種'),
                value:
                    '${statistics.activeCars}/${statistics.totalRegisteredCars}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _FrostedPanel(
                  label: _text(isEnglish, 'Top car', '最多保存の車種'),
                  value: statistics.topCar?.carName ??
                      _text(isEnglish, 'No data', 'データなし'),
                  subtitle: statistics.topCar == null
                      ? null
                      : _text(
                          isEnglish,
                          '${statistics.topCar!.count} saves',
                          '${statistics.topCar!.count}件保存',
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FrostedPanel(
                  label: _text(isEnglish, 'Top maker', '最多保存のメーカー'),
                  value: statistics.topManufacturer?.manufacturerName ??
                      _text(isEnglish, 'No data', 'データなし'),
                  subtitle: statistics.latestActivity == null
                      ? null
                      : _text(
                          isEnglish,
                          'Latest ${_formatDateTime(statistics.latestActivity!, isEnglish)}',
                          '最新 ${_formatDateTime(statistics.latestActivity!, isEnglish)}',
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _text(
              isEnglish,
              'Updated ${_formatRelativeTime(statistics.latestActivity, now, isEnglish)}',
              '${_formatRelativeTime(statistics.latestActivity, now, isEnglish)}に更新',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(
    BuildContext context,
    SettingStatistics statistics,
    bool isEnglish,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.18,
      children: [
        _MetricTile(
          icon: Icons.directions_car_rounded,
          title: _text(isEnglish, 'Active cars', '利用中の車種'),
          value: '${statistics.activeCars}',
          detail: _text(
            isEnglish,
            '${statistics.totalRegisteredCars} registered',
            '登録 ${statistics.totalRegisteredCars} 台',
          ),
        ),
        _MetricTile(
          icon: Icons.exposure_plus_1_rounded,
          title: _text(isEnglish, 'Average per car', '車種あたり平均'),
          value: _formatAverage(statistics.averageSettingsPerCar),
          detail: _text(isEnglish, 'saved setups', '保存セット'),
        ),
        _MetricTile(
          icon: Icons.factory_rounded,
          title: _text(isEnglish, 'Top maker', '最多メーカー'),
          value: statistics.topManufacturer?.manufacturerName ??
              _text(isEnglish, 'No data', 'データなし'),
          detail: statistics.topManufacturer == null
              ? _text(isEnglish, 'No saves yet', '保存履歴なし')
              : _text(
                  isEnglish,
                  '${statistics.topManufacturer!.count} saves',
                  '${statistics.topManufacturer!.count}件保存',
                ),
        ),
        _MetricTile(
          icon: Icons.schedule_rounded,
          title: _text(isEnglish, 'Latest save', '最新の保存'),
          value: statistics.latestActivity == null
              ? _text(isEnglish, 'No data', 'データなし')
              : _formatDate(statistics.latestActivity!, isEnglish),
          detail: statistics.latestActivity == null
              ? _text(isEnglish, 'Waiting for activity', '保存を待機中')
              : _formatTime(statistics.latestActivity!, isEnglish),
        ),
      ],
    );
  }

  Widget _buildMonthlyActivity(
    BuildContext context,
    SettingStatistics statistics,
    bool isEnglish,
    DateTime now,
  ) {
    final theme = Theme.of(context);
    final maxCount = statistics.monthlyActivity.fold<int>(
      0,
      (current, item) => math.max(current, item.count),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(
                isEnglish,
                'Saved setups over the last six months',
                '直近6か月の保存件数の推移',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                isEnglish,
                'A quick view of how often you capture new setup snapshots each month.',
                '毎月どれくらいの頻度でセッティングを保存しているかを確認できます。',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final month in statistics.monthlyActivity)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _MonthlyBar(
                          stat: month,
                          maxCount: maxCount,
                          isEnglish: isEnglish,
                          now: now,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageBreakdown(
    BuildContext context,
    SettingStatistics statistics,
    bool isEnglish,
    DateTime now,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(isEnglish, 'Chassis ranking', 'シャーシ別ランキング'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                isEnglish,
                'See which cars and manufacturers dominate your setup history.',
                'どの車種とメーカーに保存履歴が集中しているかを確認できます。',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 20),
            for (var index = 0;
                index < statistics.carUsage.length;
                index++) ...[
              if (index > 0) const Divider(height: 24),
              _CarUsageTile(
                rank: index + 1,
                stat: statistics.carUsage[index],
                isEnglish: isEnglish,
                now: now,
              ),
            ],
            const SizedBox(height: 20),
            Text(
              _text(isEnglish, 'Manufacturer share', 'メーカー別シェア'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final manufacturer in statistics.manufacturerUsage)
                  _ManufacturerPill(
                    manufacturer: manufacturer,
                    isEnglish: isEnglish,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(
    BuildContext context,
    SettingStatistics statistics,
    bool isEnglish,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _text(
                isEnglish,
                'Most recent saved setups',
                '最新の保存セッティング',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                isEnglish,
                'The latest entries are listed here so you can jump back into recent work quickly.',
                '直近で保存した設定をすぐに振り返れるよう、最新の履歴を並べています。',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),
            for (var index = 0;
                index < statistics.recentActivity.length;
                index++) ...[
              if (index > 0) const Divider(height: 24),
              _RecentActivityTile(
                setting: statistics.recentActivity[index],
                isEnglish: isEnglish,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isEnglish) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _text(isEnglish, 'No statistics yet', 'まだ統計情報がありません'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _text(
                isEnglish,
                'Save a few setups first. This page will summarize your activity automatically.',
                'まずはセッティングをいくつか保存してください。保存履歴が増えると、この画面に自動で統計が表示されます。',
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CarSelectionPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _text(isEnglish, 'Create a setting', 'セッティングを作成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _FrostedPanel extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;

  const _FrostedPanel({
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  const _MetricTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const Spacer(),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyBar extends StatelessWidget {
  final MonthlyActivityStatistics stat;
  final int maxCount;
  final bool isEnglish;
  final DateTime now;

  const _MonthlyBar({
    required this.stat,
    required this.maxCount,
    required this.isEnglish,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = maxCount == 0 ? 0.0 : stat.count / maxCount;
    final barHeight = 24 + (96 * ratio);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${stat.count}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.72),
                    theme.colorScheme.primary,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _formatMonth(stat.month, now, isEnglish),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CarUsageTile extends StatelessWidget {
  final int rank;
  final CarUsageStatistics stat;
  final bool isEnglish;
  final DateTime now;

  const _CarUsageTile({
    required this.rank,
    required this.stat,
    required this.isEnglish,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$rank',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      stat.carName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _text(
                      isEnglish,
                      '${stat.count} saves',
                      '${stat.count}件',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${stat.manufacturerName}  •  ${_formatPercentage(stat.share)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: stat.share.clamp(0.0, 1.0),
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _text(
                  isEnglish,
                  'Last used ${_formatRelativeTime(stat.lastUsedAt, now, isEnglish)}',
                  '${_formatRelativeTime(stat.lastUsedAt, now, isEnglish)}に使用',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ManufacturerPill extends StatelessWidget {
  final ManufacturerUsageStatistics manufacturer;
  final bool isEnglish;

  const _ManufacturerPill({
    required this.manufacturer,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            manufacturer.manufacturerName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _text(
              isEnglish,
              '${manufacturer.count} saves • ${_formatPercentage(manufacturer.share)}',
              '${manufacturer.count}件 • ${_formatPercentage(manufacturer.share)}',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  final SavedSetting setting;
  final bool isEnglish;

  const _RecentActivityTile({
    required this.setting,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.history_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                setting.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                setting.car.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(setting.createdAt, isEnglish),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(setting.createdAt, isEnglish),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FastestRunTile extends StatelessWidget {
  final int rank;
  final RunLog runLog;
  final bool isEnglish;

  const _FastestRunTile({
    required this.rank,
    required this.runLog,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingName = runLog.resultSettingName ?? runLog.baseSettingName;
    final feelLabels = runLog.feelTagIds
        .map((id) => runFeelTagLabel(id, isEnglish))
        .join(', ');
    final conditionText = formatRunConditions(runLog, isEnglish);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RankBadge(rank: rank),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatBestLapMillis(runLog.bestLapMillis),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(runLog.runAt, isEnglish),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                runLog.car.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (settingName != null) ...[
                const SizedBox(height: 4),
                Text(
                  settingName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (feelLabels.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  feelLabels,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
              if (conditionText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  conditionText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingPerformanceTile extends StatelessWidget {
  final int rank;
  final SettingRunPerformance stat;
  final bool isEnglish;
  final DateTime now;

  const _SettingPerformanceTile({
    required this.rank,
    required this.stat,
    required this.isEnglish,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RankBadge(rank: rank),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      stat.settingName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatBestLapMillis(stat.bestLapMillis),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${stat.carName} / ${stat.isResultSetting ? _text(isEnglish, 'Result', '結果セット') : _text(isEnglish, 'Base', 'ベース')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _text(
                  isEnglish,
                  '${stat.runCount} runs / avg ${formatBestLapMillis(stat.averageLapMillis)} / last ${_formatRelativeTime(stat.lastRunAt, now, isEnglish)}',
                  '${stat.runCount}走行 / 平均 ${formatBestLapMillis(stat.averageLapMillis)} / ${_formatRelativeTime(stat.lastRunAt, now, isEnglish)}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChangePerformanceTile extends StatelessWidget {
  final int rank;
  final ChangeRunPerformance stat;
  final bool isEnglish;
  final DateTime now;

  const _ChangePerformanceTile({
    required this.rank,
    required this.stat,
    required this.isEnglish,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fastestValue = stat.fastestAfterValue?.toString();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RankBadge(rank: rank),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      stat.settingLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatBestLapMillis(stat.bestLapMillis),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (fastestValue != null && fastestValue.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _text(
                    isEnglish,
                    'Fastest value: $fastestValue',
                    '最速時の値: $fastestValue',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                _text(
                  isEnglish,
                  '${stat.runCount} runs / avg ${formatBestLapMillis(stat.averageLapMillis)} / last ${_formatRelativeTime(stat.lastRunAt, now, isEnglish)}',
                  '${stat.runCount}走行 / 平均 ${formatBestLapMillis(stat.averageLapMillis)} / ${_formatRelativeTime(stat.lastRunAt, now, isEnglish)}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeelTagPerformancePill extends StatelessWidget {
  final FeelTagRunPerformance stat;
  final bool isEnglish;

  const _FeelTagPerformancePill({
    required this.stat,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            runFeelTagLabel(stat.tagId, isEnglish),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _text(
              isEnglish,
              '${stat.runCount} runs / best ${formatBestLapMillis(stat.bestLapMillis)}',
              '${stat.runCount}走行 / 最速 ${formatBestLapMillis(stat.bestLapMillis)}',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _text(
              isEnglish,
              'avg ${formatBestLapMillis(stat.averageLapMillis)}',
              '平均 ${formatBestLapMillis(stat.averageLapMillis)}',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$rank',
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

String _text(bool isEnglish, String english, String japanese) {
  return isEnglish ? english : japanese;
}

String _formatAverage(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.05) {
    return rounded.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _formatPercentage(double value) {
  return '${(value * 100).round()}%';
}

String _formatDate(DateTime date, bool isEnglish) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  if (isEnglish) {
    return '${date.year}-$month-$day';
  }
  return '${date.year}年$month月$day日';
}

String _formatTime(DateTime date, bool isEnglish) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  if (isEnglish) {
    return '$hour:$minute';
  }
  return '$hour:$minute';
}

String _formatDateTime(DateTime date, bool isEnglish) {
  return '${_formatDate(date, isEnglish)} ${_formatTime(date, isEnglish)}';
}

String _formatMonth(DateTime month, DateTime now, bool isEnglish) {
  const englishMonths = [
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

  if (isEnglish) {
    if (month.year == now.year) {
      return englishMonths[month.month - 1];
    }
    return '${englishMonths[month.month - 1]}\n${month.year}';
  }

  if (month.year == now.year) {
    return '${month.month}月';
  }
  return '${month.year}\n${month.month}月';
}

String _formatRelativeTime(DateTime? date, DateTime now, bool isEnglish) {
  if (date == null) {
    return isEnglish ? 'not available' : '記録なし';
  }

  final difference = now.difference(date);
  if (difference.inMinutes < 1) {
    return isEnglish ? 'just now' : 'たった今';
  }
  if (difference.inHours < 1) {
    return isEnglish
        ? '${difference.inMinutes} min ago'
        : '${difference.inMinutes}分前';
  }
  if (difference.inDays < 1) {
    return isEnglish
        ? '${difference.inHours} hrs ago'
        : '${difference.inHours}時間前';
  }
  if (difference.inDays < 30) {
    return isEnglish
        ? '${difference.inDays} days ago'
        : '${difference.inDays}日前';
  }
  final months = (difference.inDays / 30).floor();
  if (months < 12) {
    return isEnglish ? '$months months ago' : '$monthsか月前';
  }
  final years = (months / 12).floor();
  return isEnglish ? '$years years ago' : '$years年前';
}
