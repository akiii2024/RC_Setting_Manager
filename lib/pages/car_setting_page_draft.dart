part of 'car_setting_page.dart';

extension _CarSettingDraft on _CarSettingPageState {
  Map<String, dynamic> _draftValue() => {
        'settings': settings,
        'name': _settingNameController.text,
        'trackName': _trackNameController.text,
      };

  void _scheduleDraft() {
    if (!_draftReady) return;
    final value = _draftValue();
    final encoded = SettingDraftService.encodeDraft(value);
    if (encoded == null || encoded == _lastDraft) return;
    if (_draftService.schedule(value)) {
      _lastDraft = encoded;
    }
  }

  Future<bool> _restoreDraft() async {
    var restored = false;
    Map<String, dynamic>? draft;
    try {
      draft = await _draftService.read();
    } catch (_) {
      // A preferences failure must not block editing.
    }
    if (!mounted) return false;
    if (draft != null) {
      final isEnglish = context.read<SettingsProvider>().isEnglish;
      final restore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(isEnglish ? 'Restore draft?' : '下書きを復元しますか？'),
            content: Text(isEnglish
                ? 'Unsaved changes for this setting were found.'
                : 'このセッティングの未保存の編集内容が見つかりました。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(isEnglish ? 'Discard' : '破棄する'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(isEnglish ? 'Restore' : '復元する'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return false;
      if (restore == true) {
        restored = true;
        setState(() {
          settings = Map<String, dynamic>.from(draft!['settings'] as Map);
          _settingNameController.text = draft['name'] as String;
          _trackNameController.text = draft['trackName'] as String;
        });
      } else {
        await _draftService.clear();
      }
    }
    if (!mounted) return false;
    _lastDraft = SettingDraftService.encodeDraft(_draftValue());
    _draftReady = true;
    return restored;
  }
}
