import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../models/car.dart';
import '../models/visibility_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoSave = true;
  String _selectedLanguage = '日本語';
  List<Car> _cars = [];
  Car? _selectedCar;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 車両リストを取得
    final settingsProvider = Provider.of<SettingsProvider>(context);
    _loadCars(settingsProvider);
  }

  void _loadCars(SettingsProvider settingsProvider) {
    // 保存済み設定から車両リストを取得
    final savedSettings = settingsProvider.savedSettings;
    final Map<String, Car> uniqueCars = {};

    for (var setting in savedSettings) {
      uniqueCars[setting.car.id] = setting.car;
    }

    setState(() {
      _cars = uniqueCars.values.toList();
      // 車両が存在する場合は最初の車両を選択
      if (_cars.isNotEmpty && _selectedCar == null) {
        _selectedCar = _cars.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('ダークモード'),
            subtitle: const Text('アプリの外観を暗くします'),
            value: themeProvider.isDarkMode,
            onChanged: (bool value) {
              themeProvider.toggleTheme();
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('表示設定'),
            subtitle: const Text('各マシンごとの表示項目を設定します'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              _showVisibilitySettingsDialog(context);
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

  void _showVisibilitySettingsDialog(BuildContext context) {
    if (_cars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('表示設定を行うには、まず車両を登録してください')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('表示設定'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 車両選択ドロップダウン
                    DropdownButtonFormField<Car>(
                      decoration: const InputDecoration(
                        labelText: '車両を選択',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedCar,
                      items: _cars.map((car) {
                        return DropdownMenuItem<Car>(
                          value: car,
                          child: Text(car.name),
                        );
                      }).toList(),
                      onChanged: (Car? value) {
                        setState(() {
                          _selectedCar = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // 選択された車両の表示設定
                    if (_selectedCar != null)
                      Expanded(
                        child: _buildVisibilitySettings(
                            context, _selectedCar!, setState),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVisibilitySettings(
      BuildContext context, Car car, StateSetter setState) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final visibilitySettings = settingsProvider.getVisibilitySettings(car.id);

    // 設定項目をカテゴリごとにグループ化
    final Map<String, List<MapEntry<String, String>>> settingGroups = {
      '基本情報': [
        MapEntry('date', '日付'),
        MapEntry('track', 'トラック'),
        MapEntry('surface', '路面'),
        MapEntry('airTemp', '気温'),
        MapEntry('humidity', '湿度'),
        MapEntry('trackTemp', '路面温度'),
        MapEntry('condition', 'コンディション'),
      ],
      'フロント設定': [
        MapEntry('frontCamber', 'キャンバー角'),
        MapEntry('frontRideHeight', '車高'),
        MapEntry('frontDamperPosition', 'ダンパーポジション'),
        MapEntry('frontSpring', 'スプリング'),
        MapEntry('frontToe', 'トー角'),
        MapEntry('frontCasterAngle', 'キャスター角'),
        MapEntry('frontStabilizer', 'スタビライザー'),
      ],
      'リア設定': [
        MapEntry('rearCamber', 'キャンバー角'),
        MapEntry('rearRideHeight', '車高'),
        MapEntry('rearDamperPosition', 'ダンパーポジション'),
        MapEntry('rearSpring', 'スプリング'),
        MapEntry('rearToe', 'トー角'),
        MapEntry('rearStabilizer', 'スタビライザー'),
      ],
      'トップ設定': [
        MapEntry('upperDeckScrewPosition', 'アッパーデッキスクリューポジション'),
        MapEntry('upperDeckflexType', 'アッパーデッキフレックスタイプ'),
        MapEntry('ballastFrontRight', 'バラスト前右'),
        MapEntry('ballastFrontLeft', 'バラスト前左'),
        MapEntry('ballastMiddle', 'バラスト中央'),
        MapEntry('ballastBattery', 'バラストバッテリー'),
      ],
      'その他設定': [
        MapEntry('motor', 'モーター'),
        MapEntry('spurGear', 'スパーギア'),
        MapEntry('pinionGear', 'ピニオンギア'),
        MapEntry('battery', 'バッテリー'),
        MapEntry('body', 'ボディ'),
        MapEntry('bodyWeight', 'ボディ重量'),
        MapEntry('wing', 'ウイング'),
        MapEntry('tire', 'タイヤ'),
        MapEntry('wheel', 'ホイール'),
        MapEntry('tireInsert', 'タイヤインサート'),
      ],
    };

    return ListView.builder(
      shrinkWrap: true,
      itemCount: settingGroups.length,
      itemBuilder: (context, index) {
        final category = settingGroups.keys.elementAt(index);
        final settings = settingGroups[category]!;

        return ExpansionTile(
          title: Text(category),
          children: settings.map((setting) {
            final key = setting.key;
            final label = setting.value;
            final isVisible =
                visibilitySettings.settingsVisibility[key] ?? true;

            return SwitchListTile(
              title: Text(label),
              value: isVisible,
              onChanged: (bool value) {
                settingsProvider.toggleSettingVisibility(car.id, key, value);
                setState(() {});
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('言語を選択'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('日本語'),
                onTap: () {
                  setState(() {
                    _selectedLanguage = '日本語';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('English'),
                onTap: () {
                  setState(() {
                    _selectedLanguage = 'English';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Rc Setting Manager',
      applicationVersion: '0.0.1',
      applicationIcon: Image.asset(
        'assets/launcher_icon/ios_icon.png',
        width: 48,
        height: 48,
      ),
      children: [
        const Text('ラジコンのセッティングを管理するためのアプリです。'),
        const SizedBox(height: 16),
        const Text('© 2025 Akihisa Iwata'),
      ],
    );
  }
}
