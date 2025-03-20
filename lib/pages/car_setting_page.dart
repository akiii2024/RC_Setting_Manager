import 'package:flutter/material.dart';
import '../models/car.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../models/saved_setting.dart';
import '../models/visibility_settings.dart';
import '../data/car_settings_definitions.dart';
import '../models/car_setting_definition.dart';

class CarSettingPage extends StatefulWidget {
  final Car originalCar;
  final Map<String, dynamic>? savedSettings;
  final String? savedSettingId;
  final String? settingName;

  const CarSettingPage({
    Key? key,
    required this.originalCar,
    this.savedSettings,
    this.savedSettingId,
    this.settingName,
  }) : super(key: key);

  @override
  State<CarSettingPage> createState() => _CarSettingPageState();
}

class _CarSettingPageState extends State<CarSettingPage> {
  late String carName;
  late Map<String, dynamic> settings;
  bool _isLoading = true;
  final TextEditingController _settingNameController = TextEditingController();
  bool _isEditing = false;
  CarSettingDefinition? _carSettingDefinition;

  @override
  void initState() {
    super.initState();
    carName = widget.originalCar.name;
    print('Car ID: ${widget.originalCar.id}'); // デバッグ用ログ
    _carSettingDefinition = getCarSettingDefinition(widget.originalCar.id);
    print('Car Setting Definition: $_carSettingDefinition'); // デバッグ用ログ

    // 既存の設定を使用するか、新しい設定を作成
    if (widget.savedSettings != null) {
      settings = Map<String, dynamic>.from(widget.savedSettings!);
      _isEditing = widget.savedSettingId != null;
      if (widget.settingName != null) {
        _settingNameController.text = widget.settingName!;
      }
    } else {
      // デフォルト設定を作成
      settings = {};
      if (_carSettingDefinition != null) {
        for (var setting in _carSettingDefinition!.availableSettings) {
          settings[setting.key] = _getDefaultValueForType(setting);
        }
      }
    }

    _initializeSettings();
  }

  // 設定項目の型に応じたデフォルト値を返す
  dynamic _getDefaultValueForType(SettingItem setting) {
    switch (setting.type) {
      case 'number':
        return setting.constraints['default'] ?? 0.0;
      case 'text':
        return '';
      case 'select':
        return setting.options?.first;
      case 'slider':
        return setting.constraints['min'] ?? 0.0;
      default:
        return null;
    }
  }

