import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/xml_service.dart';
import '../services/file_service.dart';

class PartialExportPage extends StatefulWidget {
  const PartialExportPage({super.key});

  @override
  State<PartialExportPage> createState() => _PartialExportPageState();
}

class _PartialExportPageState extends State<PartialExportPage> {
  bool _includeCars = true;
  bool _includeSavedSettings = true;
  bool _includeVisibilitySettings = true;
  bool _includeLanguageSettings = true;
  bool _isLoading = false;

  Future<void> _exportSelectedData() async {
    if (!_includeCars && !_includeSavedSettings && !_includeVisibilitySettings && !_includeLanguageSettings) {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settingsProvider.isEnglish
                ? 'Please select at least one data type to export.'
                : '少なくとも1つのデータタイプを選択してください。',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      final options = ExportImportOptions(
        includeCars: _includeCars,
        includeSavedSettings: _includeSavedSettings,
        includeVisibilitySettings: _includeVisibilitySettings,
        includeLanguageSettings: _includeLanguageSettings,
      );

      final xmlContent = await XmlService.exportToXml(
        savedSettings: settingsProvider.savedSettings,
        cars: settingsProvider.cars,
        visibilitySettings: settingsProvider.visibilitySettings,
        isEnglish: settingsProvider.isEnglish,
        options: options,
      );

      final fileName = 'rc_car_settings_partial_${DateTime.now().millisecondsSinceEpoch}.xml';
      await FileService.saveAndShareXml(xmlContent, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settingsProvider.isEnglish
                  ? 'Selected data exported successfully!'
                  : '選択されたデータのエクスポートが完了しました！',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<SettingsProvider>(context, listen: false).isEnglish
                  ? 'Export failed: $e'
                  : 'エクスポートに失敗しました: $e',
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

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? 'Select Data to Export' : 'エクスポートするデータを選択'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEnglish ? 'Select Data Types' : 'データタイプを選択',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: Text(isEnglish ? 'Cars' : '車種'),
                      subtitle: Text(
                        isEnglish 
                            ? '${settingsProvider.cars.length} cars'
                            : '${settingsProvider.cars.length}台',
                      ),
                      value: _includeCars,
                      onChanged: (value) {
                        setState(() {
                          _includeCars = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: Text(isEnglish ? 'Saved Settings' : '保存された設定'),
                      subtitle: Text(
                        isEnglish 
                            ? '${settingsProvider.savedSettings.length} settings'
                            : '${settingsProvider.savedSettings.length}件',
                      ),
                      value: _includeSavedSettings,
                      onChanged: (value) {
                        setState(() {
                          _includeSavedSettings = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: Text(isEnglish ? 'Visibility Settings' : '表示設定'),
                      subtitle: Text(
                        isEnglish 
                            ? '${settingsProvider.visibilitySettings.length} cars configured'
                            : '${settingsProvider.visibilitySettings.length}台分設定済み',
                      ),
                      value: _includeVisibilitySettings,
                      onChanged: (value) {
                        setState(() {
                          _includeVisibilitySettings = value ?? false;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: Text(isEnglish ? 'Language Settings' : '言語設定'),
                      subtitle: Text(
                        isEnglish ? 'Current: English' : '現在: 日本語',
                      ),
                      value: _includeLanguageSettings,
                      onChanged: (value) {
                        setState(() {
                          _includeLanguageSettings = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          isEnglish ? 'Export Summary' : 'エクスポート概要',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getExportSummary(isEnglish),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _exportSelectedData,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(isEnglish ? 'Export Selected Data' : '選択されたデータをエクスポート'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getExportSummary(bool isEnglish) {
    List<String> selectedItems = [];
    
    if (_includeCars) {
      selectedItems.add(isEnglish ? 'Cars' : '車種');
    }
    if (_includeSavedSettings) {
      selectedItems.add(isEnglish ? 'Saved Settings' : '保存された設定');
    }
    if (_includeVisibilitySettings) {
      selectedItems.add(isEnglish ? 'Visibility Settings' : '表示設定');
    }
    if (_includeLanguageSettings) {
      selectedItems.add(isEnglish ? 'Language Settings' : '言語設定');
    }

    if (selectedItems.isEmpty) {
      return isEnglish 
          ? 'No data types selected for export.'
          : 'エクスポートするデータタイプが選択されていません。';
    }

    final itemsText = selectedItems.join(', ');
    return isEnglish 
        ? 'The following data will be exported: $itemsText'
        : '以下のデータがエクスポートされます: $itemsText';
  }
}