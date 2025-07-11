import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/xml_service.dart';
import '../services/file_service.dart';

class SimpleImportPage extends StatefulWidget {
  const SimpleImportPage({super.key});

  @override
  State<SimpleImportPage> createState() => _SimpleImportPageState();
}

class _SimpleImportPageState extends State<SimpleImportPage> {
  bool _includeCars = true;
  bool _includeSavedSettings = true;
  bool _includeVisibilitySettings = true;
  bool _includeLanguageSettings = false;
  bool _isLoading = false;
  List<dynamic> _xmlFiles = [];
  dynamic _selectedFile;
  ImportResult? _previewData;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadXmlFiles();
    }
  }

  Future<void> _loadXmlFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await FileService.getXmlFiles();
      setState(() {
        _xmlFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectFile(File file) async {
    setState(() {
      _isLoading = true;
      _selectedFile = file;
    });

    try {
      final xmlContent = await FileService.readFileContent(file);
      final previewResult = await XmlService.importFromXml(xmlContent);

      setState(() {
        _previewData = previewResult;
        _isLoading = false;
      });

      _adjustCheckboxesBasedOnFileContent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<SettingsProvider>(context, listen: false).isEnglish
                  ? 'Failed to read file: $e'
                  : 'ファイルの読み込みに失敗しました: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
          _selectedFile = null;
          _previewData = null;
        });
      }
    }
  }

  void _adjustCheckboxesBasedOnFileContent() {
    if (_previewData == null) return;

    final exportedTypes = _previewData!.metadata.exportedTypes;

    setState(() {
      _includeCars =
          exportedTypes.contains('cars') && _previewData!.cars.isNotEmpty;
      _includeSavedSettings = exportedTypes.contains('savedSettings') &&
          _previewData!.savedSettings.isNotEmpty;
      _includeVisibilitySettings =
          exportedTypes.contains('visibilitySettings') &&
              _previewData!.visibilitySettings.isNotEmpty;
      _includeLanguageSettings = exportedTypes.contains('languageSettings');
    });
  }

  Future<void> _importSelectedData() async {
    if (_previewData == null) return;

    if (!_includeCars &&
        !_includeSavedSettings &&
        !_includeVisibilitySettings &&
        !_includeLanguageSettings) {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settingsProvider.isEnglish
                ? 'Please select at least one data type to import.'
                : '少なくとも1つのデータタイプを選択してください。',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);

      await settingsProvider.replacePartialData(
        cars: _includeCars ? _previewData!.cars : null,
        savedSettings:
            _includeSavedSettings ? _previewData!.savedSettings : null,
        visibilitySettings: _includeVisibilitySettings
            ? _previewData!.visibilitySettings
            : null,
        isEnglish: _includeLanguageSettings
            ? (_previewData!.metadata.language == 'en')
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settingsProvider.isEnglish
                  ? 'Selected data imported successfully!'
                  : '選択されたデータのインポートが完了しました！',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<SettingsProvider>(context, listen: false).isEnglish
                  ? 'Import failed: $e'
                  : 'インポートに失敗しました: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(isEnglish ? 'Confirm Import' : 'インポートの確認'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEnglish
                        ? 'The following data will be replaced:'
                        : '以下のデータが置き換えられます:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_includeCars)
                    Text(
                        '• ${isEnglish ? "Cars" : "車種"} (${_previewData!.cars.length} ${isEnglish ? "items" : "件"})'),
                  if (_includeSavedSettings)
                    Text(
                        '• ${isEnglish ? "Saved Settings" : "保存された設定"} (${_previewData!.savedSettings.length} ${isEnglish ? "items" : "件"})'),
                  if (_includeVisibilitySettings)
                    Text(
                        '• ${isEnglish ? "Visibility Settings" : "表示設定"} (${_previewData!.visibilitySettings.length} ${isEnglish ? "cars" : "台分"})'),
                  if (_includeLanguageSettings)
                    Text('• ${isEnglish ? "Language Settings" : "言語設定"}'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEnglish
                                ? 'This action cannot be undone!'
                                : 'この操作は元に戻せません！',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: Text(isEnglish ? 'Import' : 'インポート'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _deleteFile(File file) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(isEnglish ? 'Delete File' : 'ファイルを削除'),
              content: Text(
                isEnglish
                    ? 'Are you sure you want to delete this file?'
                    : 'このファイルを削除してもよろしいですか？',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text(isEnglish ? 'Delete' : '削除'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirmed) {
      try {
        await FileService.deleteFile(file);
        await _loadXmlFiles();
        if (_selectedFile == file) {
          setState(() {
            _selectedFile = null;
            _previewData = null;
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEnglish ? 'File deleted successfully' : 'ファイルを削除しました',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEnglish ? 'Failed to delete file: $e' : 'ファイルの削除に失敗しました: $e',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    // Web環境の場合は機能制限を表示
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEnglish ? 'Import Data' : 'データのインポート'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.web,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'ファイルインポート機能はWeb版では利用できません',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'この機能を使用するには、AndroidまたはiOSアプリをご利用ください。',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? 'Import from Saved Files' : '保存されたファイルからインポート'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadXmlFiles,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_xmlFiles.isEmpty && !_isLoading) ...[
              SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        isEnglish ? 'No XML files found' : 'XMLファイルが見つかりません',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isEnglish
                            ? 'Export some data first to create XML files.'
                            : 'まずデータをエクスポートしてXMLファイルを作成してください。',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_selectedFile == null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnglish ? 'Select XML File' : 'XMLファイルを選択',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isEnglish
                            ? 'Choose an XML file to preview and import.'
                            : 'プレビューとインポートするXMLファイルを選択してください。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      children: _xmlFiles.map((file) {
                        final fileName = file.path.split('/').last;
                        final stat = file.statSync();

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.description,
                                color: Colors.blue),
                            title: Text(fileName),
                            subtitle: Text(
                              '${isEnglish ? "Modified" : "更新日"}: ${stat.modified.toString().split('.')[0]}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteFile(file),
                                ),
                                const Icon(Icons.arrow_forward_ios),
                              ],
                            ),
                            onTap: () => _selectFile(file),
                          ),
                        );
                      }).toList(),
                    ),
            ] else ...[
              // ファイルが選択されている場合のプレビューとインポート画面
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.preview, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFile!.path.split('/').last,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedFile = null;
                                _previewData = null;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_previewData != null) ...[
                        const SizedBox(height: 8),
                        if (_previewData!.metadata.exportDate != null)
                          Text(
                              '${isEnglish ? "Export Date" : "エクスポート日"}: ${_previewData!.metadata.exportDate}'),
                        if (_previewData!.metadata.version != null)
                          Text(
                              '${isEnglish ? "Version" : "バージョン"}: ${_previewData!.metadata.version}'),
                        const SizedBox(height: 8),
                        Text(
                          isEnglish ? 'Available Data:' : '利用可能なデータ:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                            '• ${isEnglish ? "Cars" : "車種"}: ${_previewData!.cars.length} ${isEnglish ? "items" : "件"}'),
                        Text(
                            '• ${isEnglish ? "Saved Settings" : "保存された設定"}: ${_previewData!.savedSettings.length} ${isEnglish ? "items" : "件"}'),
                        Text(
                            '• ${isEnglish ? "Visibility Settings" : "表示設定"}: ${_previewData!.visibilitySettings.length} ${isEnglish ? "cars" : "台分"}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_previewData != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEnglish ? 'Select Data to Import' : 'インポートするデータを選択',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          title: Text(isEnglish ? 'Cars' : '車種'),
                          subtitle: Text(
                              '${_previewData!.cars.length} ${isEnglish ? "items available" : "件利用可能"}'),
                          value: _includeCars,
                          onChanged: _previewData!.cars.isNotEmpty
                              ? (value) {
                                  setState(() {
                                    _includeCars = value ?? false;
                                  });
                                }
                              : null,
                        ),
                        CheckboxListTile(
                          title: Text(isEnglish ? 'Saved Settings' : '保存された設定'),
                          subtitle: Text(
                              '${_previewData!.savedSettings.length} ${isEnglish ? "items available" : "件利用可能"}'),
                          value: _includeSavedSettings,
                          onChanged: _previewData!.savedSettings.isNotEmpty
                              ? (value) {
                                  setState(() {
                                    _includeSavedSettings = value ?? false;
                                  });
                                }
                              : null,
                        ),
                        CheckboxListTile(
                          title:
                              Text(isEnglish ? 'Visibility Settings' : '表示設定'),
                          subtitle: Text(
                              '${_previewData!.visibilitySettings.length} ${isEnglish ? "cars available" : "台分利用可能"}'),
                          value: _includeVisibilitySettings,
                          onChanged: _previewData!.visibilitySettings.isNotEmpty
                              ? (value) {
                                  setState(() {
                                    _includeVisibilitySettings = value ?? false;
                                  });
                                }
                              : null,
                        ),
                        CheckboxListTile(
                          title: Text(isEnglish ? 'Language Settings' : '言語設定'),
                          subtitle: Text(
                            _previewData!.metadata.language != null
                                ? '${isEnglish ? "Language" : "言語"}: ${_previewData!.metadata.language == "en" ? "English" : "日本語"}'
                                : (isEnglish ? 'No language data' : '言語データなし'),
                          ),
                          value: _includeLanguageSettings,
                          onChanged: _previewData!.metadata.language != null
                              ? (value) {
                                  setState(() {
                                    _includeLanguageSettings = value ?? false;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _importSelectedData,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload),
                  label: Text(
                      isEnglish ? 'Import Selected Data' : '選択されたデータをインポート'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
