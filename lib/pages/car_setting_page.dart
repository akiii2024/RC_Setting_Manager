import 'package:flutter/material.dart';
import '../models/car.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../models/saved_setting.dart';
import '../models/visibility_settings.dart';

class CarSettingPage extends StatefulWidget {
  final Car originalCar;
  final Map<String, dynamic>? savedSettings;
  final String? settingName;
  final String? savedSettingId;

  const CarSettingPage({
    super.key,
    required this.originalCar,
    this.savedSettings,
    this.settingName,
    this.savedSettingId,
  });

  @override
  State<CarSettingPage> createState() => _CarSettingPageState();
}

class _CarSettingPageState extends State<CarSettingPage> {
  late String carName;
  late Map<String, dynamic> settings;
  bool _isLoading = true;
  final TextEditingController _settingNameController = TextEditingController();
  bool _isEditing = false;

  late VisibilitySettings _visibilitySettings;
  bool _isVisibilityLoaded = false;

  @override
  void initState() {
    super.initState();
    carName = widget.originalCar.name;

    // Use saved settings if available
    if (widget.savedSettings != null) {
      settings = Map<String, dynamic>.from(widget.savedSettings!);
      _isEditing = widget.savedSettingId != null;
      if (widget.settingName != null) {
        _settingNameController.text = widget.settingName!;
      }
    } else {
      // Set default values
      settings = widget.originalCar.settings ??
          {
            // Basic information
            'date': DateTime.now().toIso8601String(),
            'track': '',
            'surface': '',
            'airTemp': 0,
            'humidity': 0,
            'trackTemp': 0,
            'condition': '',

            // Front settings
            'frontCamber': 0.0,
            'frontRideHeight': 0.0,
            'frontDamperPosition': 1,
            'frontSpring': '',
            'frontToe': 0.0,

            // Front detailed settings
            'frontUpperArmSpacer': 0.0,
            'frontUpperArmSpacerInside': 0.0,
            'frontUpperArmSpacerOutside': 0.0,
            'frontLowerArmSpacer': 0.0,
            'frontWheelHub': 0.0,
            'frontWheelHubSpacer': 0.0,
            'frontDroop': 0.0,
            'frontDiffarentialPosition': 'low',
            'frontSusMountFront': '',
            'frontSusMountRear': '',
            'frontSusMountFrontShaftPosition': '2,2',
            'frontSusMountRearShaftPosition': '2,2',
            'frontCasterAngle': 0.0,
            'frontStabilizer': '',
            'frontDrive': '',
            'frontDifferentialOil': '',
            'frontDumperPosition': '',

            // Front damper settings
            'frontDamperOffsetStay': 0.0,
            'frontDamperOffsetArm': 0.0,
            'frontDumperType': '',
            'frontDumperOilSeal': '',
            'frontDumperPistonSize': '',
            'frontDumperPistonHole': '',
            'frontDumperOilHardness': '',
            'frontDumperOilName': '',
            'frontDumperStroke': '',
            'frontDumperAirHole': '',

            // リア設定
            'rearCamber': 0.0,
            'rearRideHeight': 0.0,
            'rearDamperPosition': 1,
            'rearSpring': '',
            'rearToe': 0.0,

            // リア詳細設定
            'rearUpperArmSpacer': 0.0,
            'rearUpperArmSpacerInside': 0.0,
            'rearUpperArmSpacerOutside': 0.0,
            'rearLowerArmSpacer': 0.0,
            'rearWheelHub': 0.0,
            'rearWheelHubSpacer': 0.0,
            'rearDroop': 0.0,
            'rearDiffarentialPosition': 'low',
            'rearSusMountFront': '',
            'rearSusMountRear': '',
            'rearSusMountFrontShaftPosition': '2,2',
            'rearSusMountRearShaftPosition': '2,2',
            'rearStabilizer': '',
            'rearDrive': '',
            'rearDifferentialOil': '',
            'rearDumperPosition': 1,

            // リアダンパー設定
            'rearDamperOffsetStay': 0.0,
            'rearDamperOffsetArm': 0.0,
            'rearDumperType': '',
            'rearDumperOilSeal': '',
            'rearDumperPistonSize': '',
            'rearDumperPistonHole': '',
            'rearDumperOilHardness': '',
            'rearDumperOilName': '',
            'rearDumperStroke': '',
            'rearDumperAirHole': '',

            // トップ設定
            'upperDeckScrewPosition': '',
            'upperDeckflexType': '',
            'ballastFrontRight': 0.0,
            'ballastFrontLeft': 0.0,
            'ballastMiddle': 0.0,
            'ballastBattery': 0.0,

            //トップ詳細設定
            'knucklearmType': '',
            'kuncklearmUprightSpacer': 0.0,
            'steeringPivot': '',
            'steeringSpacer': 0.0,
            'frontSuspensionArmSpacer': 0.0,
            'rearSuspensionType': '',
            'rearSuspensionArmSpacer': 0.0,
            'lowerDeckThickness': 0.0,
            'lowerDeckMaterial': '',

            //その他設定
            'motor': '',
            'spurGear': '',
            'pinionGear': '',
            'battery': '',
            'body': '',
            'bodyWeight': 0.0,
            'frontBodyMountHolePosition': '',
            'rearBodyMountHolePosition': '',
            'wing': '',
            'tire': '',
            'wheel': '',
            'tireInsert': '',
          };
    }

    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    // Load visibility settings
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      _visibilitySettings =
          settingsProvider.getVisibilitySettings(widget.originalCar.id);
      setState(() {
        _isVisibilityLoaded = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    final saveButtonText = _isEditing
        ? (isEnglish ? 'Update' : '更新')
        : (isEnglish ? 'Save' : '保存');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (isEnglish ? 'Edit Setting' : 'セッティング編集')
            : (isEnglish ? 'New Setting' : '新規セッティング')),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSetting,
            tooltip: saveButtonText,
          ),
          IconButton(
            icon: const Icon(Icons.visibility),
            onPressed: () {
              _showVisibilityDialog(context);
            },
            tooltip: isEnglish ? 'Display Options' : '表示オプション',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'share':
                  _shareSetting();
                  break;
                case 'delete':
                  if (_isEditing) {
                    _showDeleteConfirmationDialog();
                  }
                  break;
              }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  value: 'share',
                  child: Row(
                    children: [
                      const Icon(Icons.share, size: 20),
                      const SizedBox(width: 8),
                      Text(isEnglish ? 'Share' : '共有'),
                    ],
                  ),
                ),
                if (_isEditing)
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          isEnglish ? 'Delete' : '削除',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Setting name input
                  TextField(
                    controller: _settingNameController,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Setting Name' : 'セッティング名',
                      hintText:
                          isEnglish ? 'e.g. Race Setup 1' : '例：レースセットアップ1',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 16.0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Car information
                  Text(
                    '${isEnglish ? 'Car' : '車両'}: $carName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Setting tabs
                  Expanded(
                    child: _buildSettingTabs(context),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveSetting,
        tooltip: saveButtonText,
        child: const Icon(Icons.save),
      ),
    );
  }

