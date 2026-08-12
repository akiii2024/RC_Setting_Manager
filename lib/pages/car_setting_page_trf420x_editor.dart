// ignore_for_file: unused_element

part of 'car_setting_page.dart';

mixin _CarSettingTrf420xEditor on State<CarSettingPage> {
  Map<String, dynamic> get settings;

  _SelectGuideLabels _insideOutsideSelectGuideLabels();

  DropdownMenuItem<T> _buildSelectGuideMenuItem<T>({
    required T value,
    required String label,
  });

  Widget _buildTrf420xDamperPistonField({
    required String pistonKey,
    required String holeKey,
    List<String> pistonAliases = const [],
    List<String> holeAliases = const [],
  });

  Widget _buildTrf420xDamperOilField({
    required String oilKey,
    required String oilNameKey,
    List<String> oilAliases = const [],
    List<String> oilNameAliases = const [],
  });

  Widget _buildFrontSettingsTabForTRF420X() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final damperPositionGuideLabels = _insideOutsideSelectGuideLabels();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isEnglish ? 'Front Settings' : 'フロント設定',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // キャンバー角と車高の行
        _buildTRF420XSettingsRow(
          _buildTRF420XSettingFieldWithFavorite(
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
          _buildTRF420XSettingFieldWithFavorite(
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
          _buildTRF420XSettingFieldWithFavorite(
            'frontDamperPosition',
            isEnglish ? 'Damper Position' : 'ダンパーポジション',
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: isEnglish ? 'Damper Position' : 'ダンパーポジション',
                border: const OutlineInputBorder(),
              ),
              initialValue: settings['frontDamperPosition'] ?? 1,
              items: [
                _buildSelectGuideMenuItem<int>(
                  value: -1,
                  label: damperPositionGuideLabels.start,
                ),
                ...List.generate(5, (index) {
                  return DropdownMenuItem(
                    value: index + 1,
                    child: Text('${index + 1}'),
                  );
                }),
                _buildSelectGuideMenuItem<int>(
                  value: -2,
                  label: damperPositionGuideLabels.end,
                ),
              ],
              onChanged: (value) {
                if (value == null || value < 1) {
                  return;
                }
                setState(() {
                  settings['frontDamperPosition'] = value;
                });
              },
            ),
          ),
          _buildTRF420XSettingFieldWithFavorite(
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
          _buildTRF420XSettingFieldWithFavorite(
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
          _buildTRF420XSettingFieldWithFavorite(
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
          _buildTRF420XSettingFieldWithFavorite(
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
                  _buildTRF420XSettingFieldWithFavorite(
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
                  _buildTRF420XSettingFieldWithFavorite(
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
                  _buildTRF420XSettingFieldWithFavorite(
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
                  _buildTRF420XSettingFieldWithFavorite(
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
                  _buildTRF420XSettingFieldWithFavorite(
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
                  _buildTRF420XSettingFieldWithFavorite(
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
                  _buildTRF420XSettingFieldWithFavorite(
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
                  _buildTRF420XSettingFieldWithFavorite(
                    'frontSusMountFront',
                    'サスマウント前',
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'サスマウント前',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: settings['frontSusMountFront'] == null ||
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
                  _buildTRF420XSettingFieldWithFavorite(
                    'frontSusMountRear',
                    'サスマウント後',
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'サスマウント後',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: settings['frontSusMountRear'] == null ||
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
                  _buildTRF420XSettingFieldWithFavorite(
                    'frontSusMountFrontShaftPosition',
                    'サスマウント前シャフト位置',
                    _buildTRF420XGridSelector(
                      label: 'サスマウント前シャフト位置',
                      settingKey: 'frontSusMountFrontShaftPosition',
                      size: 150,
                    ),
                  ),
                  _buildTRF420XSettingFieldWithFavorite(
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
                  _buildTRF420XSettingFieldWithFavorite(
                    'frontDrive',
                    'デフ種類',
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'デフ種類',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: settings['frontDrive'] == null ||
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
                  _buildTRF420XSettingFieldWithFavorite(
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
                          _buildTRF420XSettingFieldWithFavorite(
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
                          _buildTRF420XSettingFieldWithFavorite(
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
                          _buildTRF420XSettingFieldWithFavorite(
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
                          _buildTRF420XSettingFieldWithFavorite(
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
                        _buildTRF420XSingleSetting(
                          _buildTRF420XCompactSettingWithFavorite(
                            'frontDumperPistonSize',
                            _buildTrf420xDamperPistonField(
                              pistonKey: 'frontDumperPistonSize',
                              holeKey: 'frontDumperPistonHole',
                              pistonAliases: const ['frontDamperPiston'],
                              holeAliases: const ['frontDamperPistonHole'],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // オイル関連設定
                        _buildTRF420XSingleSetting(
                          _buildTRF420XCompactSettingWithFavorite(
                            'frontDumperOilHardness',
                            _buildTrf420xDamperOilField(
                              oilKey: 'frontDumperOilHardness',
                              oilNameKey: 'frontDumperOilName',
                              oilAliases: const ['frontDamperOil'],
                              oilNameAliases: const ['frontDamperOilName'],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ストロークとエア抜き穴設定
                        _buildTRF420XSettingsRow(
                          _buildTRF420XSettingFieldWithFavorite(
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
                          _buildTRF420XSettingFieldWithFavorite(
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

  // TRF420X専用の設定項目のフィールドを構築するヘルパーメソッド（よく使うマーク付き）
  Widget _buildTRF420XSettingFieldWithFavorite(
      String key, String label, Widget inputWidget) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final favoriteKeys =
        settingsProvider.getFavoriteSettings(widget.originalCar.id);
    final isFavorite = favoriteKeys.contains(key);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildTRF420XSettingField(key, label, inputWidget),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20.0), // ラベルの高さに合わせて調整
          child: IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : null,
              size: 20,
            ),
            onPressed: () {
              settingsProvider.toggleFavoriteSetting(
                widget.originalCar.id,
                key,
                !isFavorite,
              );
            },
            tooltip: settingsProvider.isEnglish
                ? (isFavorite ? 'Remove from favorites' : 'Add to favorites')
                : (isFavorite ? 'よく使う項目から削除' : 'よく使う項目に追加'),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildTRF420XCompactSettingWithFavorite(
      String key, Widget inputWidget) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final favoriteKeys =
        settingsProvider.getFavoriteSettings(widget.originalCar.id);
    final isFavorite = favoriteKeys.contains(key);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: inputWidget),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : null,
              size: 20,
            ),
            onPressed: () {
              settingsProvider.toggleFavoriteSetting(
                widget.originalCar.id,
                key,
                !isFavorite,
              );
            },
            tooltip: settingsProvider.isEnglish
                ? (isFavorite ? 'Remove from favorites' : 'Add to favorites')
                : (isFavorite ? 'よく使う項目から削除' : 'よく使う項目に追加'),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
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
                border: Border.all(color: Theme.of(context).dividerColor),
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '$row,$col',
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
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
