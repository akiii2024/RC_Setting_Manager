part of 'car_setting_page.dart';

mixin _CarSettingSaveFlow on State<CarSettingPage> {
  Map<String, dynamic> get settings;
  bool get _isEditing;
  String? get _activeSavedSettingId;
  TextEditingController get _settingNameController;
  bool get _isSavingSetting;
  set _isSavingSetting(bool value);

  Widget _buildSaveActionBar(bool isEnglish) {
    final primaryLabel = _isEditing
        ? (isEnglish ? 'Update Setting' : '設定を更新')
        : (isEnglish ? 'Save Setting' : '設定を保存');

    if (!_isEditing) {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSavingSetting ? null : _saveSetting,
            icon: _saveButtonIcon(),
            label: Text(primaryLabel),
          ),
        ),
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSavingSetting ? null : _saveAsNewSetting,
              icon: _isSavingSetting
                  ? _saveButtonIcon()
                  : const Icon(Icons.copy_rounded),
              label: Text(isEnglish ? 'Save as New' : '新規保存'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _isSavingSetting ? null : _updateSetting,
              icon: _saveButtonIcon(),
              label: Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButtonIcon() {
    if (!_isSavingSetting) {
      return const Icon(Icons.save);
    }
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  bool _beginSettingSave() {
    if (_isSavingSetting) {
      return false;
    }
    setState(() => _isSavingSetting = true);
    return true;
  }

  void _endSettingSave() {
    if (mounted) {
      setState(() => _isSavingSetting = false);
    }
  }

  void _finishSettingSaveAndPop() {
    if (!mounted) return;
    setState(() => _isSavingSetting = false);
    Navigator.pop(context);
  }

  Future<_GaragePromptAction?> _showGaragePromptIfNeeded(
    SettingsProvider settingsProvider,
  ) async {
    final currentCar = settingsProvider.getCarById(widget.originalCar.id);
    if (currentCar == null ||
        currentCar.isInGarage ||
        currentCar.suppressGaragePrompt) {
      return null;
    }

    final isEnglish = settingsProvider.isEnglish;
    final action = await showDialog<_GaragePromptAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isEnglish ? 'Add to My Garage?' : 'マイガレージに追加しますか？',
          ),
          content: Text(
            isEnglish
                ? 'Add ${currentCar.name} to My Garage when this setting is saved?'
                : '設定の保存と同時に ${currentCar.name} をマイガレージへ追加しますか？',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_GaragePromptAction.notNow);
              },
              child: Text(isEnglish ? 'Not now' : '今はしない'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_GaragePromptAction.suppress);
              },
              child: Text(
                isEnglish ? "Don't show again" : '今後は表示しない',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_GaragePromptAction.add);
              },
              child: Text(
                isEnglish ? 'Add to My Garage' : 'マイガレージに追加',
              ),
            ),
          ],
        );
      },
    );

    return mounted ? action : null;
  }

  String _savedSnackBarMessage(
    bool isEnglish,
    _GaragePromptAction? action,
  ) {
    switch (action) {
      case _GaragePromptAction.add:
        return isEnglish
            ? 'Setting saved and added to My Garage'
            : '設定を保存し、マイガレージに追加しました';
      case _GaragePromptAction.suppress:
        return isEnglish
            ? 'Setting saved. Future garage prompts disabled for this model'
            : '設定を保存しました。この車種では今後ガレージ確認を表示しません';
      case _GaragePromptAction.notNow:
      case null:
        return isEnglish ? 'Setting saved' : '設定を保存しました';
    }
  }

  Future<void> _saveSetting() async {
    if (!_beginSettingSave()) return;
    try {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final isEnglish = settingsProvider.isEnglish;
      if (!_validateSettingName(isEnglish)) return;

      if (_isEditing && _activeSavedSettingId != null) {
        await _performSettingUpdate(settingsProvider, isEnglish);
      } else {
        await _performNewSettingSave(settingsProvider, isEnglish);
      }
    } finally {
      _endSettingSave();
    }
  }

  Future<void> _saveAsNewSetting() async {
    if (!_beginSettingSave()) return;
    try {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final isEnglish = settingsProvider.isEnglish;
      if (!_validateSettingName(isEnglish)) return;
      await _performNewSettingSave(settingsProvider, isEnglish);
    } finally {
      _endSettingSave();
    }
  }

  Future<void> _updateSetting() async {
    if (!_beginSettingSave()) return;
    try {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final isEnglish = settingsProvider.isEnglish;
      if (!_validateSettingName(isEnglish)) return;

      if (_isEditing && _activeSavedSettingId != null) {
        await _performSettingUpdate(settingsProvider, isEnglish);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEnglish ? 'No setting to update' : '更新する設定がありません'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      _endSettingSave();
    }
  }

  bool _validateSettingName(bool isEnglish) {
    if (_settingNameController.text.trim().isNotEmpty) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEnglish ? 'Please enter a setting name' : 'セッティング名を入力してください',
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
    return false;
  }

  Future<void> _performNewSettingSave(
    SettingsProvider settingsProvider,
    bool isEnglish,
  ) async {
    final garageAction = await _showGaragePromptIfNeeded(settingsProvider);
    if (!mounted) return;

    final result = await settingsProvider.addSettingWithCarUpdate(
      _settingNameController.text.trim(),
      widget.originalCar,
      Map<String, dynamic>.from(settings),
      isInGarage: garageAction == _GaragePromptAction.add ? true : null,
      suppressGaragePrompt:
          garageAction == _GaragePromptAction.suppress ? true : null,
    );
    if (!mounted ||
        !handleSettingsOperationResult(
          context,
          result,
          isEnglish: isEnglish,
        )) {
      return;
    }
    final savedSetting = switch (result) {
      SettingsOperationSuccess<SavedSetting>(:final value) => value,
      SettingsOperationFailure<SavedSetting>() => null,
    };
    if (savedSetting == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_savedSnackBarMessage(isEnglish, garageAction))),
    );
    _finishSettingSaveAndPop();
  }

  Future<void> _performSettingUpdate(
    SettingsProvider settingsProvider,
    bool isEnglish,
  ) async {
    SavedSetting? existingSetting;
    for (final setting in settingsProvider.savedSettings) {
      if (setting.id == _activeSavedSettingId) {
        existingSetting = setting;
        break;
      }
    }
    if (existingSetting == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'The setting no longer exists.'
              : '対象のセッティングが見つかりません。'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final updatedSetting = SavedSetting(
      id: existingSetting.id,
      name: _settingNameController.text.trim(),
      createdAt: DateTime.now(),
      car: widget.originalCar,
      settings: Map<String, dynamic>.from(settings),
      kind: existingSetting.kind,
      sourceRunLogId: existingSetting.sourceRunLogId,
      parentSettingId: existingSetting.parentSettingId,
    );
    final result = await settingsProvider.updateSetting(updatedSetting);
    if (!mounted ||
        !handleSettingsOperationResult(
          context,
          result,
          isEnglish: isEnglish,
        )) {
      return;
    }
    final savedSetting = switch (result) {
      SettingsOperationSuccess<SavedSetting?>(:final value) => value,
      SettingsOperationFailure<SavedSetting?>() => null,
    };
    if (savedSetting == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'The setting was not updated.'
              : 'セッティングは更新されませんでした。'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isEnglish ? 'Setting updated' : '設定を更新しました')),
    );
    _finishSettingSaveAndPop();
  }
}
