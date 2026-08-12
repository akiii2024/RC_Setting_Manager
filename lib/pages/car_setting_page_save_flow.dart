part of 'car_setting_page.dart';

mixin _CarSettingSaveFlow on State<CarSettingPage> {
  Map<String, dynamic> get settings;
  bool get _isEditing;
  String? get _activeSavedSettingId;
  TextEditingController get _settingNameController;

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
            onPressed: _saveSetting,
            icon: const Icon(Icons.save),
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
              onPressed: _saveAsNewSetting,
              icon: const Icon(Icons.copy_rounded),
              label: Text(isEnglish ? 'Save as New' : '新規保存'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _updateSetting,
              icon: const Icon(Icons.save),
              label: Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
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
                ? 'You saved a setting for ${currentCar.name}. Add this model to My Garage for quicker access next time?'
                : '${currentCar.name} の設定を保存しました。次回から見つけやすいように、マイガレージへ追加しますか？',
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

    if (action == _GaragePromptAction.add) {
      await settingsProvider.setGarageMembership(currentCar.id, true);
    } else if (action == _GaragePromptAction.suppress) {
      await settingsProvider.setGaragePromptSuppressed(currentCar.id, true);
    }

    return action;
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

  void _saveSetting() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    if (_settingNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isEnglish ? 'Please enter a setting name' : 'セッティング名を入力してください'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_isEditing && _activeSavedSettingId != null) {
      // Update existing setting
      SavedSetting? existingSetting;
      for (final setting in settingsProvider.savedSettings) {
        if (setting.id == _activeSavedSettingId) {
          existingSetting = setting;
          break;
        }
      }
      final updatedSetting = SavedSetting(
        id: _activeSavedSettingId!,
        name: _settingNameController.text,
        createdAt: DateTime.now(),
        car: widget.originalCar,
        settings: settings,
        kind: existingSetting?.kind ?? SavedSettingKind.manual,
        sourceRunLogId: existingSetting?.sourceRunLogId,
        parentSettingId: existingSetting?.parentSettingId,
      );

      await settingsProvider.updateSetting(updatedSetting);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Setting updated' : '設定を更新しました')),
        );
        Navigator.pop(context);
      }
    } else {
      // Add new setting
      await settingsProvider.addSetting(
        _settingNameController.text,
        widget.originalCar,
        settings,
      );
      final promptAction = await _showGaragePromptIfNeeded(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _savedSnackBarMessage(isEnglish, promptAction),
            ),
          ),
        );
        Navigator.pop(context);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Setting saved' : '設定を保存しました')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _saveAsNewSetting() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    if (_settingNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isEnglish ? 'Please enter a setting name' : 'セッティング名を入力してください'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Add new setting
    await settingsProvider.addSetting(
      _settingNameController.text,
      widget.originalCar,
      settings,
    );
    final promptAction = await _showGaragePromptIfNeeded(settingsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _savedSnackBarMessage(isEnglish, promptAction),
          ),
        ),
      );
      Navigator.pop(context);
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEnglish ? 'Setting saved' : '設定を保存しました')),
      );
      Navigator.pop(context);
    }
  }

  void _updateSetting() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    if (_settingNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isEnglish ? 'Please enter a setting name' : 'セッティング名を入力してください'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_isEditing && _activeSavedSettingId != null) {
      // Update existing setting
      SavedSetting? existingSetting;
      for (final setting in settingsProvider.savedSettings) {
        if (setting.id == _activeSavedSettingId) {
          existingSetting = setting;
          break;
        }
      }
      final updatedSetting = SavedSetting(
        id: _activeSavedSettingId!,
        name: _settingNameController.text,
        createdAt: DateTime.now(),
        car: widget.originalCar,
        settings: settings,
        kind: existingSetting?.kind ?? SavedSettingKind.manual,
        sourceRunLogId: existingSetting?.sourceRunLogId,
        parentSettingId: existingSetting?.parentSettingId,
      );

      await settingsProvider.updateSetting(updatedSetting);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Setting updated' : '設定を更新しました')),
        );
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish ? 'No setting to update' : '更新する設定がありません'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
