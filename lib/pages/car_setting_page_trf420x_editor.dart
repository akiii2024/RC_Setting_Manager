// ignore_for_file: unused_element

part of 'car_setting_page.dart';

mixin _CarSettingTrf420xEditor on State<CarSettingPage> {
  Future<bool> _handleSettingsMutation<T>(
    String operationKey,
    Future<SettingsOperationResult<T>> Function() operation,
  );

  Map<String, dynamic> get settings;
  void _updateNumberSetting(String key, String input);
  String? _numberInputErrorText(String key);

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
            CamberInputField(
              settingKey: 'frontCamber',
              initialValue: settings['frontCamber'],
              labelText: isEnglish ? 'Camber Angle' : 'キャンバー角',
              errorText: _numberInputErrorText('frontCamber'),
              isEnglish: isEnglish,
              onChanged: (value) => _updateNumberSetting('frontCamber', value),
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
                errorText: _numberInputErrorText('frontRideHeight'),
              ),
              initialValue: settings['frontRideHeight']?.toString() ?? '0.0',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _updateNumberSetting('frontRideHeight', value);
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
            SignedAngleInputField(
              settingKey: 'frontToe',
              initialValue: settings['frontToe'],
              labelText: isEnglish ? 'Toe Angle' : 'トー角',
              errorText: _numberInputErrorText('frontToe'),
              isEnglish: isEnglish,
              negativeLabel: isEnglish ? 'Toe-out' : 'トーアウト',
              positiveLabel: isEnglish ? 'Toe-in' : 'トーイン',
              negativeByDefault: false,
              onChanged: (value) => _updateNumberSetting('frontToe', value),
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
                errorText: _numberInputErrorText('frontCasterAngle'),
              ),
              initialValue: settings['frontCasterAngle']?.toString() ?? '0.0',
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _updateNumberSetting('frontCasterAngle', value);
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
                        errorText:
                            _numberInputErrorText('frontUpperArmSpacerInside'),
                      ),
                      initialValue:
                          settings['frontUpperArmSpacerInside']?.toString() ??
                              '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _updateNumberSetting(
                            'frontUpperArmSpacerInside', value);
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
                        errorText:
                            _numberInputErrorText('frontUpperArmSpacerOutside'),
                      ),
                      initialValue:
                          settings['frontUpperArmSpacerOutside']?.toString() ??
                              '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _updateNumberSetting(
                            'frontUpperArmSpacerOutside', value);
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
                        errorText: _numberInputErrorText('frontLowerArmSpacer'),
                      ),
                      initialValue:
                          settings['frontLowerArmSpacer']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _updateNumberSetting('frontLowerArmSpacer', value);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ホイールハブ関連設定
                _buildTRF420XSettingsRow(
                  _buildTRF420XSettingFieldWithFavorite(
                    'frontWheelHub',
                    isEnglish ? 'Wheel Hub' : 'ホイールハブ',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Wheel Hub (mm)' : 'ホイールハブ (mm)',
                        border: const OutlineInputBorder(),
                        errorText: _numberInputErrorText('frontWheelHub'),
                      ),
                      initialValue:
                          settings['frontWheelHub']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _updateNumberSetting('frontWheelHub', value);
                      },
                    ),
                  ),
                  _buildTRF420XSettingFieldWithFavorite(
                    'frontWheelHubSpacer',
                    isEnglish ? 'Wheel Hub Spacer' : 'ホイールハブスペーサー',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish
                            ? 'Wheel Hub Spacer (mm)'
                            : 'ホイールハブスペーサー (mm)',
                        border: const OutlineInputBorder(),
                        errorText: _numberInputErrorText('frontWheelHubSpacer'),
                      ),
                      initialValue:
                          settings['frontWheelHubSpacer']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _updateNumberSetting('frontWheelHubSpacer', value);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ドループ設定（単独項目）
                _buildTRF420XSingleSetting(
                  _buildTRF420XSettingFieldWithFavorite(
                    'frontDroop',
                    isEnglish ? 'Droop' : 'ドループ',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Droop (mm)' : 'ドループ (mm)',
                        border: const OutlineInputBorder(),
                        errorText: _numberInputErrorText('frontDroop'),
                      ),
                      initialValue: settings['frontDroop']?.toString() ?? '0.0',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _updateNumberSetting('frontDroop', value);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // デフ位置設定（単独項目）
                _buildTRF420XSingleSetting(
                  _buildTRF420XSettingFieldWithFavorite(
                    'frontDiffarentialPosition',
                    isEnglish ? 'Diff Position' : 'デフ位置',
                    Row(
                      children: [
                        Text(isEnglish ? 'Diff Position: ' : 'デフ位置: '),
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
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(isEnglish ? 'High' : '高'),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(isEnglish ? 'Low' : '低'),
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
                    isEnglish ? 'Front Suspension Mount' : 'サスマウント前',
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText:
                            isEnglish ? 'Front Suspension Mount' : 'サスマウント前',
                        border: const OutlineInputBorder(),
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
                    isEnglish ? 'Rear Suspension Mount' : 'サスマウント後',
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText:
                            isEnglish ? 'Rear Suspension Mount' : 'サスマウント後',
                        border: const OutlineInputBorder(),
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
                    isEnglish ? 'Front Mount Shaft Position' : 'サスマウント前シャフト位置',
                    _buildTRF420XGridSelector(
                      label: isEnglish
                          ? 'Front Mount Shaft Position'
                          : 'サスマウント前シャフト位置',
                      settingKey: 'frontSusMountFrontShaftPosition',
                      size: 150,
                    ),
                  ),
                  _buildTRF420XSettingFieldWithFavorite(
                    'frontSusMountRearShaftPosition',
                    isEnglish ? 'Rear Mount Shaft Position' : 'サスマウント後シャフト位置',
                    _buildTRF420XGridSelector(
                      label: isEnglish
                          ? 'Rear Mount Shaft Position'
                          : 'サスマウント後シャフト位置',
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
                    isEnglish ? 'Diff Type' : 'デフ種類',
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Diff Type' : 'デフ種類',
                        border: const OutlineInputBorder(),
                      ),
                      initialValue: settings['frontDrive'] == null ||
                              settings['frontDrive'].toString().isEmpty
                          ? null
                          : settings['frontDrive'],
                      items: [
                        DropdownMenuItem(
                            value: 'スプール',
                            child: Text(isEnglish ? 'Spool' : 'スプール')),
                        DropdownMenuItem(
                            value: 'ギアデフ',
                            child: Text(isEnglish ? 'Gear Diff' : 'ギアデフ')),
                        DropdownMenuItem(
                            value: 'ボールデフ',
                            child: Text(isEnglish ? 'Ball Diff' : 'ボールデフ')),
                        DropdownMenuItem(
                            value: 'ワンウェイ',
                            child: Text(isEnglish ? 'One-Way' : 'ワンウェイ')),
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
                    isEnglish ? 'Diff Oil' : 'デフオイル',
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Diff Oil' : 'デフオイル',
                        border: const OutlineInputBorder(),
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
                    isEnglish ? 'Front Damper Settings' : 'フロントダンパー設定',
                    _buildTRF420XExpandablePanel(
                      title: isEnglish ? 'Front Damper Settings' : 'フロントダンパー設定',
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          isEnglish ? 'Damper Offset (mm)' : 'ダンパーオフセット (mm)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 16),

                        // ダンパーオフセット設定
                        _buildTRF420XSettingsRow(
                          _buildTRF420XSettingFieldWithFavorite(
                            'frontDamperOffsetStay',
                            isEnglish ? 'Damper Stay' : 'ステー',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText:
                                    isEnglish ? 'Damper Stay (mm)' : 'ステー (mm)',
                                border: const OutlineInputBorder(),
                                errorText: _numberInputErrorText(
                                    'frontDamperOffsetStay'),
                              ),
                              initialValue: settings['frontDamperOffsetStay']
                                      ?.toString() ??
                                  '0.0',
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _updateNumberSetting(
                                    'frontDamperOffsetStay', value);
                              },
                            ),
                          ),
                          _buildTRF420XSettingFieldWithFavorite(
                            'frontDamperOffsetArm',
                            isEnglish ? 'Suspension Arm' : 'サスアーム',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: isEnglish
                                    ? 'Suspension Arm (mm)'
                                    : 'サスアーム (mm)',
                                border: const OutlineInputBorder(),
                                errorText: _numberInputErrorText(
                                    'frontDamperOffsetArm'),
                              ),
                              initialValue: settings['frontDamperOffsetArm']
                                      ?.toString() ??
                                  '0.0',
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _updateNumberSetting(
                                    'frontDamperOffsetArm', value);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ダンパータイプとオイルシール設定
                        _buildTRF420XSettingsRow(
                          _buildTRF420XSettingFieldWithFavorite(
                            'frontDumperType',
                            isEnglish ? 'Damper Type' : 'ダンパータイプ',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText:
                                    isEnglish ? 'Damper Type' : 'ダンパータイプ',
                                border: const OutlineInputBorder(),
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
                            isEnglish ? 'Oil Seal' : 'オイルシール',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: isEnglish ? 'Oil Seal' : 'オイルシール',
                                border: const OutlineInputBorder(),
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
                            isEnglish ? 'Stroke Length' : 'ストローク長',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText:
                                    isEnglish ? 'Stroke Length' : 'ストローク長',
                                border: const OutlineInputBorder(),
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
                            isEnglish ? 'Bleed Hole' : 'エア抜き穴',
                            TextFormField(
                              decoration: InputDecoration(
                                labelText:
                                    isEnglish ? 'Bleed Hole (mm)' : 'エア抜き穴(mm)',
                                border: const OutlineInputBorder(),
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
            onPressed: () async {
              await _handleSettingsMutation(
                'favorite:${widget.originalCar.id}:$key',
                () => settingsProvider.toggleFavoriteSetting(
                  widget.originalCar.id,
                  key,
                  !isFavorite,
                ),
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
            onPressed: () async {
              await _handleSettingsMutation(
                'favorite:${widget.originalCar.id}:$key',
                () => settingsProvider.toggleFavoriteSetting(
                  widget.originalCar.id,
                  key,
                  !isFavorite,
                ),
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
