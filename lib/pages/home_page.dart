import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/saved_setting.dart';
import 'car_selection_page.dart';
import 'car_setting_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RCカーセッティング'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // 設定ページへ遷移
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          final savedSettings = settingsProvider.savedSettings;
          
          if (savedSettings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.sports_motorsports_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '保存されたセッティングがありません',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('新しいセッティングを作成'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CarSelectionPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: savedSettings.length,
            itemBuilder: (context, index) {
              final setting = savedSettings[index];
              return _buildSettingCard(context, setting);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CarSelectionPage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSettingCard(BuildContext context, SavedSetting setting) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          // 設定詳細画面へ遷移
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
          padding: const EdgeInsets.all(16.0),
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
                    onSelected: (value) async {
                      if (value == 'delete') {
                        _showDeleteConfirmationDialog(context, setting);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('削除'),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '車名: ${setting.car.name}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                '作成日: ${_formatDate(setting.createdAt)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, SavedSetting setting) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('設定の削除'),
          content: Text('「${setting.name}」を削除してもよろしいですか？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<SettingsProvider>(context, listen: false)
                    .deleteSetting(setting.id);
                Navigator.pop(context);
              },
              child: const Text('削除'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 