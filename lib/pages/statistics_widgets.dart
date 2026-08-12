part of 'statistics_page.dart';

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
