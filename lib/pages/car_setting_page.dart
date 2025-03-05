import 'package:flutter/material.dart';
import '../models/car.dart';

class CarSettingPage extends StatefulWidget {
  final Car originalCar;

  const CarSettingPage({super.key, required this.originalCar});

  @override
  State<CarSettingPage> createState() => _CarSettingPageState();
}

class _CarSettingPageState extends State<CarSettingPage> {
  late String carName;
  late Map<String, dynamic> settings;

  @override
  void initState() {
    super.initState();
    carName = widget.originalCar.name;
    // 初期設定値を設定
    settings = widget.originalCar.settings ??
        {
          // 基本情報
          'date': DateTime.now(),
          'track': '',
          'surface': '',
          'airTemp': 0,
          'humidity': 0,
          'trackTemp': 0,
          'condition': '',

          // フロント設定
          'frontCamber': 0.0,
          'frontRideHeight': 0.0,
          'frontDamperPosition': 1,
          'frontSpring': '',
          'frontToe': 0.0,

          // フロント詳細設定
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

          //フロントダンパー設定
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$carName セッティング'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const Divider(height: 32),
              _buildFrontSection(),
              const Divider(height: 32),
              _buildRearSection(),
              const Divider(height: 32),
              _buildTopSection(),
              const Divider(height: 32),
              _buildOtherSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('基本情報',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: '日付',
                  border: OutlineInputBorder(),
                ),
                initialValue:
                    '${settings['date'].year}/${settings['date'].month}/${settings['date'].day}',
                readOnly: true,
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: settings['date'],
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      settings['date'] = picked;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'トラック',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['track'],
                onChanged: (value) {
                  settings['track'] = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '路面',
                  border: OutlineInputBorder(),
                ),
                value: settings['surface'].isEmpty ? null : settings['surface'],
                items: const [
                  DropdownMenuItem(value: 'アスファルト', child: Text('アスファルト')),
                  DropdownMenuItem(value: 'カーペット', child: Text('カーペット')),
                ],
                onChanged: (value) {
                  setState(() {
                    settings['surface'] = value!;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'コンディション',
                  border: OutlineInputBorder(),
                ),
                value: settings['condition'].isEmpty
                    ? null
                    : settings['condition'],
                items: const [
                  DropdownMenuItem(value: '非常に良い', child: Text('非常に良い')),
                  DropdownMenuItem(value: '良い', child: Text('良い')),
                  DropdownMenuItem(value: '少し良い', child: Text('少し良い')),
                  DropdownMenuItem(value: '普通', child: Text('普通')),
                  DropdownMenuItem(value: '少し悪い', child: Text('少し悪い')),
                  DropdownMenuItem(value: '悪い', child: Text('悪い')),
                  DropdownMenuItem(value: '非常に悪い', child: Text('非常に悪い')),
                ],
                onChanged: (value) {
                  setState(() {
                    settings['condition'] = value!;
                  });
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
                  labelText: '気温 (°C)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                initialValue: settings['airTemp'].toString(),
                onChanged: (value) {
                  settings['airTemp'] = int.tryParse(value) ?? 0;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: '湿度 (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                initialValue: settings['humidity'].toString(),
                onChanged: (value) {
                  settings['humidity'] = int.tryParse(value) ?? 0;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: '路面温度 (°C)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                initialValue: settings['trackTemp'].toString(),
                onChanged: (value) {
                  settings['trackTemp'] = int.tryParse(value) ?? 0;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFrontSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('フロント設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'キャンバー角 (°)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['frontCamber'].toString(),
                onChanged: (value) {
                  settings['frontCamber'] = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'トー角 (mm)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['frontToe'].toString(),
                onChanged: (value) {
                  settings['frontToe'] = double.tryParse(value) ?? 0.0;
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
                  labelText: 'キャスター角 (°)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['frontCasterAngle'].toString(),
                onChanged: (value) {
                  settings['frontCasterAngle'] = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: '車高 (mm)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['frontRideHeight'].toString(),
                onChanged: (value) {
                  settings['frontRideHeight'] = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('ダンパーポジション: '),
            const SizedBox(width: 8),
            const Text('内側'),
            const SizedBox(width: 8),
            ToggleButtons(
              isSelected: List.generate(
                3,
                (index) => settings['frontDamperPosition'] == index + 1,
              ),
              onPressed: (index) {
                setState(() {
                  settings['frontDamperPosition'] = index + 1;
                });
              },
              children: const [
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('1')),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('2')),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('3')),
              ],
            ),
            const SizedBox(width: 12),
            const Text('外側'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'ダンパーオイル',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['frontDamperOil'],
                onChanged: (value) {
                  settings['frontDamperOil'] = value;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'スプリング',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['frontSpring'],
                onChanged: (value) {
                  settings['frontSpring'] = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'スタビライザー',
            border: OutlineInputBorder(),
          ),
          initialValue: settings['frontStabilizer'],
          onChanged: (value) {
            settings['frontStabilizer'] = value;
          },
        ),
        const SizedBox(height: 16),
        _buildExpandablePanel(
          title: '詳細設定',
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'アッパーアームスペーサー',
                    style: TextStyle(fontSize: 12),
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
                      labelText: '内側 (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['frontUpperArmSpacerInside']?.toString() ??
                            '0.0',
                    onChanged: (value) {
                      settings['frontUpperArmSpacerInside'] =
                          double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: '外側 (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['frontUpperArmSpacerOutside']?.toString() ??
                            '0.0',
                    onChanged: (value) {
                      settings['frontUpperArmSpacerOutside'] =
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
                      labelText: 'ロアアーム スペーサー (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['frontLowerArmSpacer']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['frontLowerArmSpacer'] =
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
                      labelText: 'ホイールハブ (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['frontWheelHub']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['frontWheelHub'] = double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ホイールハブスペーサー (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['frontWheelHubSpacer']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['frontWheelHubSpacer'] =
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
                      labelText: 'ドループ (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue: settings['frontDroop']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['frontDroop'] = double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                        child: Text('高')),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('低')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
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
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildGridSelector(
                    label: 'サスマウント前シャフト位置',
                    settingKey: 'frontSusMountFrontShaftPosition',
                    size: 150,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGridSelector(
                    label: 'サスマウント後シャフト位置',
                    settingKey: 'frontSusMountRearShaftPosition',
                    size: 150,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
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
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('ダンパーポジション: '),
                const SizedBox(width: 8),
                const Text('内'),
                const SizedBox(width: 8),
                ToggleButtons(
                  isSelected: [
                    settings['frontDumperPosition'] == 1,
                    settings['frontDumperPosition'] == 2,
                    settings['frontDumperPosition'] == 3,
                  ],
                  onPressed: (index) {
                    setState(() {
                      settings['frontDumperPosition'] = index + 1;
                    });
                  },
                  children: const [
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('1')),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('2')),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('3')),
                  ],
                ),
                const SizedBox(width: 12),
                const Text('外'),
              ],
            ),
            const SizedBox(height: 16),
            _buildExpandablePanel(
              title: 'フロントダンパー設定',
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'ダンパーオフセット (mm)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ステー (mm)',
                          border: OutlineInputBorder(),
                        ),
                        initialValue:
                            settings['frontDamperOffsetStay']?.toString() ??
                                '0.0',
                        onChanged: (value) {
                          settings['frontDamperOffsetStay'] =
                              double.tryParse(value) ?? 0.0;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'サスアーム (mm)',
                          border: OutlineInputBorder(),
                        ),
                        initialValue:
                            settings['frontDamperOffsetArm']?.toString() ??
                                '0.0',
                        onChanged: (value) {
                          settings['frontDamperOffsetArm'] =
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
                          labelText: 'ダンパータイプ',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: settings['frontDumperType'],
                        onChanged: (value) {
                          settings['frontDumperType'] = value;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
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
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRearSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('リア設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'キャンバー角 (°)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['rearCamber'].toString(),
                onChanged: (value) {
                  settings['rearCamber'] = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'トー角 (mm)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['rearToe']?.toString() ?? '0.0',
                onChanged: (value) {
                  settings['rearToe'] = double.tryParse(value) ?? 0.0;
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
                  labelText: '車高 (mm)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings['rearRideHeight'].toString(),
                onChanged: (value) {
                  settings['rearRideHeight'] = double.tryParse(value) ?? 0.0;
                },
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('ダンパーポジション: '),
            const SizedBox(width: 8),
            const Text('内側'),
            const SizedBox(width: 8),
            ToggleButtons(
              isSelected: List.generate(
                3,
                (index) => settings['rearDamperPosition'] == index + 1,
              ),
              onPressed: (index) {
                setState(() {
                  settings['rearDamperPosition'] = index + 1;
                });
              },
              children: const [
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('1')),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('2')),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('3')),
              ],
            ),
            const SizedBox(width: 12),
            const Text('外側'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'ダンパーオイル',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['rearDamperOil'],
                onChanged: (value) {
                  settings['rearDamperOil'] = value;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'スプリング',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['rearSpring'],
                onChanged: (value) {
                  settings['rearSpring'] = value;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'スタビライザー',
            border: OutlineInputBorder(),
          ),
          initialValue: settings['rearStabilizer'],
          onChanged: (value) {
            settings['rearStabilizer'] = value;
          },
        ),
        const SizedBox(height: 16),
        _buildExpandablePanel(
          title: '詳細設定',
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'アッパーアームスペーサー',
                    style: TextStyle(fontSize: 12),
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
                      labelText: '内側 (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['rearUpperArmSpacerInside']?.toString() ??
                            '0.0',
                    onChanged: (value) {
                      settings['rearUpperArmSpacerInside'] =
                          double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: '外側 (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['rearUpperArmSpacerOutside']?.toString() ??
                            '0.0',
                    onChanged: (value) {
                      settings['rearUpperArmSpacerOutside'] =
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
                      labelText: 'ロアアーム スペーサー (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['rearLowerArmSpacer']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['rearLowerArmSpacer'] =
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
                      labelText: 'ホイールハブ (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue: settings['rearWheelHub']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['rearWheelHub'] = double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'ホイールハブスペーサー (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue:
                        settings['rearWheelHubSpacer']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['rearWheelHubSpacer'] =
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
                      labelText: 'ドループ (mm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue: settings['rearDroop']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['rearDroop'] = double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                        child: Text('高')),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('低')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'サスマウント前',
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
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'サスマウント後',
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
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildGridSelector(
                    label: 'サスマウント前シャフト位置',
                    settingKey: 'rearSusMountFrontShaftPosition',
                    size: 150,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGridSelector(
                    label: 'サスマウント後シャフト位置',
                    settingKey: 'rearSusMountRearShaftPosition',
                    size: 150,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'デフ種類',
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
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'デフオイル',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: settings['rearDifferentialOil'],
                    onChanged: (value) {
                      settings['rearDifferentialOil'] = value;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('ダンパーポジション：'),
                const SizedBox(width: 8),
                const Text('内'),
                const SizedBox(width: 8),
                ToggleButtons(
                  isSelected: [
                    settings['rearDumperPosition'] == 1,
                    settings['rearDumperPosition'] == 2,
                    settings['rearDumperPosition'] == 3,
                  ],
                  onPressed: (index) {
                    setState(() {
                      settings['rearDumperPosition'] = index + 1;
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('1'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('2'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('3'),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text('外'),
              ],
            ),
            const SizedBox(height: 16),
            _buildExpandablePanel(
              title: 'リアダンパー設定',
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'ダンパーオフセット (mm)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'ステー (mm)',
                          border: OutlineInputBorder(),
                        ),
                        initialValue:
                            settings['rearDamperOffsetStay']?.toString() ??
                                '0.0',
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'サスアーム (mm)',
                      border: OutlineInputBorder(),
                    ),
                    initialValue:
                        settings['rearDamperOffsetArm']?.toString() ?? '0.0',
                    onChanged: (value) {
                      settings['rearDamperOffsetArm'] =
                          double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
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
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('トップ設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'アッパーデッキスクリューポジション',
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
                decoration: const InputDecoration(
                  labelText: 'アッパーデッキフレックスタイプ',
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
                decoration: const InputDecoration(
                  labelText: 'バラスト前右 (g)',
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
                decoration: const InputDecoration(
                  labelText: 'バラスト前左 (g)',
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
                decoration: const InputDecoration(
                  labelText: 'バラスト中央 (g)',
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
                decoration: const InputDecoration(
                  labelText: 'バラストバッテリー (g)',
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

  Widget _buildOtherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('その他設定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'モーター',
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
                decoration: const InputDecoration(
                  labelText: 'スパーギア',
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
                decoration: const InputDecoration(
                  labelText: 'ピニオンギア',
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
                decoration: const InputDecoration(
                  labelText: 'バッテリー',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['battery'],
                onChanged: (value) {
                  settings['battery'] = value;
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
                  labelText: 'ボディ',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['body'],
                onChanged: (value) {
                  settings['body'] = value;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'ボディ重量 (g)',
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
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'フロントボディマウントホール位置',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings['frontBodyMountHolePosition'],
                onChanged: (value) {
                  settings['frontBodyMountHolePosition'] = value;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'リアボディマウントホール位置',
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
          decoration: const InputDecoration(
            labelText: 'ウイング',
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
                decoration: const InputDecoration(
                  labelText: 'タイヤ',
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
                decoration: const InputDecoration(
                  labelText: 'ホイール',
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
          decoration: const InputDecoration(
            labelText: 'タイヤインサート',
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
    // 現在の選択位置を解析（例: "2,3"）
    List<int> position = [2, 2]; // デフォルト位置は中央
    if (settings[settingKey] != null && settings[settingKey].isNotEmpty) {
      try {
        List<String> parts = settings[settingKey].split(',');
        if (parts.length == 2) {
          position = [int.parse(parts[0]), int.parse(parts[1])];
        }
      } catch (e) {
        // パース失敗時はデフォルト位置
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

  void _saveSettings() {
    // セッティングを保存
    widget.originalCar.settings = settings;

    // 保存完了メッセージ
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('セッティングを保存しました')),
    );

    // 前の画面に戻る
    Navigator.pop(context);
  }
}
