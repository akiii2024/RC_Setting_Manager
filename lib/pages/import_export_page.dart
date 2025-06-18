import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/xml_service.dart';
import '../services/file_service.dart';
import 'partial_export_page.dart';
import 'simple_import_page.dart';

class ImportExportPage extends StatefulWidget {
  const ImportExportPage({super.key});

  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  bool _isLoading = false;

  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      final xmlContent = await XmlService.exportToXml(
        savedSettings: settingsProvider.savedSettings,
        cars: settingsProvider.cars,
        visibilitySettings: settingsProvider.visibilitySettings,
        isEnglish: settingsProvider.isEnglish,
      );

      final fileName = 'rc_car_settings_full_${DateTime.now().millisecondsSinceEpoch}.xml';
      await FileService.saveAndShareXml(xmlContent, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settingsProvider.isEnglish
                  ? 'Data exported successfully!'
                  : 'データのエクスポートが完了しました！',
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

  Future<void> _importData() async {
    // SimpleImportPageに移動
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SimpleImportPage(),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? 'Import / Export' : 'インポート / エクスポート'),
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
                    Row(
                      children: [
                        const Icon(Icons.upload_file, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          isEnglish ? 'Export Data' : 'データエクスポート',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEnglish
                          ? 'Export all your settings, cars, and preferences to an XML file.'
                          : 'すべての設定、車種、環境設定をXMLファイルにエクスポートします。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _exportData,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.download),
                            label: Text(isEnglish ? 'Export All' : '全てエクスポート'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const PartialExportPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.tune),
                            label: Text(isEnglish ? 'Partial Export' : '部分エクスポート'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download_for_offline, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          isEnglish ? 'Import Data' : 'データインポート',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEnglish
                          ? 'Import settings from an XML file. This will replace all current data.'
                          : 'XMLファイルから設定をインポートします。現在のデータはすべて置き換えられます。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isEnglish
                                  ? 'Warning: This will overwrite all existing data!'
                                  : '警告: 既存のデータがすべて上書きされます！',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _importData,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.upload),
                            label: Text(isEnglish ? 'Import All' : '全てインポート'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const SimpleImportPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.tune),
                            label: Text(isEnglish ? 'Partial Import' : '部分インポート'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                            ),
                          ),
                        ),
                      ],
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
                          isEnglish ? 'Information' : '情報',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEnglish
                          ? '• XML files contain all your settings, car data, and preferences\n'
                            '• Files can be shared between devices\n'
                            '• Full import/export replaces all current data\n'
                            '• Partial import/export allows selective data transfer\n'
                            '• Make sure to export current data before importing'
                          : '• XMLファイルにはすべての設定、車種データ、環境設定が含まれます\n'
                            '• ファイルはデバイス間で共有できます\n'
                            '• 全体インポート/エクスポートは現在のデータを完全に置き換えます\n'
                            '• 部分インポート/エクスポートは選択的なデータ転送が可能です\n'
                            '• インポート前に現在のデータをエクスポートすることをお勧めします',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}