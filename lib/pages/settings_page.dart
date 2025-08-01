import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../models/car.dart';
import 'import_export_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Car> _cars = [];
  Car? _selectedCar;
  bool _canDisplaySetting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load car list
    final settingsProvider = Provider.of<SettingsProvider>(context);
    _loadCars(settingsProvider);
  }

  void _loadCars(SettingsProvider settingsProvider) {
    // Get car list from saved settings
    final savedSettings = settingsProvider.savedSettings;
    final Map<String, Car> uniqueCars = {};

    for (var setting in savedSettings) {
      uniqueCars[setting.car.id] = setting.car;
    }

    setState(() {
      _cars = uniqueCars.values.toList();
      // Select first car if exists
      if (_cars.isNotEmpty && _selectedCar == null) {
        _selectedCar = _cars.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    // AuthServiceを安全に取得（Firebaseが初期化されていない場合はnull）
    AuthService? authService;
    try {
      authService = Provider.of<AuthService>(context, listen: false);
    } catch (e) {
      authService = null;
    }
    final isEnglish = settingsProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? 'Settings' : '設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        children: [
          SwitchListTile(
            title: Text(isEnglish ? 'Dark Mode' : 'ダークモード'),
            subtitle:
                Text(isEnglish ? 'Switch to dark appearance' : 'アプリの外観を暗くします'),
            value: themeProvider.isDarkMode,
            onChanged: (bool value) {
              themeProvider.toggleTheme();
            },
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          ),
          const SizedBox(height: 8.0),
          const Divider(),
          const SizedBox(height: 8.0),
          ListTile(
            title: Text(isEnglish ? 'Display Settings' : '表示設定'),
            subtitle: Text(isEnglish
                ? 'Set display items for each machine'
                : '各マシンごとの表示項目を設定します'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              _showVisibilitySettingsDialog(context);
            },
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          ),
          const SizedBox(height: 16.0),
          ListTile(
            title: Text(isEnglish ? 'Auto Save' : '自動保存'),
            subtitle: Text(isEnglish
                ? 'Automatically save setting changes (Coming Soon)'
                : 'セッティングの変更を自動的に保存します（準備中）'),
            trailing: const Icon(Icons.lock_outline),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          ),
          const SizedBox(height: 16.0),
          ListTile(
            title: Text(isEnglish ? 'Language' : '言語'),
            subtitle: Text(isEnglish ? 'English' : '日本語'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showLanguageDialog(context),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          ),
          const SizedBox(height: 8.0),
          const Divider(),
          const SizedBox(height: 8.0),
          // オンライン機能セクション
          ListTile(
            title: Text(isEnglish ? 'Online Features' : 'オンライン機能'),
            subtitle: Text(isEnglish
                ? 'Sign in to sync your data across devices'
                : 'サインインしてデバイス間でデータを同期'),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          ),
          if (authService == null || !authService.isFirebaseAvailable) ...[
            ListTile(
              title: Text(
                  isEnglish ? 'Firebase Not Available' : 'Firebaseが利用できません'),
              subtitle: Text(isEnglish
                  ? 'Please check Firebase configuration'
                  : 'Firebase設定を確認してください'),
              leading: const Icon(Icons.warning, color: Colors.orange),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            ),
          ] else if (!authService.isSignedIn) ...[
            ListTile(
              title: Text(isEnglish ? 'Sign In / Sign Up' : 'サインイン / サインアップ'),
              subtitle: Text(isEnglish
                  ? 'Create account or sign in to sync data'
                  : 'アカウントを作成またはサインインしてデータを同期'),
              leading: const Icon(Icons.login),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).pushNamed('/login');
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            ),
          ] else ...[
            ListTile(
              title: Text(isEnglish ? 'Signed in as' : 'サインイン中'),
              subtitle: Text(authService.currentUser?.email ?? ''),
              leading: const Icon(Icons.account_circle),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            ),
            SwitchListTile(
              title: Text(isEnglish ? 'Online Sync' : 'オンライン同期'),
              subtitle: Text(isEnglish
                  ? 'Automatically sync data to cloud'
                  : 'データを自動的にクラウドに同期'),
              value: settingsProvider.isOnlineMode,
              onChanged: (bool value) async {
                try {
                  await settingsProvider.toggleOnlineMode();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value
                            ? (isEnglish
                                ? 'Online sync enabled'
                                : 'オンライン同期が有効になりました')
                            : (isEnglish
                                ? 'Online sync disabled'
                                : 'オンライン同期が無効になりました')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEnglish
                            ? 'Failed to toggle sync: $e'
                            : '同期の切り替えに失敗しました: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            ),
            ListTile(
              title: Text(isEnglish ? 'Sync Now' : '今すぐ同期'),
              subtitle: Text(
                  isEnglish ? 'Manually sync data to cloud' : '手動でデータをクラウドに同期'),
              leading: const Icon(Icons.sync),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                try {
                  await settingsProvider.syncToFirebase();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEnglish
                            ? 'Data synced successfully'
                            : 'データの同期が完了しました'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            isEnglish ? 'Sync failed: $e' : '同期に失敗しました: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            ),
            ListTile(
              title: Text(isEnglish ? 'Load from Cloud' : 'クラウドから読み込み'),
              subtitle: Text(isEnglish
                  ? 'Load data from cloud storage'
                  : 'クラウドストレージからデータを読み込み'),
              leading: const Icon(Icons.cloud_download),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                try {
                  await settingsProvider.loadFromFirebase();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEnglish
                            ? 'Data loaded successfully'
                            : 'データの読み込みが完了しました'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            isEnglish ? 'Load failed: $e' : '読み込みに失敗しました: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            ),
            ListTile(
              title: Text(isEnglish ? 'Sign Out' : 'サインアウト'),
              leading: const Icon(Icons.logout),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                try {
                  if (authService != null) {
                    await authService.signOut();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEnglish
                            ? 'Signed out successfully'
                            : 'サインアウトしました'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEnglish
                            ? 'Sign out failed: $e'
                            : 'サインアウトに失敗しました: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            ),
          ],
          const SizedBox(height: 16.0),
          const Divider(),
          const SizedBox(height: 16.0),
          ListTile(
            title: Text(isEnglish ? 'Import / Export' : 'インポート / エクスポート'),
            subtitle: Text(isEnglish
                ? 'Backup and restore data using XML files'
                : 'XMLファイルを使用してデータをバックアップ・復元'),
            leading: const Icon(Icons.import_export),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ImportExportPage(),
                ),
              );
            },
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          ),
          const SizedBox(height: 16.0),
          ListTile(
            title: Text(isEnglish ? 'About This App' : 'アプリについて'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showAboutDialog(context),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          ),
        ],
      ),
    );
  }

  void _showVisibilitySettingsDialog(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    if (_canDisplaySetting == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isEnglish
                ? 'This feature is not available yet'
                : 'この機能はまだ準備中です。')),
      );
      return;
    }

    //if (_cars.isEmpty) {
    //ScaffoldMessenger.of(context).showSnackBar(
    //SnackBar(
    //content: Text(isEnglish
    //? 'Please register a car first to configure display settings'
    //: '表示設定を行うには、まず車両を登録してください')),
    //);
    //return;
    //}

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEnglish ? 'Display Settings' : '表示設定'),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Car selection dropdown
                    DropdownButtonFormField<Car>(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Select Car' : '車両を選択',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 16.0),
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
                    const SizedBox(height: 20.0),
                    // Selected car visibility settings
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
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 10.0),
                  ),
                  child: Text(isEnglish ? 'Close' : '閉じる'),
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
    final isEnglish = settingsProvider.isEnglish;

    // 車種固有の利用可能な設定項目を取得
    List<String> availableSettings = car.availableSettings;

    // 利用可能な設定項目がない場合は従来の全ての設定項目を使用
    if (availableSettings.isEmpty) {
      // Group settings by category
      final Map<String, List<MapEntry<String, String>>> settingGroups =
          isEnglish
              ? {
                  'Basic Information': [
                    const MapEntry('date', 'Date'),
                    const MapEntry('track', 'Track'),
                    const MapEntry('surface', 'Surface'),
                    const MapEntry('airTemp', 'Air Temperature'),
                    const MapEntry('humidity', 'Humidity'),
                    const MapEntry('trackTemp', 'Track Temperature'),
                    const MapEntry('condition', 'Condition'),
                  ],
                  'Front Settings': [
                    const MapEntry('frontCamber', 'Camber Angle'),
                    const MapEntry('frontRideHeight', 'Ride Height'),
                    const MapEntry('frontDamperPosition', 'Damper Position'),
                    const MapEntry('frontSpring', 'Spring'),
                    const MapEntry('frontToe', 'Toe Angle'),
                    const MapEntry('frontCasterAngle', 'Caster Angle'),
                    const MapEntry('frontStabilizer', 'Stabilizer'),
                  ],
                  'Rear Settings': [
                    const MapEntry('rearCamber', 'Camber Angle'),
                    const MapEntry('rearRideHeight', 'Ride Height'),
                    const MapEntry('rearDamperPosition', 'Damper Position'),
                    const MapEntry('rearSpring', 'Spring'),
                    const MapEntry('rearToe', 'Toe Angle'),
                    const MapEntry('rearStabilizer', 'Stabilizer'),
                  ],
                  'Top Settings': [
                    const MapEntry(
                        'upperDeckScrewPosition', 'Upper Deck Screw Position'),
                    const MapEntry('upperDeckflexType', 'Upper Deck Flex Type'),
                    const MapEntry('ballastFrontRight', 'Ballast Front Right'),
                    const MapEntry('ballastFrontLeft', 'Ballast Front Left'),
                    const MapEntry('ballastMiddle', 'Ballast Middle'),
                    const MapEntry('ballastBattery', 'Ballast Battery'),
                  ],
                  'Other Settings': [
                    const MapEntry('motor', 'Motor'),
                    const MapEntry('spurGear', 'Spur Gear'),
                    const MapEntry('pinionGear', 'Pinion Gear'),
                    const MapEntry('battery', 'Battery'),
                    const MapEntry('body', 'Body'),
                    const MapEntry('bodyWeight', 'Body Weight'),
                    const MapEntry('wing', 'Wing'),
                    const MapEntry('tire', 'Tire'),
                    const MapEntry('wheel', 'Wheel'),
                    const MapEntry('tireInsert', 'Tire Insert'),
                  ],
                }
              : {
                  '基本情報': [
                    const MapEntry('date', '日付'),
                    const MapEntry('track', 'トラック'),
                    const MapEntry('surface', '路面'),
                    const MapEntry('airTemp', '気温'),
                    const MapEntry('humidity', '湿度'),
                    const MapEntry('trackTemp', '路面温度'),
                    const MapEntry('condition', 'コンディション'),
                  ],
                  'フロント設定': [
                    const MapEntry('frontCamber', 'キャンバー角'),
                    const MapEntry('frontRideHeight', '車高'),
                    const MapEntry('frontDamperPosition', 'ダンパーポジション'),
                    const MapEntry('frontSpring', 'スプリング'),
                    const MapEntry('frontToe', 'トー角'),
                    const MapEntry('frontCasterAngle', 'キャスター角'),
                    const MapEntry('frontStabilizer', 'スタビライザー'),
                  ],
                  'リア設定': [
                    const MapEntry('rearCamber', 'キャンバー角'),
                    const MapEntry('rearRideHeight', '車高'),
                    const MapEntry('rearDamperPosition', 'ダンパーポジション'),
                    const MapEntry('rearSpring', 'スプリング'),
                    const MapEntry('rearToe', 'トー角'),
                    const MapEntry('rearStabilizer', 'スタビライザー'),
                  ],
                  'トップ設定': [
                    const MapEntry(
                        'upperDeckScrewPosition', 'アッパーデッキスクリューポジション'),
                    const MapEntry('upperDeckflexType', 'アッパーデッキフレックスタイプ'),
                    const MapEntry('ballastFrontRight', 'バラスト前右'),
                    const MapEntry('ballastFrontLeft', 'バラスト前左'),
                    const MapEntry('ballastMiddle', 'バラスト中央'),
                    const MapEntry('ballastBattery', 'バラストバッテリー'),
                  ],
                  'その他設定': [
                    const MapEntry('motor', 'モーター'),
                    const MapEntry('spurGear', 'スパーギア'),
                    const MapEntry('pinionGear', 'ピニオンギア'),
                    const MapEntry('battery', 'バッテリー'),
                    const MapEntry('body', 'ボディ'),
                    const MapEntry('bodyWeight', 'ボディ重量'),
                    const MapEntry('wing', 'ウイング'),
                    const MapEntry('tire', 'タイヤ'),
                    const MapEntry('wheel', 'ホイール'),
                    const MapEntry('tireInsert', 'タイヤインサート'),
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
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            childrenPadding: const EdgeInsets.only(left: 16.0, right: 16.0),
            children: settings.map((setting) {
              final key = setting.key;
              final label = setting.value;
              final isVisible =
                  visibilitySettings.settingsVisibility[key] ?? true;

              return SwitchListTile(
                title: Text(label),
                value: isVisible,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                onChanged: (bool value) {
                  setState(() {
                    settingsProvider.toggleSettingVisibility(
                        car.id, key, value);
                  });
                },
              );
            }).toList(),
          );
        },
      );
    } else {
      // 車種固有の設定項目を使用して表示
      // 設定項目をカテゴリ別にグループ化するためのヘルパー関数
      Map<String, List<String>> groupSettingsByCategory(List<String> settings) {
        Map<String, List<String>> groups = {};

        for (var setting in settings) {
          String category = 'その他';

          if (setting.startsWith('front')) {
            if (setting.contains('Damper') || setting.contains('Dumper')) {
              category = isEnglish ? 'Front Damper Settings' : 'フロントダンパー設定';
            } else {
              category = isEnglish ? 'Front Settings' : 'フロント設定';
            }
          } else if (setting.startsWith('rear')) {
            if (setting.contains('Damper') || setting.contains('Dumper')) {
              category = isEnglish ? 'Rear Damper Settings' : 'リアダンパー設定';
            } else {
              category = isEnglish ? 'Rear Settings' : 'リア設定';
            }
          } else if (setting == 'date' ||
              setting == 'track' ||
              setting == 'surface' ||
              setting == 'airTemp' ||
              setting == 'humidity' ||
              setting == 'trackTemp' ||
              setting == 'condition') {
            category = isEnglish ? 'Basic Information' : '基本情報';
          } else if (setting.contains('upperDeck') ||
              setting.contains('ballast')) {
            category = isEnglish ? 'Top Settings' : 'トップ設定';
          } else if (setting.contains('knucklearm') ||
              setting.contains('steering') ||
              setting.contains('lowerDeck')) {
            category = isEnglish ? 'Top Detailed Settings' : 'トップ詳細設定';
          }

          if (!groups.containsKey(category)) {
            groups[category] = [];
          }
          groups[category]!.add(setting);
        }

        return groups;
      }

      // 設定項目名から表示ラベルを取得するヘルパー関数
      String getSettingLabel(String key) {
        // 英語の場合のラベルマッピング
        Map<String, String> englishLabels = {
          'date': 'Date',
          'track': 'Track',
          'surface': 'Surface',
          'airTemp': 'Air Temperature',
          'humidity': 'Humidity',
          'trackTemp': 'Track Temperature',
          'condition': 'Condition',
          'frontCamber': 'Front Camber Angle',
          'frontRideHeight': 'Front Ride Height',
          'frontDamperPosition': 'Front Damper Position',
          'frontSpring': 'Front Spring',
          'frontToe': 'Front Toe Angle',
          // 他の項目も同様に追加...
        };

        // 日本語の場合のラベルマッピング
        Map<String, String> japaneseLabels = {
          'date': '日付',
          'track': 'トラック',
          'surface': '路面',
          'airTemp': '気温',
          'humidity': '湿度',
          'trackTemp': '路面温度',
          'condition': 'コンディション',
          'frontCamber': 'フロントキャンバー角',
          'frontRideHeight': 'フロントライドハイト',
          'frontDamperPosition': 'フロントダンパーポジション',
          'frontSpring': 'フロントスプリング',
          'frontToe': 'フロントトー角',
          // 他の項目も同様に追加...
        };

        // 言語に応じたラベルを返す
        if (isEnglish) {
          return englishLabels[key] ?? key; // マッピングがない場合はキーをそのまま使用
        } else {
          return japaneseLabels[key] ?? key; // マッピングがない場合はキーをそのまま使用
        }
      }

      // 利用可能な設定項目をカテゴリ別にグループ化
      final groupedSettings = groupSettingsByCategory(availableSettings);

      return ListView.builder(
        shrinkWrap: true,
        itemCount: groupedSettings.length,
        itemBuilder: (context, index) {
          final category = groupedSettings.keys.elementAt(index);
          final settings = groupedSettings[category]!;

          return ExpansionTile(
            title: Text(category),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            childrenPadding: const EdgeInsets.only(left: 16.0, right: 16.0),
            children: settings.map((key) {
              final label = getSettingLabel(key);
              final isVisible =
                  visibilitySettings.settingsVisibility[key] ?? true;

              return SwitchListTile(
                title: Text(label),
                value: isVisible,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                onChanged: (bool value) {
                  setState(() {
                    settingsProvider.toggleSettingVisibility(
                        car.id, key, value);
                  });
                },
              );
            }).toList(),
          );
        },
      );
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEnglish ? 'Select Language' : '言語を選択'),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('日本語'),
                leading: Radio<bool>(
                  value: false,
                  groupValue: isEnglish,
                  onChanged: (bool? value) {
                    if (value != null && value == false) {
                      settingsProvider.toggleLanguage();
                      Navigator.of(context).pop();
                    }
                  },
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                onTap: () {
                  if (isEnglish) {
                    settingsProvider.toggleLanguage();
                    Navigator.of(context).pop();
                  }
                },
              ),
              const SizedBox(height: 8.0),
              ListTile(
                title: const Text('English'),
                leading: Radio<bool>(
                  value: true,
                  groupValue: isEnglish,
                  onChanged: (bool? value) {
                    if (value != null && value == true) {
                      settingsProvider.toggleLanguage();
                      Navigator.of(context).pop();
                    }
                  },
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                onTap: () {
                  if (!isEnglish) {
                    settingsProvider.toggleLanguage();
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
              ),
              child: Text(isEnglish ? 'Close' : '閉じる'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEnglish ? 'About This App' : 'アプリについて'),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEnglish ? 'RC Car Setting Manager' : 'RCカーセッティング管理アプリ'),
              const SizedBox(height: 16),
              Text(isEnglish ? 'Version: 1.0.0' : 'バージョン: 1.0.0'),
              const SizedBox(height: 16),
              Text(isEnglish
                  ? 'This app helps you manage settings for your RC cars.'
                  : 'このアプリはRCカーのセッティングを管理するためのアプリです。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
              ),
              child: Text(isEnglish ? 'Close' : '閉じる'),
            ),
          ],
        );
      },
    );
  }
}
