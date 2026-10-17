import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../services/ai_configuration_service.dart';
import '../services/ai_provider_client.dart';

typedef AiConnectionTester = Future<void> Function(
  AiConfiguration configuration,
);

class AiProviderSettingsPage extends StatefulWidget {
  const AiProviderSettingsPage({
    super.key,
    this.configurationService,
    this.connectionTester,
    this.isEnglish = false,
  });

  final AiConfigurationService? configurationService;
  final AiConnectionTester? connectionTester;
  final bool isEnglish;

  @override
  State<AiProviderSettingsPage> createState() => _AiProviderSettingsPageState();
}

class _AiProviderSettingsPageState extends State<AiProviderSettingsPage> {
  late final AiConfigurationService _configurationService;
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  AiProvider _selectedProvider = AiProvider.gemini;
  bool _hasStoredKey = false;
  bool _usesManagedGemini = true;
  bool _developerModeEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureApiKey = true;
  int _loadGeneration = 0;

  bool get _isEnglish => widget.isEnglish;
  bool get _usesFirebase => _usesManagedGemini;

  @override
  void initState() {
    super.initState();
    _configurationService =
        widget.configurationService ?? AiConfigurationService();
    _loadInitialState();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    try {
      final developerModeEnabled =
          await _configurationService.isDeveloperModeEnabled;
      if (!developerModeEnabled) {
        if (!mounted) return;
        setState(() {
          _developerModeEnabled = false;
          _isLoading = false;
        });
        return;
      }
      _developerModeEnabled = true;
      final activeSettings = await _configurationService.activeSettings;
      _usesManagedGemini = activeSettings.usesManagedGemini;
      if (_usesManagedGemini) {
        if (!mounted) return;
        setState(() {
          _selectedProvider = AiProvider.gemini;
          _modelController.text = activeSettings.model;
          _isLoading = false;
        });
        return;
      }
      final provider = await _configurationService.selectedProvider;
      if (!mounted) return;
      _selectedProvider = provider;
      await _loadProvider(provider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(error);
    }
  }

  Future<void> _loadProvider(AiProvider provider) async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _selectedProvider = provider;
      _hasStoredKey = false;
      _apiKeyController.clear();
    });

    try {
      final results = await Future.wait<Object>([
        _configurationService.getModel(provider),
        _usesManagedGemini
            ? Future.value(false)
            : _configurationService.hasApiKey(provider),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _modelController.text = results[0] as String;
        _hasStoredKey = results[1] as bool;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _isLoading = false);
      _showError(error);
    }
  }

  Future<bool> _save() async {
    final model = _modelController.text.trim();
    final enteredApiKey = _apiKeyController.text.trim();
    if (model.isEmpty) {
      _showMessage(_isEnglish ? 'Enter a model name.' : 'モデル名を入力してください。');
      return false;
    }
    if (!_usesManagedGemini && !_hasStoredKey && enteredApiKey.isEmpty) {
      _showMessage(_isEnglish ? 'Enter an API key.' : 'APIキーを入力してください。');
      return false;
    }

    if (!_usesManagedGemini &&
        enteredApiKey.isNotEmpty &&
        !await _confirmRisk(forConnection: false)) {
      return false;
    }
    if (!mounted) return false;
    setState(() => _isSaving = true);
    try {
      await _configurationService.requireDeveloperMode();
      if (_usesManagedGemini) {
        await _configurationService.selectManagedGemini();
      } else if (enteredApiKey.isNotEmpty) {
        await _configurationService.saveConfiguration(
          provider: _selectedProvider,
          model: model,
          apiKey: enteredApiKey,
        );
      } else {
        await _configurationService.selectPersonalProvider(
          provider: _selectedProvider,
          model: model,
        );
      }
      if (!mounted) return false;
      setState(() {
        _hasStoredKey = !_usesManagedGemini;
        _apiKeyController.clear();
      });
      _showMessage(
        _isEnglish
            ? '${_selectedProvider.displayName} settings saved.'
            : '${_selectedProvider.displayName}の設定を保存しました。',
      );
      return true;
    } catch (error) {
      _showError(error);
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    final model = _modelController.text.trim();
    final enteredApiKey = _apiKeyController.text.trim();
    if (model.isEmpty) {
      _showMessage(_isEnglish ? 'Enter a model name.' : 'モデル名を入力してください。');
      return;
    }

    if (enteredApiKey.isNotEmpty && !await _confirmRisk(forConnection: true)) {
      return;
    }
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      await _configurationService.requireDeveloperMode();
      final apiKey = enteredApiKey.isNotEmpty
          ? enteredApiKey
          : await _configurationService.getApiKey(_selectedProvider);
      if (apiKey == null) {
        _showMessage(_isEnglish ? 'Enter an API key.' : 'APIキーを入力してください。');
        return;
      }
      final configuration = AiConfiguration(
        provider: _selectedProvider,
        model: model,
        apiKey: apiKey,
      );
      final tester = widget.connectionTester;
      if (tester != null) {
        await tester(configuration);
      } else {
        final client = AiProviderClient(configuration: configuration);
        try {
          await client.testConnection();
        } finally {
          client.close();
        }
      }
      _showMessage(
        _isEnglish
            ? 'Connected to ${configuration.provider.displayName}.'
            : '${configuration.provider.displayName}への接続を確認しました。',
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _confirmRisk({required bool forConnection}) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
                _isEnglish ? 'Important API key warning' : 'APIキーに関する重要な注意'),
            content: SingleChildScrollView(
              child: Text(_isEnglish
                  ? 'Your API account may be charged. A leaked key may be used by others. Questions, settings, OCR images, and telemetry analysis data may be sent to the selected provider. The key is stored in secure storage (web: this tab memory). Delete the key and set usage limits when needed.'
                  : 'APIアカウントに利用料金が発生する場合があります。キーが漏洩すると第三者に利用される危険があります。相談内容、設定値、OCR画像、走行分析データが選択したプロバイダーへ送信されます。キーはセキュアストレージ（Web版はこのタブのメモリ内）に保存されます。必要に応じてキーを削除し、利用制限を設定してください。'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_isEnglish ? 'Cancel' : 'キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  forConnection
                      ? (_isEnglish ? 'Agree and test connection' : '同意して接続する')
                      : (_isEnglish ? 'Agree and save' : '同意して保存する'),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteApiKey() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_isEnglish ? 'Delete API key?' : 'APIキーを削除しますか？'),
            content: Text(
              _isEnglish
                  ? 'The key stored for ${_selectedProvider.displayName} '
                      'will be removed from this device.'
                  : 'この端末に保存した${_selectedProvider.displayName}の'
                      'APIキーを削除します。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_isEnglish ? 'Cancel' : 'キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(_isEnglish ? 'Delete' : '削除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await _configurationService.deleteApiKey(_selectedProvider);
      if (!mounted) return;
      setState(() {
        _hasStoredKey = false;
        _apiKeyController.clear();
      });
      _showMessage(_isEnglish ? 'API key deleted.' : 'APIキーを削除しました。');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is AiProviderException
        ? error.message
        : (_isEnglish
            ? 'Could not update AI settings. Check developer mode and the API key, then try again.'
            : 'AI設定を更新できませんでした。開発者モードとAPIキーを確認し、再試行してください。');
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEnglish ? 'AI Provider' : 'AIプロバイダー'),
      ),
      body: !_developerModeEnabled && !_isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _isEnglish
                      ? 'Developer mode is off. Unlock and enable it in About to use your own API key.'
                      : '開発者モードがオフです。自分のAPIキーを使うには「アプリについて」で開発者モードを解放してオンにしてください。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      _isEnglish
                          ? 'Gemini is ready to use by default. You can also use your own OpenAI, Anthropic, or Gemini API key.'
                          : '標準のGeminiはAPIキーの入力なしで利用できます。OpenAI・Anthropic・Geminiはご自身のAPIキーでも利用できます。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    if (!_usesFirebase) _buildSecurityNotice(context),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label:
                              Text(_isEnglish ? 'Standard Gemini' : '標準Gemini'),
                          selected: _usesManagedGemini,
                          onSelected: _isSaving || _isLoading
                              ? null
                              : (_) {
                                  setState(() {
                                    _usesManagedGemini = true;
                                    _selectedProvider = AiProvider.gemini;
                                    _modelController.text =
                                        AiProvider.gemini.defaultModel;
                                    _apiKeyController.clear();
                                    _hasStoredKey = false;
                                  });
                                },
                        ),
                        ChoiceChip(
                          label: Text(_isEnglish ? 'My API key' : '自分のAPIキー'),
                          selected: !_usesManagedGemini,
                          onSelected: _isSaving || _isLoading
                              ? null
                              : (_) async {
                                  setState(() => _usesManagedGemini = false);
                                  await _loadProvider(_selectedProvider);
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      if (_usesManagedGemini)
                        Text(_isEnglish
                            ? 'Use the standard Gemini service. No API key setup is needed.'
                            : '標準のGeminiを使用します。APIキーの設定は不要です。'),
                      if (!_usesManagedGemini) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final provider in AiProvider.values)
                              ChoiceChip(
                                label: Text(provider.displayName),
                                selected: _selectedProvider == provider,
                                onSelected: _isSaving || _isLoading
                                    ? null
                                    : (_) => _loadProvider(provider),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _modelController,
                          enabled: !_isSaving,
                          decoration: InputDecoration(
                            labelText: _isEnglish ? 'Model' : 'モデル',
                            helperText: _isEnglish
                                ? 'Default: ${_selectedProvider.defaultModel}'
                                : '既定値: ${_selectedProvider.defaultModel}',
                            suffixIcon: IconButton(
                              tooltip:
                                  _isEnglish ? 'Restore default' : '既定値に戻す',
                              onPressed: _isSaving
                                  ? null
                                  : () => _modelController.text =
                                      _selectedProvider.defaultModel,
                              icon: const Icon(Icons.restart_alt),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _apiKeyController,
                          enabled: !_isSaving,
                          obscureText: _obscureApiKey,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText:
                                '${_selectedProvider.displayName} API key',
                            hintText: _hasStoredKey
                                ? (_isEnglish
                                    ? 'Saved — leave blank to keep it'
                                    : '設定済み（変更しない場合は空欄）')
                                : (_isEnglish ? 'Enter API key' : 'APIキーを入力'),
                            prefixIcon: Icon(
                              _hasStoredKey ? Icons.key : Icons.key_outlined,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _isEnglish ? 'Show or hide' : '表示／非表示',
                              onPressed: () => setState(
                                () => _obscureApiKey = !_obscureApiKey,
                              ),
                              icon: Icon(
                                _obscureApiKey
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _hasStoredKey
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                              size: 18,
                              color: _hasStoredKey
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _hasStoredKey
                                    ? (_isEnglish
                                        ? 'A key is stored on this device.'
                                        : 'この端末にAPIキーが保存されています。')
                                    : (_isEnglish
                                        ? 'No key is stored for this provider.'
                                        : 'このプロバイダーのキーは未設定です。'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            if (_hasStoredKey)
                              TextButton(
                                onPressed: _isSaving ? null : _deleteApiKey,
                                child: Text(_isEnglish ? 'Delete' : '削除'),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : () => _save(),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_isEnglish ? 'Save and use' : '保存して使用'),
                      ),
                      const SizedBox(height: 12),
                      if (!_usesManagedGemini)
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _testConnection,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cable_outlined),
                          label: Text(_isEnglish ? 'Test connection' : '接続テスト'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSecurityNotice(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = kIsWeb
        ? (_isEnglish
            ? 'Web warning: the key is kept only in this tab\'s memory and '
                'is erased on reload, but code running on this site can use '
                'it while open. Use trusted HTTPS and a restricted key.'
            : 'Web版の注意: キーはこのタブのメモリ内だけに保持し、再読み込みで'
                '消去します。ただし表示中はサイト上のコードから利用できるため、'
                '信頼できるHTTPS環境と制限付きキーを使用してください。')
        : (_isEnglish
            ? 'The API key is kept in this device\'s secure storage and is '
                'excluded from app backups, cloud sync, and XML export.'
            : 'APIキーはこの端末のセキュアストレージに保存し、アプリ内バックアップ、'
                'クラウド同期、XMLエクスポートには含めません。');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            kIsWeb ? Icons.warning_amber_rounded : Icons.security_outlined,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
