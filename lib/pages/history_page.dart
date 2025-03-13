import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/saved_setting.dart';
import 'car_setting_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? 'Setting History' : 'セッティング履歴'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          final savedSettings = settingsProvider.savedSettings;
          final isEnglish = settingsProvider.isEnglish;

          if (savedSettings.isEmpty) {
            return Center(
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
                    isEnglish ? 'No history available' : '履歴がありません',
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

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
            Text(isEnglish
                ? 'Car: ${setting.car.name}'
                : '車名: ${setting.car.name}'),
            Text(isEnglish
                ? 'Created: ${_formatDate(setting.createdAt, isEnglish)}'
                : '作成日: ${_formatDate(setting.createdAt, isEnglish)}'),
          ],
        ),
        leading: const CircleAvatar(
          child: Icon(Icons.sports_motorsports),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Navigate to setting detail page
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

  String _formatDate(DateTime dateTime, bool isEnglish) {
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
      final String month = months[dateTime.month - 1];
      final String day = dateTime.day.toString();
      final String year = dateTime.year.toString();
      final String hour = (dateTime.hour > 12)
          ? (dateTime.hour - 12).toString()
          : (dateTime.hour == 0 ? '12' : dateTime.hour.toString());
      final String minute = dateTime.minute.toString().padLeft(2, '0');
      final String period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$month $day, $year $hour:$minute $period';
    } else {
      // Japanese format: 2023年1月1日 12:34
      return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
