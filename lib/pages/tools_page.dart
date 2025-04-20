import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/saved_setting.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _SectionHeader(title: isEnglish ? 'Data Management' : 'データ管理'),
            _ToolCard(
              title: isEnglish ? 'Backup Settings' : 'セッティングデータのバックアップ',
              description: isEnglish
                  ? 'Export all your setting data'
                  : 'すべてのセッティングデータをエクスポートします',
              icon: Icons.backup_rounded,
              color: Colors.blue,
              onTap: () => _exportSettings(context),
            ),
            _ToolCard(
              title: isEnglish ? 'Import Settings' : 'セッティングデータのインポート',
              description: isEnglish
                  ? 'Restore previously exported data'
                  : '以前にエクスポートしたデータを復元します',
              icon: Icons.restore_rounded,
              color: Colors.indigo,
              onTap: () => _showComingSoonDialog(context),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: isEnglish ? 'Calculation Tools' : '計算ツール'),
            _ToolCard(
              title: isEnglish ? 'Gear Ratio Calculator' : 'ギヤレシオ計算',
              description: isEnglish
                  ? 'Calculate gear ratio from spur and pinion gears'
                  : 'スパーギヤとピニオンギヤからギヤレシオを計算',
              icon: Icons.calculate_rounded,
              color: Colors.orange,
              onTap: () => _showGearRatioCalculator(context),
            ),
            _ToolCard(
              title: isEnglish ? 'Roll Angle Calculator' : 'ロール角度計算',
              description:
                  isEnglish ? 'Calculate suspension angles' : 'サスペンションの角度を計算',
              icon: Icons.straighten_rounded,
              color: Colors.deepOrange,
              onTap: () => _showComingSoonDialog(context),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: isEnglish ? 'Other' : 'その他'),
            _ToolCard(
              title: isEnglish ? 'Share Settings' : 'セッティングデータを共有',
              description: isEnglish
                  ? 'Share setting information with other users'
                  : '他のユーザーとセッティング情報を共有',
              icon: Icons.share_rounded,
              color: Colors.teal,
              onTap: () => _shareSettings(context),
            ),
            _ToolCard(
              title: isEnglish ? 'Statistics' : '統計情報',
              description:
                  isEnglish ? 'View your setting trends' : 'あなたのセッティング傾向を確認',
              icon: Icons.bar_chart_rounded,
              color: Colors.purple,
              onTap: () => _showComingSoonDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _exportSettings(BuildContext context) {
    // Backup feature is not implemented yet
    _showComingSoonDialog(context);
  }

  void _shareSettings(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final savedSettings = settingsProvider.savedSettings;
    final isEnglish = settingsProvider.isEnglish;

    if (savedSettings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'No settings available to share'
              : '共有可能なセッティングがありません'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isEnglish ? 'Select a setting to share' : '共有するセッティングを選択',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: savedSettings.length,
              itemBuilder: (context, index) {
                final setting = savedSettings[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      setting.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(setting.car.name),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      child: Icon(
                        Icons.directions_car_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _shareSettingData(context, setting);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
            ),
          ],
        );
      },
    );
  }

  void _shareSettingData(BuildContext context, SavedSetting setting) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    // Create a formatted string of the setting details
    final buffer = StringBuffer();
    buffer.writeln(isEnglish
        ? 'RC Car Setting: ${setting.name}'
        : 'RCカーセッティング: ${setting.name}');
    buffer.writeln(
        isEnglish ? 'Car: ${setting.car.name}' : '車種: ${setting.car.name}');
    buffer.writeln(isEnglish
        ? 'Created: ${_formatDate(setting.createdAt, isEnglish)}'
        : '作成日: ${_formatDate(setting.createdAt, isEnglish)}');
    buffer.writeln('-------------------');

    // Add setting details
    setting.settings.forEach((key, value) {
      buffer.writeln('$key: $value');
    });

    Share.share(buffer.toString());
  }

  String _formatDate(DateTime dateTime, bool isEnglish) {
    if (isEnglish) {
      final List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final String month = months[dateTime.month - 1];
      final String day = dateTime.day.toString();
      final String year = dateTime.year.toString();
      return '$month $day, $year';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    }
  }

  void _showGearRatioCalculator(BuildContext context) {
    final spurController = TextEditingController();
    final pinionController = TextEditingController();
    double gearRatio = 0.0;
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(isEnglish ? 'Gear Ratio Calculator' : 'ギヤレシオ計算機'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: spurController,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Spur Gear (teeth)' : 'スパーギヤ (歯数)',
                      prefixIcon: const Icon(Icons.settings_rounded),
                      filled: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinionController,
                    decoration: InputDecoration(
                      labelText:
                          isEnglish ? 'Pinion Gear (teeth)' : 'ピニオンギヤ (歯数)',
                      prefixIcon: const Icon(Icons.settings_rounded),
                      filled: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final spur = int.tryParse(spurController.text);
                        final pinion = int.tryParse(pinionController.text);

                        if (spur != null && pinion != null && pinion > 0) {
                          setState(() {
                            gearRatio = spur / pinion;
                          });
                        }
                      },
                      icon: const Icon(Icons.calculate_rounded),
                      label: Text(isEnglish ? 'Calculate' : '計算'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (gearRatio > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.speed_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${isEnglish ? 'Gear Ratio' : 'ギヤレシオ'}: ${gearRatio.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(isEnglish ? 'Close' : '閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(isEnglish ? 'Coming Soon' : '準備中'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              isEnglish
                  ? 'This feature is under development and will be available soon.'
                  : 'この機能は開発中です。もうしばらくお待ちください。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(isEnglish ? 'OK' : '了解'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 16),
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
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
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
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
