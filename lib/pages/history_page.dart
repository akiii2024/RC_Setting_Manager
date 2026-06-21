import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/run_feel_tags.dart';
import '../models/car.dart';
import '../models/run_log.dart';
import '../models/saved_setting.dart';
import '../providers/settings_provider.dart';
import '../utils/run_log_formatters.dart';
import 'car_setting_page.dart';

class HistoryPage extends StatefulWidget {
  final Car? filterCar;

  const HistoryPage({
    super.key,
    this.filterCar,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

enum _HistoryView {
  settings,
  runLogs,
}

enum _RunLogSort {
  newest,
  fastest,
}

class _HistoryPageState extends State<HistoryPage> {
  _HistoryView _selectedView = _HistoryView.settings;
  _RunLogSort _runLogSort = _RunLogSort.newest;
  String? _runLogCarId;
  String? _runLogTagId;

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final savedSettings = widget.filterCar == null
            ? settingsProvider.savedSettings
            : settingsProvider.savedSettings
                .where((setting) => setting.car.id == widget.filterCar!.id)
                .toList(growable: false);
        final sourceRunLogs = widget.filterCar == null
            ? settingsProvider.runLogs
            : settingsProvider.runLogs
                .where((runLog) => runLog.car.id == widget.filterCar!.id)
                .toList(growable: false);
        final runLogs = _applyRunLogFilters(sourceRunLogs);
        final isEnglish = settingsProvider.isEnglish;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<_HistoryView>(
                segments: [
                  ButtonSegment<_HistoryView>(
                    value: _HistoryView.settings,
                    icon: const Icon(Icons.tune_rounded),
                    label: Text(isEnglish ? 'Settings' : '設定履歴'),
                  ),
                  ButtonSegment<_HistoryView>(
                    value: _HistoryView.runLogs,
                    icon: const Icon(Icons.timer_rounded),
                    label: Text(isEnglish ? 'Run Logs' : '走行ログ'),
                  ),
                ],
                selected: {_selectedView},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedView = selection.first;
                  });
                },
              ),
            ),
            Expanded(
              child: _selectedView == _HistoryView.settings
                  ? _buildSettingsView(context, savedSettings, isEnglish)
                  : _buildRunLogsView(
                      context,
                      runLogs,
                      sourceRunLogs,
                      settingsProvider,
                      isEnglish,
                    ),
            ),
          ],
        );
      },
    );
  }

  List<RunLog> _applyRunLogFilters(List<RunLog> sourceRunLogs) {
    var filtered = sourceRunLogs.where((runLog) {
      if (widget.filterCar == null &&
          _runLogCarId != null &&
          runLog.car.id != _runLogCarId) {
        return false;
      }
      if (_runLogTagId != null && !runLog.feelTagIds.contains(_runLogTagId)) {
        return false;
      }
      return true;
    }).toList(growable: false);

    filtered = List<RunLog>.from(filtered);
    if (_runLogSort == _RunLogSort.fastest) {
      filtered.sort((a, b) {
        final aHasTime = a.bestLapMillis > 0;
        final bHasTime = b.bestLapMillis > 0;
        if (aHasTime != bHasTime) {
          return aHasTime ? -1 : 1;
        }
        if (aHasTime && bHasTime) {
          final lapComparison = a.bestLapMillis.compareTo(b.bestLapMillis);
          if (lapComparison != 0) {
            return lapComparison;
          }
        }
        return b.runAt.compareTo(a.runAt);
      });
    } else {
      filtered.sort((a, b) => b.runAt.compareTo(a.runAt));
    }

    return filtered;
  }

  Widget _buildSettingsView(
    BuildContext context,
    List<SavedSetting> savedSettings,
    bool isEnglish,
  ) {
    if (savedSettings.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.history_rounded,
        title: widget.filterCar == null
            ? (isEnglish ? 'No history available' : '履歴がありません')
            : (isEnglish
                ? 'No history for ${widget.filterCar!.name}'
                : '${widget.filterCar!.name} の履歴がありません'),
        message: widget.filterCar == null
            ? (isEnglish
                ? 'Your saved settings will appear here'
                : '保存された設定がここに表示されます')
            : (isEnglish
                ? 'Saved settings for this car will appear here'
                : 'この車両の保存済み設定がここに表示されます'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: savedSettings.length,
      itemBuilder: (context, index) {
        final setting = savedSettings[index];
        return _buildHistoryItem(context, setting);
      },
    );
  }

  Widget _buildRunLogsView(
    BuildContext context,
    List<RunLog> runLogs,
    List<RunLog> sourceRunLogs,
    SettingsProvider settingsProvider,
    bool isEnglish,
  ) {
    if (sourceRunLogs.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.timer_rounded,
        title: widget.filterCar == null
            ? (isEnglish ? 'No run logs yet' : '走行ログがありません')
            : (isEnglish
                ? 'No run logs for ${widget.filterCar!.name}'
                : '${widget.filterCar!.name} の走行ログがありません'),
        message: isEnglish
            ? 'Quick run logs will appear here after each run.'
            : '走行後に記録したタイムと感触がここに表示されます',
      );
    }

    return Column(
      children: [
        _buildRunLogControls(
          context,
          sourceRunLogs,
          isEnglish,
        ),
        Expanded(
          child: runLogs.isEmpty
              ? _buildEmptyState(
                  context,
                  icon: Icons.filter_alt_off_rounded,
                  title: isEnglish ? 'No matching run logs' : '条件に合う走行ログがありません',
                  message: isEnglish
                      ? 'Change the car, tag, or sort filters.'
                      : '車種やタグの絞り込み条件を変更してください。',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: runLogs.length,
                  itemBuilder: (context, index) {
                    final runLog = runLogs[index];
                    return _buildRunLogItem(
                      context,
                      runLog,
                      settingsProvider,
                      isEnglish,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRunLogControls(
    BuildContext context,
    List<RunLog> sourceRunLogs,
    bool isEnglish,
  ) {
    final cars = _uniqueCarsFromRunLogs(sourceRunLogs);
    final tagIds =
        sourceRunLogs.expand((runLog) => runLog.feelTagIds).toSet().toList()
          ..sort(
            (a, b) => runFeelTagLabel(a, isEnglish).compareTo(
              runFeelTagLabel(b, isEnglish),
            ),
          );
    final selectedCarValue =
        cars.any((car) => car.id == _runLogCarId) ? (_runLogCarId ?? '') : '';
    final selectedTagValue =
        tagIds.contains(_runLogTagId) ? (_runLogTagId ?? '') : '';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SegmentedButton<_RunLogSort>(
              segments: [
                ButtonSegment<_RunLogSort>(
                  value: _RunLogSort.newest,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(isEnglish ? 'Newest' : '新しい順'),
                ),
                ButtonSegment<_RunLogSort>(
                  value: _RunLogSort.fastest,
                  icon: const Icon(Icons.speed_rounded),
                  label: Text(isEnglish ? 'Fastest' : 'タイム順'),
                ),
              ],
              selected: {_runLogSort},
              onSelectionChanged: (selection) {
                setState(() {
                  _runLogSort = selection.first;
                });
              },
            ),
            const SizedBox(height: 12),
            if (widget.filterCar == null) ...[
              DropdownButtonFormField<String>(
                initialValue: selectedCarValue,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Car' : '車種',
                  prefixIcon: const Icon(Icons.directions_car_rounded),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: '',
                    child: Text(isEnglish ? 'All cars' : 'すべての車種'),
                  ),
                  ...cars.map(
                    (car) => DropdownMenuItem<String>(
                      value: car.id,
                      child: Text(car.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _runLogCarId =
                        value == null || value.isEmpty ? null : value;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              initialValue: selectedTagValue,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Feel tag' : 'フィーリングタグ',
                prefixIcon: const Icon(Icons.sell_rounded),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(isEnglish ? 'All tags' : 'すべてのタグ'),
                ),
                ...tagIds.map(
                  (tagId) => DropdownMenuItem<String>(
                    value: tagId,
                    child: Text(runFeelTagLabel(tagId, isEnglish)),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _runLogTagId = value == null || value.isEmpty ? null : value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Car> _uniqueCarsFromRunLogs(List<RunLog> runLogs) {
    final seen = <String>{};
    final cars = <Car>[];
    for (final runLog in runLogs) {
      if (seen.add(runLog.car.id)) {
        cars.add(runLog.car);
      }
    }
    cars.sort((a, b) => a.name.compareTo(b.name));
    return cars;
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(24),
              child: Icon(
                icon,
                size: 80,
                color: colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, SavedSetting setting) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    theme.colorScheme.secondary.withValues(alpha: 0.1),
                radius: 28,
                child: Icon(
                  Icons.sports_motorsports_rounded,
                  color: theme.colorScheme.secondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setting.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (setting.kind == SavedSettingKind.runResult) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: const Icon(Icons.timer_rounded, size: 16),
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            isEnglish ? 'Run result' : '走行結果',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.directions_car_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          setting.car.name,
                          style: TextStyle(
                            fontSize: 15,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(setting.createdAt, isEnglish),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunLogItem(
    BuildContext context,
    RunLog runLog,
    SettingsProvider settingsProvider,
    bool isEnglish,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final feelLabels = runLog.feelTagIds
        .map((id) => runFeelTagLabel(id, isEnglish))
        .join(', ');
    final conditionText = formatRunConditions(runLog, isEnglish);
    final linkedSetting = _findLinkedSetting(settingsProvider, runLog);
    final linkedSettingName =
        runLog.resultSettingName ?? runLog.baseSettingName;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.timer_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatBestLapMillis(runLog.bestLapMillis)} sec',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${runLog.car.name} / ${_formatDate(runLog.runAt, isEnglish)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (conditionText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          conditionText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isEnglish ? 'Delete run log' : '走行ログを削除',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmDeleteRunLog(
                    context,
                    settingsProvider,
                    runLog,
                    isEnglish,
                  ),
                ),
              ],
            ),
            if (feelLabels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                feelLabels,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (runLog.memo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                runLog.memo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (linkedSettingName != null || runLog.changes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (linkedSettingName != null)
                    linkedSetting == null
                        ? Chip(
                            avatar: const Icon(Icons.tune_rounded, size: 18),
                            label: Text(linkedSettingName),
                          )
                        : ActionChip(
                            avatar:
                                const Icon(Icons.open_in_new_rounded, size: 18),
                            label: Text(linkedSettingName),
                            onPressed: () =>
                                _openSavedSetting(context, linkedSetting),
                          ),
                  if (runLog.changes.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(
                        isEnglish
                            ? '${runLog.changes.length} changes'
                            : '${runLog.changes.length}件の変更',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  SavedSetting? _findLinkedSetting(
    SettingsProvider settingsProvider,
    RunLog runLog,
  ) {
    final settingIds = [
      runLog.resultSettingId,
      runLog.baseSettingId,
    ].whereType<String>();

    for (final settingId in settingIds) {
      for (final setting in settingsProvider.savedSettings) {
        if (setting.id == settingId) {
          return setting;
        }
      }
    }
    return null;
  }

  void _openSavedSetting(BuildContext context, SavedSetting setting) {
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

  Future<void> _confirmDeleteRunLog(
    BuildContext context,
    SettingsProvider settingsProvider,
    RunLog runLog,
    bool isEnglish,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEnglish ? 'Delete run log?' : '走行ログを削除しますか？'),
        content: Text(
          isEnglish
              ? 'This removes only the run log. Linked saved setups remain.'
              : '削除されるのは走行ログのみです。紐づく保存セットは残ります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isEnglish ? 'Delete' : '削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await settingsProvider.deleteRunLog(runLog.id);
    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(isEnglish ? 'Run log deleted.' : '走行ログを削除しました。'),
      ),
    );
  }

  String _formatDate(DateTime dateTime, bool isEnglish) {
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
        'Dec'
      ];
      final month = months[dateTime.month - 1];
      final day = dateTime.day.toString();
      final year = dateTime.year.toString();
      final hour = dateTime.hour > 12
          ? (dateTime.hour - 12).toString()
          : (dateTime.hour == 0 ? '12' : dateTime.hour.toString());
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$month $day, $year $hour:$minute $period';
    }

    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