  Future<void> _initializeSettings() async {
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? (isEnglish ? 'Edit Setting' : 'セッティング編集')
            : (isEnglish ? 'New Setting' : '新規セッティング')),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSetting,
            tooltip: _isEditing
                ? (isEnglish ? 'Update' : '更新')
                : (isEnglish ? 'Save' : '保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Setting name input
            TextField(
              controller: _settingNameController,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Setting Name' : 'セッティング名',
                hintText: isEnglish ? 'e.g. Race Setup 1' : '例：レースセットアップ1',
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
        tooltip: _isEditing
            ? (isEnglish ? 'Update' : '更新')
            : (isEnglish ? 'Save' : '保存'),
        child: const Icon(Icons.save),
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

  Widget _buildSettingTabs(BuildContext context) {
    if (_carSettingDefinition == null) {
      return const Center(child: Text('車種の設定定義が見つかりません'));
    }

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    // カテゴリーごとに設定項目をグループ化
    final categories = {
      'basic': isEnglish ? 'Basic' : '基本',
      'front': isEnglish ? 'Front' : 'フロント',
      'rear': isEnglish ? 'Rear' : 'リア',
      'top': isEnglish ? 'Top Deck' : 'トップデッキ',
      'other': isEnglish ? 'Other' : 'その他',
    };

    return DefaultTabController(
      length: categories.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: categories.values.map((name) => Tab(text: name)).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: categories.keys.map((category) {
                // TRF420Xのフロントタブの場合、専用のビルダーを使用
                if (category == 'front' && widget.originalCar.id == 'trf420x') {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildFrontSettingsTabForTRF420X(),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildCategorySettings(category),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySettings(String category) {
    final categorySettings = _carSettingDefinition!.availableSettings
        .where((setting) => setting.category == category)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categorySettings.map((setting) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildSettingField(setting),
        );
      }).toList(),
    );
  }

  Widget _buildSettingField(SettingItem setting) {
    switch (setting.type) {
      case 'number':
        return _buildNumberField(setting);
      case 'text':
        return _buildTextField(setting);
      case 'select':
        return _buildSelectField(setting);
      case 'slider':
        return _buildSliderField(setting);
      default:
        return Container();
    }
  }

  Widget _buildNumberField(SettingItem setting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(setting.label),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixText: setting.unit,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          initialValue: settings[setting.key]?.toString() ?? '0',
          onChanged: (value) {
            setState(() {
              settings[setting.key] = double.tryParse(value) ?? 0.0;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTextField(SettingItem setting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(setting.label),
        const SizedBox(height: 8),
        TextFormField(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          initialValue: settings[setting.key] ?? '',
          onChanged: (value) {
            setState(() {
              settings[setting.key] = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSelectField(SettingItem setting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(setting.label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          value: settings[setting.key],
          items: setting.options?.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              settings[setting.key] = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSliderField(SettingItem setting) {
    final min = setting.constraints['min'] as double? ?? 0.0;
    final max = setting.constraints['max'] as double? ?? 100.0;
    final divisions = setting.constraints['divisions'] as int? ?? 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(setting.label),
        Row(
          children: [
            Text(min.toString()),
            Expanded(
              child: Slider(
                min: min,
                max: max,
                divisions: divisions,
                value: (settings[setting.key] ?? min).toDouble(),
                label: settings[setting.key]?.toString(),
                onChanged: (value) {
                  setState(() {
                    settings[setting.key] = value;
                  });
                },
              ),
            ),
            Text(max.toString()),
          ],
        ),
        Center(
          child: Text(
            '${settings[setting.key]?.toStringAsFixed(1)}${setting.unit ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // TRF420X用のフロント設定タブを構築するメソッド
  Widget _buildFrontSettingsTabForTRF420X() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isEnglish ? 'Front Settings' : 'フロント設定',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // キャンバー角と車高の行
        _buildTRF420XSettingsRow(
          _buildTRF420XSettingField(
            'frontCamber',
            isEnglish ? 'Camber Angle' : 'キャンバー角',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Camber Angle' : 'キャンバー角',
                border: const OutlineInputBorder(),
                suffixText: '°',
              ),
              initialValue: settings['frontCamber']?.toString() ?? '0.0',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  settings['frontCamber'] = double.tryParse(value) ?? 0.0;
                });
              },
            ),
          ),
          _buildTRF420XSettingField(
            'frontRideHeight',
            isEnglish ? 'Ride Height' : '車高',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Ride Height' : '車高',
                border: const OutlineInputBorder(),
                suffixText: 'mm',
              ),
              initialValue: settings['frontRideHeight']?.toString() ?? '0.0',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  settings['frontRideHeight'] = double.tryParse(value) ?? 0.0;
                });
              },
            ),
          ),
        ),

        // ダンパーポジションとスプリングの行
        _buildTRF420XSettingsRow(
          _buildTRF420XSettingField(
            'frontDamperPosition',
            isEnglish ? 'Damper Position' : 'ダンパーポジション',
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Damper Position' : 'ダンパーポジション',
                border: const OutlineInputBorder(),
              ),
              value: settings['frontDamperPosition'] ?? 1,
              items: List.generate(5, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}'),
                );
              }),
              onChanged: (value) {
                setState(() {
                  settings['frontDamperPosition'] = value;
                });
              },
            ),
          ),
          _buildTRF420XSettingField(
            'frontSpring',
            isEnglish ? 'Spring' : 'スプリング',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Spring' : 'スプリング',
                border: const OutlineInputBorder(),
              ),
              initialValue: settings['frontSpring'] ?? '',
              onChanged: (value) {
                setState(() {
                  settings['frontSpring'] = value;
                });
              },
            ),
          ),
        ),

        // トー角とスタビライザーの行
        _buildTRF420XSettingsRow(
          _buildTRF420XSettingField(
            'frontToe',
            isEnglish ? 'Toe Angle' : 'トー角',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Toe Angle' : 'トー角',
                border: const OutlineInputBorder(),
                suffixText: '°',
              ),
              initialValue: settings['frontToe']?.toString() ?? '0.0',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  settings['frontToe'] = double.tryParse(value) ?? 0.0;
                });
              },
            ),
          ),
          _buildTRF420XSettingField(
            'frontStabilizer',
            isEnglish ? 'Stabilizer' : 'スタビライザー',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Stabilizer' : 'スタビライザー',
                border: const OutlineInputBorder(),
              ),
              initialValue: settings['frontStabilizer'] ?? '',
              onChanged: (value) {
                setState(() {
                  settings['frontStabilizer'] = value;
                });
              },
            ),
          ),
        ),

        // キャスター角（単独項目）
        _buildTRF420XSingleSetting(
          _buildTRF420XSettingField(
            'frontCasterAngle',
            isEnglish ? 'Caster Angle' : 'キャスター角',
            TextFormField(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Caster Angle' : 'キャスター角',
                border: const OutlineInputBorder(),
                suffixText: '°',
              ),
              initialValue: settings['frontCasterAngle']?.toString() ?? '0.0',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  settings['frontCasterAngle'] = double.tryParse(value) ?? 0.0;
                });
              },
            ),
          ),
        ),

        // 詳細設定の展開パネル
        _buildTRF420XSingleSetting(
          _buildTRF420XSettingField(
            'frontDetails',
            isEnglish ? 'Detailed Settings' : '詳細設定',
            _buildTRF420XExpandablePanel(
              title: isEnglish ? 'Detailed Settings' : '詳細設定',
              children: [
                const SizedBox(height: 8),
                Text(
                  isEnglish ? 'Upper Arm Spacer' : 'アッパーアームスペーサー',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),

                // 内側と外側のスペーサー設定
                _buildTRF420XSettingsRow(
                  _buildTRF420XSettingField(
                    'frontUpperArmSpacerInside',
                    isEnglish ? 'Inside' : '内側',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Inside (mm)' : '内側 (mm)',
                        border: const OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['frontUpperArmSpacerInside']?.toString() ??
                              '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          settings['frontUpperArmSpacerInside'] =
                              double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                  _buildTRF420XSettingField(
                    'frontUpperArmSpacerOutside',
                    isEnglish ? 'Outside' : '外側',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Outside (mm)' : '外側 (mm)',
                        border: const OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['frontUpperArmSpacerOutside']?.toString() ??
                              '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          settings['frontUpperArmSpacerOutside'] =
                              double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ロアアームスペーサー（単独項目）
                _buildTRF420XSingleSetting(
                  _buildTRF420XSettingField(
                    'frontLowerArmSpacer',
                    isEnglish ? 'Lower Arm Spacer' : 'ロアアームスペーサー',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText:
                            isEnglish ? 'Lower Arm Spacer' : 'ロアアームスペーサー (mm)',
                        border: const OutlineInputBorder(),
                      ),
                      initialValue:
                          settings['frontLowerArmSpacer']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          settings['frontLowerArmSpacer'] =
                              double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ホイールハブ関連設定
                _buildTRF420XSettingsRow(
                  _buildTRF420XSettingField(
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
                        setState(() {
                          settings['frontWheelHub'] =
                              double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                  _buildTRF420XSettingField(
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
                        setState(() {
                          settings['frontWheelHubSpacer'] =
                              double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ドループ設定（単独項目）
                _buildTRF420XSingleSetting(
                  _buildTRF420XSettingField(
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
                        setState(() {
                          settings['frontDroop'] =
                              double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // デフ位置設定（単独項目）
                _buildTRF420XSingleSetting(
                  _buildTRF420XSettingField(
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
                _buildTRF420XSettingsRow(
                  _buildTRF420XSettingField(
                    'frontSusMountFront',
                    'サスマウント前',
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'サスマウント前',
                        border: OutlineInputBorder(),
                      ),
                      value: settings['frontSusMountFront'] == null ||
                              settings['frontSusMountFront'].toString().isEmpty
                          ? null
                          : settings['frontSusMountFront'],
                      items: const [
                        DropdownMenuItem(value: 'XB', child: Text('XB')),
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'E', child: Text('E')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          settings['frontSusMountFront'] = value;
                        });
                      },
                    ),
                  ),
                  _buildTRF420XSettingField(
                    'frontSusMountRear',
                    'サスマウント後',
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'サスマウント後',
                        border: OutlineInputBorder(),
                      ),
                      value: settings['frontSusMountRear'] == null ||
                              settings['frontSusMountRear'].toString().isEmpty
                          ? null
                          : settings['frontSusMountRear'],
                      items: const [
                        DropdownMenuItem(value: 'XB', child: Text('XB')),
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'E', child: Text('E')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          settings['frontSusMountRear'] = value;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // サスマウントシャフト位置設定
                _buildTRF420XSettingsRow(
                  _buildTRF420XSettingField(
                    'frontSusMountFrontShaftPosition',
                    'サスマウント前シャフト位置',
                    _buildTRF420XGridSelector(
                      label: 'サスマウント前シャフト位置',
                      settingKey: 'frontSusMountFrontShaftPosition',
                      size: 150,
                    ),
                  ),
                  _buildTRF420XSettingField(
                    'frontSusMountRearShaftPosition',
                    'サスマウント後シャフト位置',
                    _buildTRF420XGridSelector(
                      label: 'サスマウント後シャフト位置',
                      settingKey: 'frontSusMountRearShaftPosition',
                      size: 150,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // デフ関連設定
                _buildTRF420XSettingsRow(
                  _buildTRF420XSettingField(
                    'frontDrive',
                    'デフ種類',
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'デフ種類',
                        border: OutlineInputBorder(),
                      ),
                      value: settings['frontDrive'] == null ||
                              settings['frontDrive'].toString().isEmpty
                          ? null
                          : settings['frontDrive'],
                      items: const [
                        DropdownMenuItem(value: 'スプール', child: Text('スプール')),
                        DropdownMenuItem(value: 'ギアデフ', child: Text('ギアデフ')),
                        DropdownMenuItem(value: 'ボールデフ', child: Text('ボールデフ')),
                        DropdownMenuItem(value: 'ワンウェイ', child: Text('ワンウェイ')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          settings['frontDrive'] = value;
                        });
                      },
                    ),
                  ),
                  _buildTRF420XSettingField(
                    'frontDifferentialOil',
                    'デフオイル',
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'デフオイル',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: settings['frontDifferentialOil'] ?? '',
                      onChanged: (value) {
                        setState(() {
                          settings['frontDifferentialOil'] = value;
                        });
                      },
                    ),
                  ),
                ),

                // フロントダンパー設定の展開パネル
                _buildTRF420XSingleSetting(
                  _buildTRF420XSettingField(
                    'frontDamperSettings',
                    'フロントダンパー設定',
                    _buildTRF420XExpandablePanel(
                      title: 'フロントダンパー設定',
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'ダンパーオフセット (mm)',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),

                        // ダンパーオフセット設定
                        _buildTRF420XSettingsRow(
                          _buildTRF420XSettingField(
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
                                setState(() {
                                  settings['frontDamperOffsetStay'] =
                                      double.tryParse(value) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          _buildTRF420XSettingField(
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
                                setState(() {
                                  settings['frontDamperOffsetArm'] =
                                      double.tryParse(value) ?? 0.0;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ダンパータイプとオイルシール設定
                        _buildTRF420XSettingsRow(
                          _buildTRF420XSettingField(
                            'frontDumperType',
                            'ダンパータイプ',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ダンパータイプ',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDumperType'] ?? '',
                              onChanged: (value) {
                                setState(() {
                                  settings['frontDumperType'] = value;
                                });
                              },
                            ),
                          ),
                          _buildTRF420XSettingField(
                            'frontDumperOilSeal',
                            'オイルシール',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'オイルシール',
                                border: OutlineInputBorder(),
                              ),
                              initialValue:
                                  settings['frontDumperOilSeal'] ?? '',
                              onChanged: (value) {
                                setState(() {
                                  settings['frontDumperOilSeal'] = value;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ピストン関連設定
                        _buildTRF420XSettingsRow(
                          _buildTRF420XSettingField(
                            'frontDumperPistonSize',
                            'ピストンサイズ',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ピストンサイズ',
                                border: OutlineInputBorder(),
                              ),
                              initialValue:
                                  settings['frontDumperPistonSize'] ?? '',
                              onChanged: (value) {
                                setState(() {
                                  settings['frontDumperPistonSize'] = value;
                                });
                              },
                            ),
                          ),
                          _buildTRF420XSettingField(
                            'frontDumperPistonHole',
                            'ピストン穴数',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ピストン穴数',
                                border: OutlineInputBorder(),
                              ),
                              initialValue:
                                  settings['frontDumperPistonHole'] ?? '',
                              onChanged: (value) {
                                setState(() {
                                  settings['frontDumperPistonHole'] = value;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // オイル関連設定
                        _buildTRF420XSettingsRow(
                          _buildTRF420XSettingField(
                            'frontDumperOilHardness',
                            'オイル硬度',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'オイル硬度',
                                border: OutlineInputBorder(),
                              ),
                              initialValue:
                                  settings['frontDumperOilHardness'] ?? '',
                              onChanged: (value) {
                                setState(() {
                                  settings['frontDumperOilHardness'] = value;
                                });
                              },
                            ),
                          ),
                          _buildTRF420XSettingField(
                            'frontDumperOilName',
                            'オイル名',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'オイル名',
                                border: OutlineInputBorder(),
                              ),
                              initialValue:
                                  settings['frontDumperOilName'] ?? '',
                              onChanged: (value) {
                                setState(() {
                                  settings['frontDumperOilName'] = value;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ストロークとエア抜き穴設定
                        _buildTRF420XSettingsRow(
                          _buildTRF420XSettingField(
                            'frontDumperStroke',
                            'ストローク長',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'ストローク長',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: settings['frontDumperStroke'] ?? '',
                              onChanged: (value) {
                                setState(() {
                                  settings['frontDumperStroke'] = value;
                                });
                              },
                            ),
                          ),
                          _buildTRF420XSettingField(
                            'frontDumperAirHole',
                            'エア抜き穴',
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'エア抜き穴(mm)',
                                border: OutlineInputBorder(),
                              ),
                              initialValue:
                                  settings['frontDumperAirHole'] ?? '',
                              onChanged: (value) {
                                setState(() {
                                  settings['frontDumperAirHole'] = value;
                                });
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

  // TRF420X専用の2つの設定項目を横に並べるためのヘルパーメソッド
  Widget _buildTRF420XSettingsRow(Widget widget1, Widget widget2) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: widget1),
          const SizedBox(width: 16),
          Expanded(child: widget2),
        ],
      ),
    );
  }

  // TRF420X専用の単一の設定項目を表示するためのヘルパーメソッド
  Widget _buildTRF420XSingleSetting(Widget widget) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: widget,
    );
  }

  // TRF420X専用の設定項目のフィールドを構築するヘルパーメソッド
  Widget _buildTRF420XSettingField(
      String key, String label, Widget inputWidget) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        inputWidget,
      ],
    );
  }

  // TRF420X専用の展開可能なパネルを構築するヘルパーメソッド
  Widget _buildTRF420XExpandablePanel(
      {required String title, required List<Widget> children}) {
    return ExpansionTile(
      title: Text(title),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  // TRF420X専用のグリッド選択UIを構築するヘルパーメソッド
  Widget _buildTRF420XGridSelector(
      {required String label,
      required String settingKey,
      required double size}) {
    // グリッド選択UIの実装
    // 例：3x3のグリッドで位置を選択できるUI
    const rows = 3;
    const cols = 3;

    // 現在の選択値を取得（例：'1,2'はrow=1, col=2を意味する）
    final currentValue = settings[settingKey] as String? ?? '1,1';
    final parts = currentValue.split(',');
    final selectedRow = int.tryParse(parts[0]) ?? 1;
    final selectedCol = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;

    return SizedBox(
      width: size,
      height: size,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 1,
        ),
        itemCount: rows * cols,
        itemBuilder: (context, index) {
          final row = index ~/ cols + 1;
          final col = index % cols + 1;
          final isSelected = row == selectedRow && col == selectedCol;

          return GestureDetector(
            onTap: () {
              setState(() {
                settings[settingKey] = '$row,$col';
              });
            },
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                color: isSelected ? Colors.blue : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '$row,$col',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
