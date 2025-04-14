import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/saved_setting.dart';
import 'car_selection_page.dart';
import 'car_setting_page.dart';
import 'history_page.dart';
import 'tools_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const _HomeTab(),
    const HistoryPage(),
    const ToolsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    final List<String> titles = [
      isEnglish ? 'RC Car Settings' : 'RCカーセッティング',
      isEnglish ? 'Setting History' : 'セッティング履歴',
      isEnglish ? 'Tools' : 'ツール',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings page
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: isEnglish ? 'Home' : 'ホーム',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: isEnglish ? 'History' : '履歴',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.build),
            label: isEnglish ? 'Tools' : 'ツール',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CarSelectionPage(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final savedSettings = settingsProvider.savedSettings;
        final isEnglish = settingsProvider.isEnglish;

        if (savedSettings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_car,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  isEnglish ? 'No settings saved yet' : '保存された設定はありません',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  isEnglish
                      ? 'Tap the + button to create a new setting'
                      : '+ ボタンをタップして新しい設定を作成してください',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: savedSettings.length,
          itemBuilder: (context, index) {
            final setting = savedSettings[index];
            return SettingCard(setting: setting);
          },
        );
      },
    );
  }
}

class SettingCard extends StatelessWidget {
  final SavedSetting setting;

  const SettingCard({super.key, required this.setting});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CarSettingPage(
                originalCar: setting.car,
                savedSettings: setting.settings,
                settingName: setting.name,
                savedSettingId: setting.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      setting.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        // 編集画面へ遷移
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CarSettingPage(
                              originalCar: setting.car,
                              savedSettings: setting.settings,
                              settingName: setting.name,
                              savedSettingId: setting.id,
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        // 削除確認ダイアログを表示
                        _showDeleteConfirmationDialog(context, setting);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 20),
                            const SizedBox(width: 8),
                            Text(isEnglish ? 'Edit' : '編集'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete,
                                size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              isEnglish ? 'Delete' : '削除',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                setting.car.name,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(setting.createdAt, isEnglish),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date, bool isEnglish) {
    if (isEnglish) {
      // English format: Jan 1, 2023 12:34 PM
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
      final String month = months[date.month - 1];
      final String day = date.day.toString();
      final String year = date.year.toString();
      final String hour = (date.hour > 12)
          ? (date.hour - 12).toString()
          : (date.hour == 0 ? '12' : date.hour.toString());
      final String minute = date.minute.toString().padLeft(2, '0');
      final String period = date.hour >= 12 ? 'PM' : 'AM';
      return '$month $day, $year $hour:$minute $period';
    } else {
      // Japanese format: 2023年1月1日 12:34
      return '${date.year}年${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, SavedSetting setting) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEnglish ? 'Delete Setting' : '設定の削除'),
          content: Text(isEnglish
              ? 'Are you sure you want to delete "${setting.name}"? This action cannot be undone.'
              : '「${setting.name}」を削除してもよろしいですか？この操作は元に戻せません。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
            ),
            TextButton(
              onPressed: () {
                settingsProvider.deleteSetting(setting.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEnglish ? 'Setting deleted' : '設定を削除しました'),
                  ),
                );
              },
              child: Text(
                isEnglish ? 'Delete' : '削除',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
