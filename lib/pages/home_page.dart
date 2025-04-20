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
            tooltip: isEnglish ? 'Settings' : '設定',
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
        elevation: 8,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: isEnglish ? 'Home' : 'ホーム',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_rounded),
            label: isEnglish ? 'History' : '履歴',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.build_rounded),
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
              tooltip: isEnglish ? 'Add new setting' : '新しい設定を追加',
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
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Icon(
                      Icons.directions_car_rounded,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isEnglish ? 'No settings saved yet' : '保存された設定はありません',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isEnglish
                        ? 'Create your first RC car setting by tapping the + button below'
                        : '下の + ボタンをタップして最初のRCカー設定を作成しましょう',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CarSelectionPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: Text(isEnglish ? 'Create Setting' : '設定を作成'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
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
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
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
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カラーバー
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
            Padding(
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
                            _showDeleteConfirmationDialog(context, setting);
                          }
                        },
                        icon: Icon(
                          Icons.more_vert,
                          color: theme.colorScheme.primary,
                        ),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(isEnglish ? 'Edit' : '編集'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_rounded,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 12),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car_rounded,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        setting.car.name,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(setting.createdAt, isEnglish),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
