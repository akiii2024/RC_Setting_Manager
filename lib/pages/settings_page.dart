import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _autoSave = true;
  String _selectedLanguage = '日本語';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('ダークモード'),
            subtitle: const Text('アプリの外観を暗くします'),
            value: _darkMode,
            onChanged: (bool value) {
              setState(() {
                _darkMode = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('自動保存'),
            subtitle: const Text('セッティングの変更を自動的に保存します'),
            value: _autoSave,
            onChanged: (bool value) {
              setState(() {
                _autoSave = value;
              });
            },
          ),
          ListTile(
            title: const Text('言語'),
            subtitle: Text(_selectedLanguage),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _showLanguageDialog,
          ),
          ListTile(
            title: const Text('データのバックアップ'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // バックアップ機能の実装
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('バックアップ機能は準備中です')),
              );
            },
          ),
          ListTile(
            title: const Text('データの復元'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // 復元機能の実装
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('復元機能は準備中です')),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('アプリについて'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('言語を選択'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                setState(() {
                  _selectedLanguage = '日本語';
                });
                Navigator.pop(context);
              },
              child: const Text('日本語'),
            ),
            SimpleDialogOption(
              onPressed: () {
                setState(() {
                  _selectedLanguage = 'English';
                });
                Navigator.pop(context);
              },
              child: const Text('English'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'ラジコンセッティング',
      applicationVersion: '1.0.0',
      applicationIcon: const FlutterLogo(size: 48),
      children: [
        const Text('ラジコンのセッティングを管理するためのアプリです。'),
        const SizedBox(height: 16),
        const Text('© 2023 ラジコンセッティングアプリ'),
      ],
    );
  }
}
