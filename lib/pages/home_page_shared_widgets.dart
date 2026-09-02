part of 'home_page.dart';

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
        borderRadius: BorderRadius.circular(24),
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
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.38),
            ),
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
                    gradient:
                        isHighlighted ? _expressiveGradient(context) : null,
                    color: isHighlighted
                        ? null
                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
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
    final messenger = ScaffoldMessenger.of(context);
    var deleteInFlight = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => PopScope(
            canPop: !deleteInFlight,
            child: AlertDialog(
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
                  onPressed: deleteInFlight
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(_t(isEnglish, 'Cancel', 'キャンセル')),
                ),
                TextButton(
                  onPressed: deleteInFlight
                      ? null
                      : () async {
                          deleteInFlight = true;
                          setDialogState(() {});
                          try {
                            final result = await settingsProvider
                                .deleteSetting(setting.id);
                            if (!dialogContext.mounted ||
                                !handleSettingsOperationResult(
                                  dialogContext,
                                  result,
                                  isEnglish: isEnglish,
                                )) {
                              return;
                            }
                            final deleted = switch (result) {
                              SettingsOperationSuccess<bool>(:final value) =>
                                value ?? false,
                              SettingsOperationFailure<bool>() => false,
                            };
                            if (!deleted) return;
                            deleteInFlight = false;
                            setDialogState(() {});
                            Navigator.of(dialogContext).pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  _t(isEnglish, 'Setting deleted', '設定を削除しました'),
                                ),
                              ),
                            );
                          } finally {
                            deleteInFlight = false;
                            if (dialogContext.mounted) {
                              setDialogState(() {});
                            }
                          }
                        },
                  child: deleteInFlight
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _t(isEnglish, 'Delete', '削除'),
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                ),
              ],
            ),
          ),
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
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
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
    return FloatingActionButton(
      tooltip: tooltip,
      onPressed: onTap,
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }
}
