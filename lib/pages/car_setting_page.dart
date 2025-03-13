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
                  const SizedBox(height: 16),
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
                  child: _buildBasicInfoTab(),
                ),
                // Front Tab
                SingleChildScrollView(
                  child: _buildFrontSettingsTab(),
                ),
                // Rear Tab
                SingleChildScrollView(
                  child: _buildRearSettingsTab(),
                ),
                // Top Deck Tab
                SingleChildScrollView(
                  child: _buildTopDeckSettingsTab(),
                ),
                // Other Tab
                SingleChildScrollView(
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
        Row(
          children: [
            Expanded(
              child: _buildSettingField(
                'date',
                isEnglish ? 'Date' : '日付',
                TextFormField(
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Date' : '日付',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: settings['date'] != null
                      ? DateTime.parse(settings['date'])
                          .toString()
                          .split(' ')[0]
                          .replaceAll('-', '/')
                      : DateTime.now().toString().split(' ')[0],
                  onChanged: (value) {
                    settings['date'] =
                        DateTime.parse(value.replaceAll('/', '-'))
                            .toIso8601String();
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingField(
                'track',
                isEnglish ? 'Track' : 'トラック',
                TextFormField(
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Track' : 'トラック',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: settings['track'],
                  onChanged: (value) {
                    settings['track'] = value;
                  },
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildSettingField(
                'surface',
                isEnglish ? 'Surface' : '路面',
                TextFormField(
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Surface' : '路面',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: settings['surface'],
                  onChanged: (value) {
                    settings['surface'] = value;
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingField(
                'condition',
                isEnglish ? 'Condition' : 'コンディション',
                TextFormField(
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Condition' : 'コンディション',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: settings['condition'],
                  onChanged: (value) {
                    settings['condition'] = value;
                  },
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildSettingField(
                'airTemp',
                isEnglish ? 'Air Temperature' : '気温',
                TextFormField(
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Air Temperature (℃)' : '気温 (℃)',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: settings['airTemp'].toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    settings['airTemp'] = int.tryParse(value) ?? 0;
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingField(
                'humidity',
                isEnglish ? 'Humidity' : '湿度',
                TextFormField(
                  decoration: InputDecoration(
                    labelText: isEnglish ? 'Humidity (%)' : '湿度 (%)',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: settings['humidity'].toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    settings['humidity'] = int.tryParse(value) ?? 0;
                  },
                ),
              ),
            ),
          ],
        ),
        _buildSettingField(
          'trackTemp',
          isEnglish ? 'Track Temperature' : '路面温度',
          TextFormField(
            decoration: InputDecoration(
              labelText: isEnglish ? 'Track Temperature (℃)' : '路面温度 (℃)',
              border: OutlineInputBorder(),
            ),
            initialValue: settings['trackTemp'].toString(),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              settings['trackTemp'] = int.tryParse(value) ?? 0;
            },
          ),
        ),
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
        Row(
          children: [
            Expanded(
              child: _buildSettingField(
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingField(
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
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildSettingField(
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingField(
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
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildSettingField(
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingField(
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
          ],
        ),
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

        // 詳細設定の展開パネル
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
              Row(
                children: [
                  Expanded(
                    child: _buildSettingField(
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSettingField(
                      'frontUpperArmSpacerOutside',
                      isEnglish ? 'Outside' : '外側',
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: isEnglish ? 'Outside (mm)' : '外側 (mm)',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: settings['frontUpperArmSpacerOutside']
                                ?.toString() ??
                            '0.0',
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          settings['frontUpperArmSpacerOutside'] =
                              double.tryParse(value) ?? 0.0;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSettingField(
                      'frontLowerArmSpacer',
                      'ロアアームスペーサー',
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ロアアームスペーサー (mm)',
                          border: OutlineInputBorder(),
                        ),
                        initialValue:
                            settings['frontLowerArmSpacer']?.toString() ??
                                '0.0',
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          settings['frontLowerArmSpacer'] =
                              double.tryParse(value) ?? 0.0;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSettingField(
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSettingField(
                      'frontWheelHubSpacer',
                      'ホイールハブスペーサー',
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ホイールハブスペーサー (mm)',
                          border: OutlineInputBorder(),
                        ),
                        initialValue:
                            settings['frontWheelHubSpacer']?.toString() ??
                                '0.0',
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          settings['frontWheelHubSpacer'] =
                              double.tryParse(value) ?? 0.0;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSettingField(
                      'frontDroop',
                      'ドループ',
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ドループ (mm)',
                          border: OutlineInputBorder(),
                        ),
                        initialValue:
                            settings['frontDroop']?.toString() ?? '0.0',
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          settings['frontDroop'] =
                              double.tryParse(value) ?? 0.0;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSettingField(
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSettingField(
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
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSettingField(
                      'frontSusMountFrontShaftPosition',
                      'サスマウント前シャフト位置',
                      _buildGridSelector(
                        label: 'サスマウント前シャフト位置',
                        settingKey: 'frontSusMountFrontShaftPosition',
                        size: 150,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSettingField(
                      'frontSusMountRearShaftPosition',
                      'サスマウント後シャフト位置',
                      _buildGridSelector(
                        label: 'サスマウント後シャフト位置',
                        settingKey: 'frontSusMountRearShaftPosition',
                        size: 150,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSettingField(
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
                          DropdownMenuItem(
                              value: 'ボールデフ', child: Text('ボールデフ')),
                          DropdownMenuItem(
                              value: 'ワンウェイ', child: Text('ワンウェイ')),
                        ],
                        onChanged: (value) {
                          settings['frontDrive'] = value;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSettingField(
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
                ],
              ),

              // フロントダンパー設定の展開パネル
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
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
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
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
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
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
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
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
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
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
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
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
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
                  ],
                ),
              ),
            ],
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
        Row(
          children: [
            Expanded(
              child: _buildSettingField(
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingField(
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
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildSettingField(
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingField(
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
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildSettingField(
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSettingField(
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
          ],
        ),

        // 詳細設定の展開パネル
        _buildSettingField(
          'rearDetails',
          isEnglish ? 'Details Settings' : '詳細設定',
          _buildExpandablePanel(
            title: isEnglish ? 'Details Settings' : '詳細設定',
            children: [
              const SizedBox(height: 8),
              Text(
                'アッパーアームスペーサー',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSettingField(
                      'rearUpperArmSpacerInside',
                      '内側',
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '内側 (mm)',
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSettingField(
                      'rearUpperArmSpacerOutside',
                      '外側',
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: '外側 (mm)',
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
                ],
              ),

              // リアダンパー設定の展開パネル
              _buildSettingField(
                'rearDamperSettings',
                'リアダンパー設定',
                _buildExpandablePanel(
                  title: 'リアダンパー設定',
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'ダンパーオフセット (mm)',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
                            'rearDamperOffsetStay',
                            'ステー',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ステー (mm)',
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
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
                            'rearDamperOffsetArm',
                            'サスアーム',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'サスアーム (mm)',
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
                            'rearDumperType',
                            'ダンパータイプ',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ダンパータイプ',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperType'],
                              onChanged: (value) {
                                settings['rearDumperType'] = value;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
                            'rearDumperOilSeal',
                            'オイルシール',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'オイルシール',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperOilSeal'],
                              onChanged: (value) {
                                settings['rearDumperOilSeal'] = value;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
                            'rearDumperPistonSize',
                            'ピストンサイズ',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ピストンサイズ',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperPistonSize'],
                              onChanged: (value) {
                                settings['rearDumperPistonSize'] = value;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
                            'rearDumperPistonHole',
                            'ピストン穴数',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ピストン穴数',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperPistonHole'],
                              onChanged: (value) {
                                settings['rearDumperPistonHole'] = value;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
                            'rearDumperOilHardness',
                            'オイル硬度',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'オイル硬度',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperOilHardness'],
                              onChanged: (value) {
                                settings['rearDumperOilHardness'] = value;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
                            'rearDumperOilName',
                            'オイル名',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'オイル名',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperOilName'],
                              onChanged: (value) {
                                settings['rearDumperOilName'] = value;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
                            'rearDumperStroke',
                            'ストローク長',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ストローク長',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['rearDumperStroke'],
                              onChanged: (value) {
                                settings['rearDumperStroke'] = value;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
                            'rearDumperAirHole',
                            'エア抜き穴',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'エア抜き穴(mm)',
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
                  ],
                ),
              ),
            ],
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

  // メソッドのコメントを英語と日本語両方で提供
  // Method to create a widget, checking if it should be displayed according to visibility settings
  // ウィジェットを作成するメソッドで、表示・非表示の設定をチェックします
  Widget _buildSettingField(String key, String label, Widget child) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    // Only check if visibility settings are loaded
    // 表示設定が読み込まれている場合のみチェックする
    if (_isVisibilityLoaded) {
      // Check visibility for this setting
      // 該当設定の表示・非表示をチェック
      final isVisible = _visibilitySettings.settingsVisibility[key] ?? true;

      // Return empty container if not visible
      // 非表示の場合は空のコンテナを返す
      if (!isVisible) {
        return Container();
      }
    }

    // Display the item as normal if visible
    // 表示する場合は通常通り項目を表示
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8.0),
          child,
        ],
      ),
    );
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
}
