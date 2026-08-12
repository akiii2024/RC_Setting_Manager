part of 'quick_run_log_page.dart';

class _CourseSuggestionRow extends StatelessWidget {
  final TrackLocation track;
  final VoidCallback onSelect;
  final VoidCallback onDetails;
  final String detailTooltip;

  const _CourseSuggestionRow({
    required this.track,
    required this.onSelect,
    required this.onDetails,
    required this.detailTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: detailTooltip,
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: onDetails,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _CourseDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  final RunSettingChange change;
  final VoidCallback onRemove;

  const _ChangeTile({
    required this.change,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          title: Text(change.settingLabel),
          subtitle: Text(
            '${change.beforeValue ?? '-'} -> ${change.afterValue ?? '-'}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ),
      ),
    );
  }
}

class _RunChangeDialog extends StatefulWidget {
  final List<SettingItem> settings;
  final Map<String, dynamic> baseValues;
  final bool isEnglish;
  final VoidCallback onOpenDetailedEditor;

  const _RunChangeDialog({
    required this.settings,
    required this.baseValues,
    required this.isEnglish,
    required this.onOpenDetailedEditor,
  });

  @override
  State<_RunChangeDialog> createState() => _RunChangeDialogState();
}

class _RunChangeDialogState extends State<_RunChangeDialog> {
  final TextEditingController _afterController = TextEditingController();
  SettingItem? _selectedSetting;
  String? _selectedOption;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedSetting = _firstOrNull(widget.settings);
    _syncAfterInput();
  }

  @override
  void dispose() {
    _afterController.dispose();
    super.dispose();
  }

  bool get _isSupported {
    final setting = _selectedSetting;
    if (setting == null) {
      return false;
    }
    if (setting.type == 'grid' ||
        setting.constraints.containsKey('composite')) {
      return false;
    }
    return setting.type == 'text' ||
        setting.type == 'number' ||
        setting.type == 'slider' ||
        setting.type == 'select';
  }

  void _selectSetting(String key) {
    final setting = widget.settings.firstWhere((item) => item.key == key);
    setState(() {
      _selectedSetting = setting;
      _errorText = null;
      _syncAfterInput();
    });
  }

  void _syncAfterInput() {
    final setting = _selectedSetting;
    _afterController.clear();
    _selectedOption = null;

    if (setting?.type == 'select') {
      final options = setting?.options ?? const <String>[];
      final beforeValue = widget.baseValues[setting!.key]?.toString();
      _selectedOption = options.contains(beforeValue)
          ? beforeValue
          : (options.isNotEmpty ? options.first : null);
    }
  }

  dynamic _afterValue() {
    final setting = _selectedSetting;
    if (setting == null) {
      return null;
    }

    if (setting.type == 'select') {
      return _selectedOption;
    }

    final text = _afterController.text.trim();
    if (setting.type == 'number' || setting.type == 'slider') {
      return double.tryParse(text);
    }

    return text;
  }

  void _submit() {
    final setting = _selectedSetting;
    if (setting == null || !_isSupported) {
      return;
    }

    final afterValue = _afterValue();
    if (afterValue == null || afterValue.toString().trim().isEmpty) {
      setState(() {
        _errorText = _t(
          widget.isEnglish,
          'Enter the new value.',
          '変更後の値を入力してください。',
        );
      });
      return;
    }

    Navigator.of(context).pop(
      RunSettingChange(
        settingKey: setting.key,
        settingLabel: setting.label,
        beforeValue: widget.baseValues[setting.key],
        afterValue: afterValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setting = _selectedSetting;
    final beforeValue = setting == null ? null : widget.baseValues[setting.key];

    return AlertDialog(
      title: Text(_t(widget.isEnglish, 'Add Setting Change', '変更を追加')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('setting-${setting?.key ?? ''}'),
              initialValue: setting?.key,
              decoration: InputDecoration(
                labelText: _t(widget.isEnglish, 'Setting', '項目'),
              ),
              items: widget.settings
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.key,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _selectSetting(value);
                }
              },
            ),
            const SizedBox(height: 12),
            Text(
              '${_t(widget.isEnglish, 'Current', '変更前')}: ${beforeValue ?? '-'}',
            ),
            const SizedBox(height: 12),
            if (!_isSupported)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t(
                    widget.isEnglish,
                    'This setting uses a detailed editor.',
                    'この項目は詳細編集画面で変更してください。',
                  )),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenDetailedEditor();
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: Text(_t(
                      widget.isEnglish,
                      'Open Detail Editor',
                      '詳細編集を開く',
                    )),
                  ),
                ],
              )
            else if (setting?.type == 'select')
              DropdownButtonFormField<String>(
                key: ValueKey('option-${setting?.key ?? ''}'),
                initialValue: _selectedOption,
                decoration: InputDecoration(
                  labelText: _t(widget.isEnglish, 'New value', '変更後'),
                  errorText: _errorText,
                ),
                items: (setting?.options ?? const <String>[])
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOption = value;
                    _errorText = null;
                  });
                },
              )
            else
              TextField(
                controller: _afterController,
                keyboardType:
                    setting?.type == 'number' || setting?.type == 'slider'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                decoration: InputDecoration(
                  labelText: _t(widget.isEnglish, 'New value', '変更後'),
                  errorText: _errorText,
                ),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() {
                      _errorText = null;
                    });
                  }
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t(widget.isEnglish, 'Cancel', 'キャンセル')),
        ),
        FilledButton(
          onPressed: _isSupported ? _submit : null,
          child: Text(_t(widget.isEnglish, 'Add', '追加')),
        ),
      ],
    );
  }
}