  Widget _buildSettingTabs(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: isEnglish ? 'Basic' : '基本'),
              Tab(text: isEnglish ? 'Front' : 'フロント'),
              Tab(text: isEnglish ? 'Rear' : 'リア'),
              Tab(text: isEnglish ? 'Top Deck' : 'トップデッキ'),
              Tab(text: isEnglish ? 'Other' : 'その他'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Basic Info Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  child: _buildBasicInfoTab(),
                ),
                // Front Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  child: _buildFrontSettingsTab(),
                ),
                // Rear Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  child: _buildRearSettingsTab(),
                ),
                // Top Deck Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  child: _buildTopDeckSettingsTab(),
                ),
                // Other Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  child: _buildOtherSettingsTab(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isEnglish ? 'Basic Information' : '基本情報',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // 日付とトラックの行
        _buildSettingsRow(
          'date',
          'track',
          _buildSettingField(
            'date',
            isEnglish ? 'Date' : '日付',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Date' : '日付',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              initialValue: settings['date'] != null
                  ? DateTime.parse(settings['date'])
                      .toString()
                      .split(' ')[0]
                      .replaceAll('-', '/')
                  : DateTime.now().toString().split(' ')[0],
              onChanged: (value) {
                settings['date'] = DateTime.parse(value.replaceAll('/', '-'))
                    .toIso8601String();
              },
            ),
          ),
          _buildSettingField(
            'track',
            isEnglish ? 'Track' : 'トラック',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Track' : 'トラック',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              initialValue: settings['track'],
              onChanged: (value) {
                settings['track'] = value;
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 路面とコンディションの行
        _buildSettingsRow(
          'surface',
          'condition',
          _buildSettingField(
            'surface',
            isEnglish ? 'Surface' : '路面',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Surface' : '路面',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              initialValue: settings['surface'],
              onChanged: (value) {
                settings['surface'] = value;
              },
            ),
          ),
          _buildSettingField(
            'condition',
            isEnglish ? 'Condition' : 'コンディション',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Condition' : 'コンディション',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              initialValue: settings['condition'],
              onChanged: (value) {
                settings['condition'] = value;
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 気温と湿度の行
        _buildSettingsRow(
          'airTemp',
          'humidity',
          _buildSettingField(
            'airTemp',
            isEnglish ? 'Air Temperature' : '気温',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Air Temperature (℃)' : '気温 (℃)',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              initialValue: settings['airTemp'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                settings['airTemp'] = int.tryParse(value) ?? 0;
              },
            ),
          ),
          _buildSettingField(
            'humidity',
            isEnglish ? 'Humidity' : '湿度',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Humidity (%)' : '湿度 (%)',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              initialValue: settings['humidity'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                settings['humidity'] = int.tryParse(value) ?? 0;
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 路面温度の行（単独項目）
        _buildSingleSetting(
          'trackTemp',
          _buildSettingField(
            'trackTemp',
            isEnglish ? 'Track Temperature' : '路面温度',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Track Temperature (℃)' : '路面温度 (℃)',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              initialValue: settings['trackTemp'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                settings['trackTemp'] = int.tryParse(value) ?? 0;
              },
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFrontSettingsTab() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isEnglish ? 'Front Settings' : 'フロント設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // キャンバー角と車高の行
        _buildSettingsRow(
          'frontCamber',
          'frontRideHeight',
          _buildSettingField(
            'frontCamber',
            isEnglish ? 'Camber Angle' : 'キャンバー角',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Camber Angle' : 'キャンバー角',
                border: OutlineInputBorder(),
                suffixText: '°',
              ),
              initialValue: settings['frontCamber'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                settings['frontCamber'] = double.tryParse(value) ?? 0.0;
              },
            ),
          ),
          _buildSettingField(
            'frontRideHeight',
            isEnglish ? 'Ride Height' : '車高',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Ride Height' : '車高',
                border: OutlineInputBorder(),
                suffixText: 'mm',
              ),
              initialValue: settings['frontRideHeight'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                settings['frontRideHeight'] = double.tryParse(value) ?? 0.0;
              },
            ),
          ),
        ),

        // ダンパーポジションとスプリングの行
        _buildSettingsRow(
          'frontDamperPosition',
          'frontSpring',
          _buildSettingField(
            'frontDamperPosition',
            isEnglish ? 'Damper Position' : 'ダンパーポジション',
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Damper Position' : 'ダンパーポジション',
                border: OutlineInputBorder(),
              ),
              value: settings['frontDamperPosition'],
              items: List.generate(5, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}'),
                );
              }),
              onChanged: (value) {
                settings['frontDamperPosition'] = value;
              },
            ),
          ),
          _buildSettingField(
            'frontSpring',
            isEnglish ? 'Spring' : 'スプリング',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Spring' : 'スプリング',
                border: OutlineInputBorder(),
              ),
              initialValue: settings['frontSpring'],
              onChanged: (value) {
                settings['frontSpring'] = value;
              },
            ),
          ),
        ),

        // トー角とスタビライザーの行
        _buildSettingsRow(
          'frontToe',
          'frontStabilizer',
          _buildSettingField(
            'frontToe',
            isEnglish ? 'Toe Angle' : 'トー角',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Toe Angle' : 'トー角',
                border: OutlineInputBorder(),
                suffixText: '°',
              ),
              initialValue: settings['frontToe'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                settings['frontToe'] = double.tryParse(value) ?? 0.0;
              },
            ),
          ),
          _buildSettingField(
            'frontStabilizer',
            isEnglish ? 'Stabilizer' : 'スタビライザー',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Stabilizer' : 'スタビライザー',
                border: OutlineInputBorder(),
              ),
              initialValue: settings['frontStabilizer'],
              onChanged: (value) {
                settings['frontStabilizer'] = value;
              },
            ),
          ),
        ),

        // キャスター角（単独項目）
        _buildSingleSetting(
          'frontCasterAngle',
          _buildSettingField(
            'frontCasterAngle',
            isEnglish ? 'Caster Angle' : 'キャスター角',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Caster Angle' : 'キャスター角',
                border: OutlineInputBorder(),
                suffixText: '°',
              ),
              initialValue: settings['frontCasterAngle'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                settings['frontCasterAngle'] = double.tryParse(value) ?? 0.0;
              },
            ),
          ),
        ),

        // 詳細設定の展開パネル
        _buildSingleSetting(
          'frontDetails',
          _buildSettingField(
            'frontDetails',
            isEnglish ? 'Detailed Settings' : '詳細設定',
            _buildExpandablePanel(
              title: isEnglish ? 'Detailed Settings' : '詳細設定',
              children: [
                const SizedBox(height: 8),
                Text(
                  isEnglish ? 'Upper Arm Spacer' : 'アッパーアームスペーサー',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),

                // 内側と外側のスペーサー設定
                _buildSettingsRow(
                  'frontUpperArmSpacerInside',
                  'frontUpperArmSpacerOutside',
                  _buildSettingField(
                    'frontUpperArmSpacerInside',
                    isEnglish ? 'Inside' : '内側',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Inside (mm)' : '内側 (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['frontUpperArmSpacerInside']?.toString() ??
                              '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['frontUpperArmSpacerInside'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                  _buildSettingField(
                    'frontUpperArmSpacerOutside',
                    isEnglish ? 'Outside' : '外側',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Outside (mm)' : '外側 (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['frontUpperArmSpacerOutside']?.toString() ??
                              '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['frontUpperArmSpacerOutside'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ロアアームスペーサー（単独項目）
                _buildSingleSetting(
                  'frontLowerArmSpacer',
                  _buildSettingField(
                    'frontLowerArmSpacer',
                    isEnglish ? 'Lower Arm Spacer' : 'ロアアームスペーサー',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText:
                            isEnglish ? 'Lower Arm Spacer' : 'ロアアームスペーサー (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['frontLowerArmSpacer']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['frontLowerArmSpacer'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ホイールハブ関連設定
                _buildSettingsRow(
                  'frontWheelHub',
                  'frontWheelHubSpacer',
                  _buildSettingField(
                    'frontWheelHub',
                    'ホイールハブ',
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'ホイールハブ (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['frontWheelHub']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['frontWheelHub'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                  _buildSettingField(
                    'frontWheelHubSpacer',
                    'ホイールハブスペーサー',
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'ホイールハブスペーサー (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['frontWheelHubSpacer']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['frontWheelHubSpacer'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ドループ設定（単独項目）
                _buildSingleSetting(
                  'frontDroop',
                  _buildSettingField(
                    'frontDroop',
                    'ドループ',
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'ドループ (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: settings['frontDroop']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['frontDroop'] = double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // デフ位置設定（単独項目）
                _buildSingleSetting(
                  'frontDiffarentialPosition',
                  _buildSettingField(
                    'frontDiffarentialPosition',
                    'デフ位置',
                    Row(
                      children: [
                        const Text('デフ位置: '),
                        const SizedBox(width: 8),
                        ToggleButtons(
                          isSelected: [
                            settings['frontDiffarentialPosition'] == 'high',
                            settings['frontDiffarentialPosition'] == 'low',
                          ],
                          onPressed: (index) {
                            setState(() {
                              settings['frontDiffarentialPosition'] =
                                  ['high', 'low'][index];
                            });
                          },
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('高'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('低'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // サスマウント前後設定
                _buildSettingsRow(
                  'frontSusMountFront',
                  'frontSusMountRear',
                  _buildSettingField(
                    'frontSusMountFront',
                    'サスマウント前',
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'サスマウント前',
                        border: OutlineInputBorder(),
                      ),
                      value: settings['frontSusMountFront'].isEmpty
                          ? null
                          : settings['frontSusMountFront'],
                      items: const [
                        DropdownMenuItem(value: 'XB', child: Text('XB')),
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'E', child: Text('E')),
                      ],
                      onChanged: (value) {
                        settings['frontSusMountFront'] = value;
                      },
                    ),
                  ),
                  _buildSettingField(
                    'frontSusMountRear',
                    'サスマウント後',
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'サスマウント後',
                        border: OutlineInputBorder(),
                      ),
                      value: settings['frontSusMountRear'].isEmpty
                          ? null
                          : settings['frontSusMountRear'],
                      items: const [
                        DropdownMenuItem(value: 'XB', child: Text('XB')),
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'E', child: Text('E')),
                      ],
                      onChanged: (value) {
                        settings['frontSusMountRear'] = value;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // サスマウントシャフト位置設定
                _buildSettingsRow(
                  'frontSusMountFrontShaftPosition',
                  'frontSusMountRearShaftPosition',
                  _buildSettingField(
                    'frontSusMountFrontShaftPosition',
                    'サスマウント前シャフト位置',
                    _buildGridSelector(
                      label: 'サスマウント前シャフト位置',
                      settingKey: 'frontSusMountFrontShaftPosition',
                      size: 150,
                    ),
                  ),
                  _buildSettingField(
                    'frontSusMountRearShaftPosition',
                    'サスマウント後シャフト位置',
                    _buildGridSelector(
                      label: 'サスマウント後シャフト位置',
                      settingKey: 'frontSusMountRearShaftPosition',
                      size: 150,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // デフ関連設定
                _buildSettingsRow(
                  'frontDrive',
                  'frontDifferentialOil',
                  _buildSettingField(
                    'frontDrive',
                    'デフ種類',
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'デフ種類',
                        border: OutlineInputBorder(),
                      ),
                      value: settings['frontDrive'].isEmpty
                          ? null
                          : settings['frontDrive'],
                      items: const [
                        DropdownMenuItem(value: 'スプール', child: Text('スプール')),
                        DropdownMenuItem(value: 'ギアデフ', child: Text('ギアデフ')),
                        DropdownMenuItem(value: 'ボールデフ', child: Text('ボールデフ')),
                        DropdownMenuItem(value: 'ワンウェイ', child: Text('ワンウェイ')),
                      ],
                      onChanged: (value) {
                        settings['frontDrive'] = value;
                      },
                    ),
                  ),
                  _buildSettingField(
                    'frontDifferentialOil',
                    'デフオイル',
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'デフオイル',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: settings['frontDifferentialOil'],
                      onChanged: (value) {
                        settings['frontDifferentialOil'] = value;
                      },
                    ),
                  ),
                ),

                // フロントダンパー設定の展開パネル
                _buildSingleSetting(
                  'frontDamperSettings',
                  _buildSettingField(
                    'frontDamperSettings',
                    'フロントダンパー設定',
                    _buildExpandablePanel(
                      title: 'フロントダンパー設定',
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'ダンパーオフセット (mm)',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),

                        // ダンパーオフセット設定
                        _buildSettingsRow(
                          'frontDamperOffsetStay',
                          'frontDamperOffsetArm',
                          _buildSettingField(
                            'frontDamperOffsetStay',
                            'ステー',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ステー (mm)',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDamperOffsetStay']
                                      ?.toString() ??
                                  '0.0',
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                settings['frontDamperOffsetStay'] =
                                    double.tryParse(value) ?? 0.0;
                              },
                            ),
                          ),
                          _buildSettingField(
                            'frontDamperOffsetArm',
                            'サスアーム',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'サスアーム (mm)',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDamperOffsetArm']
                                      ?.toString() ??
                                  '0.0',
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                settings['frontDamperOffsetArm'] =
                                    double.tryParse(value) ?? 0.0;
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ダンパータイプとオイルシール設定
                        _buildSettingsRow(
                          'frontDumperType',
                          'frontDumperOilSeal',
                          _buildSettingField(
                            'frontDumperType',
                            'ダンパータイプ',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ダンパータイプ',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDumperType'],
                              onChanged: (value) {
                                settings['frontDumperType'] = value;
                              },
                            ),
                          ),
                          _buildSettingField(
                            'frontDumperOilSeal',
                            'オイルシール',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'オイルシール',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDumperOilSeal'],
                              onChanged: (value) {
                                settings['frontDumperOilSeal'] = value;
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ピストン関連設定
                        _buildSettingsRow(
                          'frontDumperPistonSize',
                          'frontDumperPistonHole',
                          _buildSettingField(
                            'frontDumperPistonSize',
                            'ピストンサイズ',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ピストンサイズ',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDumperPistonSize'],
                              onChanged: (value) {
                                settings['frontDumperPistonSize'] = value;
                              },
                            ),
                          ),
                          _buildSettingField(
                            'frontDumperPistonHole',
                            'ピストン穴数',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ピストン穴数',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDumperPistonHole'],
                              onChanged: (value) {
                                settings['frontDumperPistonHole'] = value;
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // オイル関連設定
                        _buildSettingsRow(
                          'frontDumperOilHardness',
                          'frontDumperOilName',
                          _buildSettingField(
                            'frontDumperOilHardness',
                            'オイル硬度',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'オイル硬度',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDumperOilHardness'],
                              onChanged: (value) {
                                settings['frontDumperOilHardness'] = value;
                              },
                            ),
                          ),
                          _buildSettingField(
                            'frontDumperOilName',
                            'オイル名',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'オイル名',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDumperOilName'],
                              onChanged: (value) {
                                settings['frontDumperOilName'] = value;
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ストロークとエア抜き穴設定
                        _buildSettingsRow(
                          'frontDumperStroke',
                          'frontDumperAirHole',
                          _buildSettingField(
                            'frontDumperStroke',
                            'ストローク長',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ストローク長',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDumperStroke'],
                              onChanged: (value) {
                                settings['frontDumperStroke'] = value;
                              },
                            ),
                          ),
                          _buildSettingField(
                            'frontDumperAirHole',
                            'エア抜き穴',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'エア抜き穴(mm)',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDumperAirHole'],
                              onChanged: (value) {
                                settings['frontDumperAirHole'] = value;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRearSettingsTab() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isEnglish ? 'Rear Settings' : 'リア設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildSettingsRow(
          'rearCamber',
          'rearToe',
          _buildSettingField(
            'rearCamber',
            isEnglish ? 'Camber Angle' : 'キャンバー角',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Camber Angle' : 'キャンバー角',
                border: OutlineInputBorder(),
                suffixText: '°',
              ),
              initialValue: settings['rearCamber'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                settings['rearCamber'] = double.tryParse(value) ?? 0.0;
              },
            ),
          ),
          _buildSettingField(
            'rearToe',
            isEnglish ? 'Toe Angle' : 'トー角',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Toe Angle' : 'トー角',
                border: OutlineInputBorder(),
                suffixText: '°',
              ),
              initialValue: settings['rearToe'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                settings['rearToe'] = double.tryParse(value) ?? 0.0;
              },
            ),
          ),
        ),
        _buildSettingsRow(
          'rearRideHeight',
          'rearDamperPosition',
          _buildSettingField(
            'rearRideHeight',
            isEnglish ? 'Ride Height' : '車高',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Ride Height' : '車高',
                border: OutlineInputBorder(),
                suffixText: 'mm',
              ),
              initialValue: settings['rearRideHeight'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                settings['rearRideHeight'] = double.tryParse(value) ?? 0.0;
              },
            ),
          ),
          _buildSettingField(
            'rearDamperPosition',
            isEnglish ? 'Damper Position' : 'ダンパーポジション',
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Damper Position' : 'ダンパーポジション',
                border: OutlineInputBorder(),
              ),
              value: settings['rearDamperPosition'],
              items: List.generate(5, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}'),
                );
              }),
              onChanged: (value) {
                settings['rearDamperPosition'] = value;
              },
            ),
          ),
        ),
        _buildSettingsRow(
          'rearSpring',
          'rearStabilizer',
          _buildSettingField(
            'rearSpring',
            isEnglish ? 'Spring' : 'スプリング',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Spring' : 'スプリング',
                border: OutlineInputBorder(),
              ),
              initialValue: settings['rearSpring'],
              onChanged: (value) {
                settings['rearSpring'] = value;
              },
            ),
          ),
          _buildSettingField(
            'rearStabilizer',
            isEnglish ? 'Stabilizer' : 'スタビライザー',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Stabilizer' : 'スタビライザー',
                border: OutlineInputBorder(),
              ),
              initialValue: settings['rearStabilizer'],
              onChanged: (value) {
                settings['rearStabilizer'] = value;
              },
            ),
          ),
        ),

        // 詳細設定の展開パネル
        _buildSingleSetting(
          'rearDetails',
          _buildSettingField(
            'rearDetails',
            isEnglish ? 'Details Settings' : '詳細設定',
            _buildExpandablePanel(
              title: isEnglish ? 'Details Settings' : '詳細設定',
              children: [
                const SizedBox(height: 8),
                Text(
                  isEnglish ? 'Upper Arm Spacer' : 'アッパーアームスペーサー',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                _buildSettingsRow(
                  'rearUpperArmSpacerInside',
                  'rearUpperArmSpacerOutside',
                  _buildSettingField(
                    'rearUpperArmSpacerInside',
                    isEnglish ? 'Inside' : '内側',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Inside' : '内側 (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['rearUpperArmSpacerInside']?.toString() ??
                              '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['rearUpperArmSpacerInside'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                  _buildSettingField(
                    'rearUpperArmSpacerOutside',
                    isEnglish ? 'Outside' : '外側',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Outside' : '外側 (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['rearUpperArmSpacerOutside']?.toString() ??
                              '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['rearUpperArmSpacerOutside'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildSingleSetting(
                  'rearLowerArmSpacer',
                  _buildSettingField(
                    'rearLowerArmSpacer',
                    isEnglish ? 'Lower Arm Spacer' : 'ロアアームスペーサー',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText:
                            isEnglish ? 'Lower Arm Spacer' : 'ロアアームスペーサー (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['rearLowerArmSpacer']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['rearLowerArmSpacer'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildSettingsRow(
                  'rearWheelHub',
                  'rearWheelHubSpacer',
                  _buildSettingField(
                    'rearWheelHub',
                    isEnglish ? 'Wheel Hub' : 'ホイールハブ',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Wheel Hub' : 'ホイールハブ (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['rearWheelHub']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['rearWheelHub'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                  _buildSettingField(
                    'rearWheelHubSpacer',
                    isEnglish ? 'Wheel Hub Spacer' : 'ホイールハブスペーサー',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText:
                            isEnglish ? 'Wheel Hub Spacer' : 'ホイールハブスペーサー (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['rearWheelHubSpacer']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['rearWheelHubSpacer'] =
                            double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildSingleSetting(
                  'rearDroop',
                  _buildSettingField(
                    'rearDroop',
                    isEnglish ? 'Droop' : 'ドループ',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Droop' : 'ドループ (mm)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: settings['rearDroop']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        settings['rearDroop'] = double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildSingleSetting(
                  'rearDiffarentialPosition',
                  _buildSettingField(
                    'rearDiffarentialPosition',
                    isEnglish ? 'Differential Position' : 'デフ位置',
                    Row(
                      children: [
                        const Text('デフ位置: '),
                        const SizedBox(width: 8),
                        ToggleButtons(
                          isSelected: [
                            settings['rearDiffarentialPosition'] == 'high',
                            settings['rearDiffarentialPosition'] == 'low',
                          ],
                          onPressed: (index) {
                            setState(() {
                              settings['rearDiffarentialPosition'] =
                                  ['high', 'low'][index];
                            });
                          },
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('高'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('低'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildSettingsRow(
                  'rearSusMountFront',
                  'rearSusMountRear',
                  _buildSettingField(
                    'rearSusMountFront',
                    isEnglish ? 'Front Suspension Mount' : 'サスマウント前',
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText:
                            isEnglish ? 'Front Suspension Mount' : 'サスマウント前',
                        border: OutlineInputBorder(),
                      ),
                      value: settings['rearSusMountFront'].isEmpty
                          ? null
                          : settings['rearSusMountFront'],
                      items: const [
                        DropdownMenuItem(value: 'XB', child: Text('XB')),
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'E', child: Text('E')),
                      ],
                      onChanged: (value) {
                        settings['rearSusMountFront'] = value;
                      },
                    ),
                  ),
                  _buildSettingField(
                    'rearSusMountRear',
                    isEnglish ? 'Rear Suspension Mount' : 'サスマウント後',
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText:
                            isEnglish ? 'Rear Suspension Mount' : 'サスマウント後',
                        border: OutlineInputBorder(),
                      ),
                      value: settings['rearSusMountRear'].isEmpty
                          ? null
                          : settings['rearSusMountRear'],
                      items: const [
                        DropdownMenuItem(value: 'XB', child: Text('XB')),
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'E', child: Text('E')),
                      ],
                      onChanged: (value) {
                        settings['rearSusMountRear'] = value;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildSettingsRow(
                  'rearSusMountFrontShaftPosition',
                  'rearSusMountRearShaftPosition',
                  _buildSettingField(
                    'rearSusMountFrontShaftPosition',
                    isEnglish ? 'Front Shaft Position' : 'サスマウント前シャフト位置',
                    _buildGridSelector(
                      label:
                          isEnglish ? 'Front Shaft Position' : 'サスマウント前シャフト位置',
                      settingKey: 'rearSusMountFrontShaftPosition',
                      size: 150,
                    ),
                  ),
                  _buildSettingField(
                    'rearSusMountRearShaftPosition',
                    'サスマウント後シャフト位置',
                    _buildGridSelector(
                      label: 'サスマウント後シャフト位置',
                      settingKey: 'rearSusMountRearShaftPosition',
                      size: 150,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildSettingsRow(
                  'rearDrive',
                  'rearDifferentialOil',
                  _buildSettingField(
                    'rearDrive',
                    isEnglish ? 'Differential Type' : 'デフ種類',
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Differential Type' : 'デフ種類',
                        border: OutlineInputBorder(),
                      ),
                      value: settings['rearDrive'].isEmpty
                          ? null
                          : settings['rearDrive'],
                      items: const [
                        DropdownMenuItem(value: 'スプール', child: Text('スプール')),
                        DropdownMenuItem(value: 'ギアデフ', child: Text('ギアデフ')),
                        DropdownMenuItem(value: 'ボールデフ', child: Text('ボールデフ')),
                        DropdownMenuItem(value: 'ワンウェイ', child: Text('ワンウェイ')),
                      ],
                      onChanged: (value) {
                        settings['rearDrive'] = value;
                      },
                    ),
                  ),
                  _buildSettingField(
                    'rearDifferentialOil',
                    isEnglish ? 'Differential Oil' : 'デフオイル',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Differential Oil' : 'デフオイル',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: settings['rearDifferentialOil'],
                      onChanged: (value) {
                        settings['rearDifferentialOil'] = value;
                      },
                    ),
                  ),
                ),

                // リアダンパー設定の展開パネル
                _buildSingleSetting(
                  'rearDamperSettings',
                  _buildSettingField(
                    'rearDamperSettings',
                    isEnglish ? 'Rear Damper Settings' : 'リアダンパー設定',
                    _buildExpandablePanel(
                      title: isEnglish ? 'Rear Damper Settings' : 'リアダンパー設定',
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          isEnglish ? 'Damper Offset (mm)' : 'ダンパーオフセット (mm)',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        _buildSettingsRow(
                          'rearDamperOffsetStay',
                          'rearDamperOffsetArm',
                          _buildSettingField(
                            'rearDamperOffsetStay',
                            isEnglish ? 'Stay' : 'ステー',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Stay' : 'ステー (mm)',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDamperOffsetStay']
                                      ?.toString() ??
                                  '0.0',
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                settings['rearDamperOffsetStay'] =
                                    double.tryParse(value) ?? 0.0;
                              },
                            ),
                          ),
                          _buildSettingField(
                            'rearDamperOffsetArm',
                            isEnglish ? 'Arm' : 'サスアーム',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Arm' : 'サスアーム (mm)',
                                border: OutlineInputBorder(),
                              ),
                              initialValue:
                                  settings['rearDamperOffsetArm']?.toString() ??
                                      '0.0',
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                settings['rearDamperOffsetArm'] =
                                    double.tryParse(value) ?? 0.0;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSettingsRow(
                          'rearDumperType',
                          'rearDumperOilSeal',
                          _buildSettingField(
                            'rearDumperType',
                            isEnglish ? 'Damper Type' : 'ダンパータイプ',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText:
                                    isEnglish ? 'Damper Type' : 'ダンパータイプ',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperType'],
                              onChanged: (value) {
                                settings['rearDumperType'] = value;
                              },
                            ),
                          ),
                          _buildSettingField(
                            'rearDumperOilSeal',
                            isEnglish ? 'Oil Seal' : 'オイルシール',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Oil Seal' : 'オイルシール',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperOilSeal'],
                              onChanged: (value) {
                                settings['rearDumperOilSeal'] = value;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSettingsRow(
                          'rearDumperPistonSize',
                          'rearDumperPistonHole',
                          _buildSettingField(
                            'rearDumperPistonSize',
                            isEnglish ? 'Piston Size' : 'ピストンサイズ',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText:
                                    isEnglish ? 'Piston Size' : 'ピストンサイズ',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperPistonSize'],
                              onChanged: (value) {
                                settings['rearDumperPistonSize'] = value;
                              },
                            ),
                          ),
                          _buildSettingField(
                            'rearDumperPistonHole',
                            isEnglish ? 'Piston Hole' : 'ピストン穴数',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Piston Hole' : 'ピストン穴数',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperPistonHole'],
                              onChanged: (value) {
                                settings['rearDumperPistonHole'] = value;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSettingsRow(
                          'rearDumperOilHardness',
                          'rearDumperOilName',
                          _buildSettingField(
                            'rearDumperOilHardness',
                            isEnglish ? 'Oil Hardness' : 'オイル硬度',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Oil Hardness' : 'オイル硬度',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperOilHardness'],
                              onChanged: (value) {
                                settings['rearDumperOilHardness'] = value;
                              },
                            ),
                          ),
                          _buildSettingField(
                            'rearDumperOilName',
                            isEnglish ? 'Oil Name' : 'オイル名',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Oil Name' : 'オイル名',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperOilName'],
                              onChanged: (value) {
                                settings['rearDumperOilName'] = value;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSettingsRow(
                          'rearDumperStroke',
                          'rearDumperAirHole',
                          _buildSettingField(
                            'rearDumperStroke',
                            isEnglish ? 'Stroke' : 'ストローク長',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Stroke' : 'ストローク長',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperStroke'],
                              onChanged: (value) {
                                settings['rearDumperStroke'] = value;
                              },
                            ),
                          ),
                          _buildSettingField(
                            'rearDumperAirHole',
                            isEnglish ? 'Air Hole' : 'エア抜き穴',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Air Hole' : 'エア抜き穴(mm)',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperAirHole'],
                              onChanged: (value) {
                                settings['rearDumperAirHole'] = value;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopDeckSettingsTab() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isEnglish ? 'Top Deck Settings' : 'トップ設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: isEnglish
                      ? 'Upper Deck Screw Position'
                      : 'アッパーデッキスクリューポジション',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['upperDeckScrewPosition'],
                onChanged: (value) {
                  settings['upperDeckScrewPosition'] = value;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText:
                      isEnglish ? 'Upper Deck Flex Type' : 'アッパーデッキフレックスタイプ',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['upperDeckflexType'],
                onChanged: (value) {
                  settings['upperDeckflexType'] = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText:
                      isEnglish ? 'Ballast Front Right (g)' : 'バラスト前右 (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue:
                    settings['ballastFrontRight']?.toString() ?? '0.0',
                onChanged: (value) {
                  settings['ballastFrontRight'] = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText:
                      isEnglish ? 'Ballast Front Left (g)' : 'バラスト前左 (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['ballastFrontLeft']?.toString() ?? '0.0',
                onChanged: (value) {
                  settings['ballastFrontLeft'] = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Ballast Middle (g)' : 'バラスト中央 (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['ballastMiddle']?.toString() ?? '0.0',
                onChanged: (value) {
                  settings['ballastMiddle'] = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText:
                      isEnglish ? 'Ballast Battery (g)' : 'バラストバッテリー (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['ballastBattery']?.toString() ?? '0.0',
                onChanged: (value) {
                  settings['ballastBattery'] = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildExpandablePanel(
          title: 'トップ詳細設定',
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ナックルアームタイプ',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: settings['knucklearmType'],
                    onChanged: (value) {
                      settings['knucklearmType'] = value;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ナックルアームアップライトスペーサー (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['kuncklearmUprightSpacer']?.toString() ??
                            '0.0',
                    onChanged: (value) {
                      settings['kuncklearmUprightSpacer'] =
                          double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ステアリングピボット',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: settings['steeringPivot'],
                    onChanged: (value) {
                      settings['steeringPivot'] = value;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ステアリングスペーサー (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['steeringSpacer']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['steeringSpacer'] =
                          double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'フロントサスペンションアームスペーサー (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['frontSuspensionArmSpacer']?.toString() ??
                            '0.0',
                    onChanged: (value) {
                      settings['frontSuspensionArmSpacer'] =
                          double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'リアサスペンションタイプ',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: settings['rearSuspensionType'],
                    onChanged: (value) {
                      settings['rearSuspensionType'] = value;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'リアサスペンションアームスペーサー (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['rearSuspensionArmSpacer']?.toString() ??
                            '0.0',
                    onChanged: (value) {
                      settings['rearSuspensionArmSpacer'] =
                          double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ロアデッキ厚さ (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['lowerDeckThickness']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['lowerDeckThickness'] =
                          double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ロアデッキ素材',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: settings['lowerDeckMaterial'],
                    onChanged: (value) {
                      settings['lowerDeckMaterial'] = value;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtherSettingsTab() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isEnglish ? 'Other Settings' : 'その他設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          decoration: InputDecoration(
            labelText: isEnglish ? 'Motor' : 'モーター',
            border: OutlineInputBorder(),
          ),
          initialValue: settings['motor'],
          onChanged: (value) {
            settings['motor'] = value;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Spur Gear' : 'スパーギア',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['spurGear'],
                onChanged: (value) {
                  settings['spurGear'] = value;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Pinion Gear' : 'ピニオンギア',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['pinionGear'],
                onChanged: (value) {
                  settings['pinionGear'] = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Battery' : 'バッテリー',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['battery'],
                onChanged: (value) {
                  settings['battery'] = value;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Body' : 'ボディ',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['body'],
                onChanged: (value) {
                  settings['body'] = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Body Weight (g)' : 'ボディ重量 (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['bodyWeight']?.toString() ?? '0.0',
                onChanged: (value) {
                  settings['bodyWeight'] = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: isEnglish
                      ? 'Front Body Mount Hole Position'
                      : 'フロントボディマウントホール位置',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['rearBodyMountHolePosition'],
                onChanged: (value) {
                  settings['rearBodyMountHolePosition'] = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: InputDecoration(
            labelText: isEnglish ? 'Wing' : 'ウイング',
            border: OutlineInputBorder(),
          ),
          initialValue: settings['wing'],
          onChanged: (value) {
            settings['wing'] = value;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Tire' : 'タイヤ',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['tire'],
                onChanged: (value) {
                  settings['tire'] = value;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Wheel' : 'ホイール',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['wheel'],
                onChanged: (value) {
                  settings['wheel'] = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: InputDecoration(
            labelText: isEnglish ? 'Tire Insert' : 'タイヤインサート',
            border: OutlineInputBorder(),
          ),
          initialValue: settings['tireInsert'],
          onChanged: (value) {
            settings['tireInsert'] = value;
          },
        ),
      ],
    );
  }

  // 折り畳みパネルウィジェット
  Widget _buildExpandablePanel(
      {required String title, required List<Widget> children}) {
    return ExpansionTile(
      title: Text(title),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  // 5×5のグリッド選択ウィジェット
  Widget _buildGridSelector({
    required String label,
    required String settingKey,
    double size = 200,
  }) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    // 現在の選択位置を解析（例: "2,3"）
    List<int> position = [2, 2]; // デフォルト位置は中央 / Default position is center
    if (settings[settingKey] != null && settings[settingKey].isNotEmpty) {
      try {
        List<String> parts = settings[settingKey].split(',');
        if (parts.length == 2) {
          position = [int.parse(parts[0]), int.parse(parts[1])];
        }
      } catch (e) {
        // パース失敗時はデフォルト位置
        // Use default position if parsing fails
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
            ),
            itemCount: 25,
            itemBuilder: (context, index) {
              int row = index ~/ 5;
              int col = index % 5;
              bool isSelected = position[0] == row && position[1] == col;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    settings[settingKey] = '$row,$col';
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 設定フィールドを作成するメソッド - タイプに基づいて異なる入力ウィジェットを使用
  Widget _buildSettingField(String key, String label, Widget child) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    // 可視性設定が読み込まれているかチェック
    if (_isVisibilityLoaded) {
      // 該当設定が表示対象かチェック
      final isVisible = _visibilitySettings.settingsVisibility[key] ?? true;

      if (!isVisible) {
        return Container(); // 非表示の場合は空のコンテナを返す
      }
    }

    // 車種固有の設定項目タイプを取得
    Car? car = settingsProvider.getCarById(widget.originalCar.id);
    // carがnullの場合は元の車種情報を使用
    car = car ?? widget.originalCar;

    if (car.settingTypes.containsKey(key)) {
      final settingType = car.settingTypes[key]!;

      // 設定項目のタイプに基づいて異なる入力ウィジェットを返す
      switch (settingType) {
        case 'number':
          return _buildNumberInputField(key, label);
        case 'text':
          return _buildTextInputField(key, label);
        case 'slider':
          return _buildSliderField(key, label);
        case 'select':
        default:
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: child, // ラベルを削除し、子ウィジェットのみを返す
          );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: child, // ラベルを削除し、子ウィジェットのみを返す
    );
  }

  // 数値入力フィールドを作成
  Widget _buildNumberInputField(String key, String label) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintText: label, // labelTextの代わりにhintTextを使用
          suffixText: _getSuffixForSetting(key),
        ),
        onChanged: (value) {
          setState(() {
            if (value.isNotEmpty) {
              try {
                // 数値の場合は数値として保存
                settings[key] = double.parse(value);
              } catch (e) {
                // 解析エラーの場合はテキストとして保存
                settings[key] = value;
              }
            } else {
              // 空の場合はデフォルト値を設定
              settings[key] = 0.0;
            }
          });
        },
        // 初期値の設定
        controller: TextEditingController(
            text: settings.containsKey(key) ? settings[key].toString() : '0'),
      ),
    );
  }

  // テキスト入力フィールドを作成
  Widget _buildTextInputField(String key, String label) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: isEnglish ? 'Enter text' : 'テキストを入力',
            ),
            onChanged: (value) {
              setState(() {
                settings[key] = value;
              });
            },
            controller: TextEditingController(
              text: settings[key] != null ? settings[key].toString() : '',
            ),
          ),
        ],
      ),
    );
  }

  // スライダーフィールドを作成
  Widget _buildSliderField(String key, String label) {
    // 設定値の範囲を定義（設定項目により異なる可能性があるため、ヘルパーメソッドで取得）
    final minValue = _getMinValueForSetting(key);
    final maxValue = _getMaxValueForSetting(key);
    final divisions = _getDivisionsForSetting(key);

    // 現在の値（初期値がなければ中央値を使用）
    double currentValue = 0.0;
    if (settings[key] != null) {
      if (settings[key] is double) {
        currentValue = settings[key];
      } else if (settings[key] is int) {
        currentValue = settings[key].toDouble();
      } else if (settings[key] is String) {
        try {
          currentValue = double.parse(settings[key]);
        } catch (e) {
          currentValue = (minValue + maxValue) / 2;
        }
      }
    } else {
      currentValue = (minValue + maxValue) / 2;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Text(minValue.toString()),
              Expanded(
                child: Slider(
                  min: minValue,
                  max: maxValue,
                  divisions: divisions,
                  value: currentValue.clamp(minValue, maxValue),
                  label: currentValue.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() {
                      settings[key] = value;
                    });
                  },
                ),
              ),
              Text(maxValue.toString()),
            ],
          ),
          Center(
            child: Text(
              '${currentValue.toStringAsFixed(1)}${_getSuffixForSetting(key)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 設定項目に応じた単位を取得するヘルパーメソッド
  String _getSuffixForSetting(String key) {
    if (key.contains('Thickness') ||
        key.contains('Height') ||
        key.contains('Mount') ||
        key.contains('Arm')) {
      return 'mm';
    } else if (key.contains('Angle')) {
      return '°';
    } else if (key.contains('Weight')) {
      return 'g';
    } else {
      return '';
    }
  }

  // 設定項目に応じた最小値を取得するヘルパーメソッド
  double _getMinValueForSetting(String key) {
    if (key.contains('Angle')) {
      return -10.0;
    } else if (key.contains('Height')) {
      return 3.0;
    } else if (key.contains('Weight')) {
      return 0.0;
    } else if (key.contains('Thickness') || key.contains('Arm')) {
      return 0.5;
    } else {
      return 0.0;
    }
  }

  // 設定項目に応じた最大値を取得するヘルパーメソッド
  double _getMaxValueForSetting(String key) {
    if (key.contains('Angle')) {
      return 10.0;
    } else if (key.contains('Height')) {
      return 15.0;
    } else if (key.contains('Weight')) {
      return 300.0;
    } else if (key.contains('Thickness') || key.contains('Arm')) {
      return 5.0;
    } else {
      return 100.0;
    }
  }

  // 設定項目に応じた分割数を取得するヘルパーメソッド
  int _getDivisionsForSetting(String key) {
    if (key.contains('Angle')) {
      return 20;
    } else if (key.contains('Height') || key.contains('Weight')) {
      return 30;
    } else if (key.contains('Thickness') || key.contains('Arm')) {
      return 9; // 0.5単位で調整できるよう
    } else {
      return 10;
    }
  }

  void _saveSetting() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    if (_settingNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isEnglish ? 'Please enter a setting name' : 'セッティング名を入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isEditing && widget.savedSettingId != null) {
      // Update existing setting
      final updatedSetting = SavedSetting(
        id: widget.savedSettingId!,
        name: _settingNameController.text,
        createdAt: DateTime.now(),
        car: widget.originalCar,
        settings: settings,
      );

      await settingsProvider.updateSetting(updatedSetting);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Setting updated' : '設定を更新しました')),
        );
        Navigator.pop(context);
      }
    } else {
      // Add new setting
      await settingsProvider.addSetting(
        _settingNameController.text,
        widget.originalCar,
        settings,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEnglish ? 'Setting saved' : '設定を保存しました')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEnglish ? 'Delete Setting' : '設定の削除'),
          content: Text(isEnglish
              ? 'Are you sure you want to delete this setting? This action cannot be undone.'
              : 'この設定を削除してもよろしいですか？この操作は元に戻せません。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                if (widget.savedSettingId != null) {
                  await settingsProvider.deleteSetting(widget.savedSettingId!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              isEnglish ? 'Setting deleted' : '設定を削除しました')),
                    );
                    Navigator.pop(context);
                  }
                }
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

  void _showVisibilityDialog(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEnglish ? 'Display Options' : '表示オプション'),
          content: Text(isEnglish
              ? 'To configure display options for each setting item, please go to Settings > Display Settings.'
              : '各設定項目の表示設定を構成するには、設定 > 表示設定に移動してください。'),
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
  }

  void _shareSetting() {
    // Implementation for sharing setting
  }

  // 横並びの設定項目を最適化して表示するためのヘルパーメソッド
  Widget _buildSettingsRow(
      String key1, String key2, Widget widget1, Widget widget2) {
    // 可視性設定が読み込まれているかチェック
    if (!_isVisibilityLoaded) {
      return Row(
        children: [
          Expanded(child: widget1),
          const SizedBox(width: 16),
          Expanded(child: widget2),
        ],
      );
    }

    // 各項目の表示状態を取得
    final isVisible1 = _visibilitySettings.settingsVisibility[key1] ?? true;
    final isVisible2 = _visibilitySettings.settingsVisibility[key2] ?? true;

    // 両方非表示の場合は空のコンテナを返す（行を詰める）
    if (!isVisible1 && !isVisible2) {
      return Container();
    }

    // 片方のみが表示される場合、その項目を横いっぱいに表示
    if (!isVisible1) {
      return widget2; // key1が非表示の場合、key2を全幅で表示
    }

    if (!isVisible2) {
      return widget1; // key2が非表示の場合、key1を全幅で表示
    }

    // 両方表示する場合は通常通りRowで並べる
    return Row(
      children: [
        Expanded(child: widget1),
        const SizedBox(width: 16),
        Expanded(child: widget2),
      ],
    );
  }

  // 単一項目の表示/非表示を処理するヘルパーメソッド
  Widget _buildSingleSetting(String key, Widget widget) {
    // 可視性設定が読み込まれていない場合はそのまま表示
    if (!_isVisibilityLoaded) {
      return widget;
    }

    // 表示状態を取得
    final isVisible = _visibilitySettings.settingsVisibility[key] ?? true;

    // 非表示の場合は空のコンテナを返す（行を詰める）
    if (!isVisible) {
      return Container();
    }

    // 表示する場合はウィジェットをそのまま返す
    return widget;
  }
}
