import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/saved_setting.dart';
import 'car_setting_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('セッティング履歴'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          final savedSettings = settingsProvider.savedSettings;

          if (savedSettings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '履歴がありません',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: savedSettings.length,
            itemBuilder: (context, index) {
              final setting = savedSettings[index];
              return _buildHistoryItem(context, setting);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, SavedSetting setting) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          setting.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('車名: ${setting.car.name}'),
            Text('作成日: ${_formatDate(setting.createdAt)}'),
          ],
        ),
        leading: const CircleAvatar(
          child: Icon(Icons.sports_motorsports),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
