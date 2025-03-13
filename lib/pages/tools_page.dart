import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/saved_setting.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ツール'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const _SectionHeader(title: 'データ管理'),
            _ToolCard(
              title: 'セッティングデータのバックアップ',
              description: 'すべてのセッティングデータをエクスポートします',
              icon: Icons.backup,
              onTap: () => _exportSettings(context),
            ),
            _ToolCard(
              title: 'セッティングデータのインポート',
              description: '以前にエクスポートしたデータを復元します',
              icon: Icons.restore,
              onTap: () => _showComingSoonDialog(context),
            ),
            const SizedBox(height: 16),
            const _SectionHeader(title: '計算ツール'),
            _ToolCard(
              title: 'ギヤレシオ計算',
              description: 'スパーギヤとピニオンギヤからギヤレシオを計算',
              icon: Icons.calculate,
              onTap: () => _showGearRatioCalculator(context),
            ),
            _ToolCard(
              title: 'ロール角度計算',
              description: 'サスペンションの角度を計算',
              icon: Icons.straighten,
              onTap: () => _showComingSoonDialog(context),
            ),
            const SizedBox(height: 16),
            const _SectionHeader(title: 'その他'),
            _ToolCard(
              title: 'セッティングデータを共有',
              description: '他のユーザーとセッティング情報を共有',
              icon: Icons.share,
              onTap: () => _shareSettings(context),
            ),
            _ToolCard(
              title: '統計情報',
              description: 'あなたのセッティング傾向を確認',
              icon: Icons.bar_chart,
              onTap: () => _showComingSoonDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _exportSettings(BuildContext context) {
    // バックアップ機能は未実装
    _showComingSoonDialog(context);
  }

  void _shareSettings(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final savedSettings = settingsProvider.savedSettings;

    if (savedSettings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('共有可能なセッティングがありません')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('共有するセッティングを選択'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: savedSettings.length,
              itemBuilder: (context, index) {
                final setting = savedSettings[index];
                return ListTile(
                  title: Text(setting.name),
                  subtitle: Text(setting.car.name),
                  onTap: () {
                    Navigator.pop(context);
                    _shareSetting(context, setting);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
          ],
        );
      },
    );
  }

  void _shareSetting(BuildContext context, SavedSetting setting) {
    final text = '''
RCカーセッティング共有

名前: ${setting.name}
車種: ${setting.car.name}
作成日: ${_formatDate(setting.createdAt)}

--- セッティング詳細 ---
${_formatSettingsForShare(setting.settings)}
''';

    Share.share(text);
  }

  String _formatSettingsForShare(Map<String, dynamic> settings) {
    final buffer = StringBuffer();
    settings.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    return buffer.toString();
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showGearRatioCalculator(BuildContext context) {
    int spur = 72; // デフォルト値
    int pinion = 24; // デフォルト値

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final double ratio = spur / pinion;

            return AlertDialog(
              title: const Text('ギヤレシオ計算'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('スパーギヤ: '),
                      Expanded(
                        child: Slider(
                          min: 60,
                          max: 120,
                          divisions: 60,
                          value: spur.toDouble(),
                          label: spur.toString(),
                          onChanged: (value) {
                            setState(() {
                              spur = value.round();
                            });
                          },
                        ),
                      ),
                      Text('$spur T'),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('ピニオンギヤ: '),
                      Expanded(
                        child: Slider(
                          min: 10,
                          max: 40,
                          divisions: 30,
                          value: pinion.toDouble(),
                          label: pinion.toString(),
                          onChanged: (value) {
                            setState(() {
                              pinion = value.round();
                            });
                          },
                        ),
                      ),
                      Text('$pinion T'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('ギヤレシオ: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          ratio.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('開発中'),
          content: const Text('この機能は現在開発中です。今後のアップデートをお楽しみに！'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ToolCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
                radius: 24,
                child: Icon(icon, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
