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
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureApiKey = true;
  int _loadGeneration = 0;

  bool get _isEnglish => widget.isEnglish;

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
      _apiKeyController.clear();
    });

    try {
      final results = await Future.wait<Object>([
        _configurationService.getModel(provider),
        _configurationService.hasApiKey(provider),
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
    if (!_hasStoredKey && enteredApiKey.isEmpty) {
      _showMessage(_isEnglish ? 'Enter an API key.' : 'APIキーを入力してください。');
      return false;
    }

    setState(() => _isSaving = true);
    try {
      if (enteredApiKey.isNotEmpty) {
        await _configurationService.saveConfiguration(
          provider: _selectedProvider,
          model: model,
          apiKey: enteredApiKey,
        );
      } else {
        await _configurationService.setModel(_selectedProvider, model);
        await _configurationService.setSelectedProvider(_selectedProvider);
      }
      if (!mounted) return false;
      setState(() {
        _hasStoredKey = true;
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
    if (model.isEmpty) {
      _showMessage(_isEnglish ? 'Enter a model name.' : 'モデル名を入力してください。');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final enteredApiKey = _apiKeyController.text.trim();
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
        : (_isEnglish ? 'Could not update AI settings.' : 'AI設定を更新できませんでした。');
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _isEnglish
                ? 'Use your own API key for AI setup advice and image OCR.'
                : 'ご自身のAPIキーで、AIセッティング相談と画像OCRを利用できます。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _buildSecurityNotice(context),
          const SizedBox(height: 20),
          SegmentedButton<AiProvider>(
            segments: [
              for (final provider in AiProvider.values)
                ButtonSegment<AiProvider>(
                  value: provider,
                  label: Text(provider.displayName),
                ),
            ],
            selected: {_selectedProvider},
            onSelectionChanged: _isSaving
                ? null
                : (selection) => _loadProvider(selection.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            TextField(
              controller: _modelController,
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: _isEnglish ? 'Model' : 'モデル',
                helperText: _isEnglish
                    ? 'Default: ${_selectedProvider.defaultModel}'
                    : '既定値: ${_selectedProvider.defaultModel}',
                suffixIcon: IconButton(
                  tooltip: _isEnglish ? 'Restore default' : '既定値に戻す',
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
                labelText: '${_selectedProvider.displayName} API key',
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
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _hasStoredKey ? Icons.check_circle : Icons.info_outline,
                  size: 18,
                  color: _hasStoredKey
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : () => _save(),
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEnglish ? 'Save and use' : '保存して使用'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _testConnection,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cable_outlined),
              label: Text(_isEnglish ? 'Test connection' : '接続テスト'),
            ),
          ],
        ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
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
