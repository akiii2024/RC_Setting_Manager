// ignore_for_file: unused_element, unused_element_parameter

part of 'car_setting_page.dart';

mixin _CarSettingNormalEditor on State<CarSettingPage> {
  Map<String, dynamic> get settings;
  CarSettingDefinition? get _carSettingDefinition;
  TrackLocation? get _currentTrack;
  WeatherData? get _currentWeather;
  bool get _isWeatherLoading;

  Future<void> _refreshWeather();
  String _weatherFailureMessage(bool isEnglish);
  Widget _buildAppEditorHeader(bool isEnglish);
  Widget _buildFrontSettingsTabForTRF420X();
  List<SettingItem> _getCategorySettings(String category);
  List<SettingItem> _filterHiddenTrf420xCompositeParts(
    Iterable<SettingItem> items,
  );
  String? _compositeTypeForSetting(SettingItem setting);
  String _compositeKey(
    SettingItem setting,
    String constraintKey,
    String fallback,
  );
  List<String> _compositeKeys(
    SettingItem setting, {
    required String primaryKey,
    required String fallback,
    String? aliasesKey,
  });
  String _settingTextForKey(
    String key, {
    List<String> aliases = const [],
  });
  void _updateTextSettingWithAliases(
    String key,
    List<String> aliases,
    String value,
  );

  Widget _buildSettingTabs(BuildContext context) {
    if (_carSettingDefinition == null) {
      return const Center(child: Text('車種の設定定義が見つかりません'));
    }

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    // カテゴリーごとに設定項目をグループ化
    final categories = {
      'favorites': isEnglish ? 'Favorites' : 'よく使う項目',
      'basic': isEnglish ? 'Basic' : '基本',
      'front': isEnglish ? 'Front' : 'フロント',
      'frontDamper': isEnglish ? 'Front Damper' : 'フロントダンパー',
      'rear': isEnglish ? 'Rear' : 'リア',
      'rearDamper': isEnglish ? 'Rear Damper' : 'リアダンパー',
      'top': isEnglish ? 'Top Deck' : 'トップデッキ',
      'other': isEnglish ? 'Other' : 'その他',
      'memo': isEnglish ? 'Memo' : 'メモ',
    };

    final tabBar = TabBar(
      isScrollable: true,
      tabs: categories.values.map((name) => Tab(text: name)).toList(),
    );

    return DefaultTabController(
      length: categories.length,
      child: NestedScrollView(
        key: const Key('setting-editor-scroll-view'),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: _buildAppEditorHeader(isEnglish),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SettingTabBarDelegate(
              tabBar: tabBar,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
        body: TabBarView(
          children: categories.keys.map((category) {
            // よく使う項目タブの場合
            if (category == 'favorites') {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: _buildFavoriteSettings(),
              );
            }
            // TRF420Xのフロントタブの場合、専用のビルダーを使用
            if (category == 'front' &&
                widget.originalCar.id == 'trf420x' &&
                _getCategorySettings('frontDamper').isEmpty) {
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
    );
  }

  // よく使う項目を表示するメソッド
  Widget _buildFavoriteSettings() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final favoriteKeys =
        settingsProvider.getFavoriteSettings(widget.originalCar.id);

    if (favoriteKeys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_border,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isEnglish
                  ? 'No favorite items yet.\nTap the star icon on any setting to add it here.'
                  : 'よく使う項目がまだありません。\n各設定項目の星アイコンをタップして追加してください。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    // よく使う項目として選択された設定を表示
    final favoriteSettings = _filterHiddenTrf420xCompositeParts(
      _carSettingDefinition!.availableSettings
          .where((setting) => favoriteKeys.contains(setting.key)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 基本設定の項目があれば天気情報カードを表示
        if (favoriteSettings.any((s) => s.category == 'basic'))
          _buildWeatherInfoCard(),
        ...favoriteSettings.map((setting) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildSettingFieldWithFavorite(setting),
          );
        }),
      ],
    );
  }

  Widget _buildCategorySettings(String category) {
    final categorySettings = _getCategorySettings(category);
    final settingWidgets = <Widget>[];

    for (var index = 0; index < categorySettings.length; index++) {
      final setting = categorySettings[index];
      final nextSetting = index + 1 < categorySettings.length
          ? categorySettings[index + 1]
          : null;

      if (nextSetting != null &&
          _shouldPairSettingsInResponsiveRow(setting, nextSetting)) {
        settingWidgets.add(_buildResponsiveSettingPair(setting, nextSetting));
        index++;
        continue;
      }

      settingWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildSettingFieldWithFavorite(setting),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 基本設定タブの場合、天気情報の状況を表示
        if (category == 'basic') _buildWeatherInfoCard(),
        ...settingWidgets,
      ],
    );
  }

  bool _shouldPairSettingsInResponsiveRow(
    SettingItem first,
    SettingItem second,
  ) {
    const pairedKeys = {
      'frontSusMountFrontShaftPosition': 'frontSusMountRearShaftPosition',
      'rearSusMountFrontShaftPosition': 'rearSusMountRearShaftPosition',
    };

    return pairedKeys[first.key] == second.key;
  }

  Widget _buildResponsiveSettingPair(
    SettingItem first,
    SettingItem second,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 320 &&
            first.type == 'grid' &&
            second.type == 'grid') {
          final availableItemWidth = (constraints.maxWidth - 8) / 2;
          final firstCellSize = _compactGridCellSize(first, availableItemWidth);
          final secondCellSize =
              _compactGridCellSize(second, availableItemWidth);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCompactGridSettingWithFavorite(
                    first,
                    cellSize: firstCellSize,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactGridSettingWithFavorite(
                    second,
                    cellSize: secondCellSize,
                  ),
                ),
              ],
            ),
          );
        }

        if (constraints.maxWidth >= 640) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildSettingFieldWithFavorite(first)),
                const SizedBox(width: 16),
                Expanded(child: _buildSettingFieldWithFavorite(second)),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildSettingFieldWithFavorite(first),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildSettingFieldWithFavorite(second),
            ),
          ],
        );
      },
    );
  }

  double _compactGridCellSize(SettingItem setting, double availableWidth) {
    final cols = setting.constraints['cols'] as int;
    final rawSize = ((availableWidth - 16) / cols) - 4;
    return rawSize.clamp(24.0, 48.0);
  }

  Widget _buildCompactGridSettingWithFavorite(
    SettingItem setting, {
    required double cellSize,
  }) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final favoriteKeys =
        settingsProvider.getFavoriteSettings(widget.originalCar.id);
    final isFavorite = favoriteKeys.contains(setting.key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                setting.label,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : null,
                size: 20,
              ),
              onPressed: () {
                settingsProvider.toggleFavoriteSetting(
                  widget.originalCar.id,
                  setting.key,
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
          ],
        ),
        const SizedBox(height: 6),
        GridSelector(
          rows: setting.constraints['rows'] as int,
          cols: setting.constraints['cols'] as int,
          allowMultiple: setting.constraints['multiple'] as bool,
          initialValue: _getGridValue(setting.key),
          cellSize: cellSize,
          onChanged: (points) => _updateGridValue(setting.key, points),
        ),
      ],
    );
  }

  // よく使うマーク付きの設定フィールドを構築
  Widget _buildSettingFieldWithFavorite(SettingItem setting) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final favoriteKeys =
        settingsProvider.getFavoriteSettings(widget.originalCar.id);
    final isFavorite = favoriteKeys.contains(setting.key);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSettingField(setting),
        ),
        IconButton(
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite ? Colors.amber : null,
          ),
          onPressed: () {
            settingsProvider.toggleFavoriteSetting(
              widget.originalCar.id,
              setting.key,
              !isFavorite,
            );
          },
          tooltip: settingsProvider.isEnglish
              ? (isFavorite ? 'Remove from favorites' : 'Add to favorites')
              : (isFavorite ? 'よく使う項目から削除' : 'よく使う項目に追加'),
        ),
      ],
    );
  }

  // 天気情報カードを構築
  Widget _buildWeatherInfoCard() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    if (_currentWeather == null && !_isWeatherLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.cloud_off,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEnglish ? 'Weather Information' : '天気情報',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _weatherFailureMessage(isEnglish),
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refreshWeather,
                icon: const Icon(Icons.refresh),
                tooltip: isEnglish ? 'Retry weather fetch' : '天気情報を再取得',
              ),
            ],
          ),
        ),
      );
    }

    if (_isWeatherLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                isEnglish ? 'Loading weather data...' : '天気情報を取得中...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentWeather != null) {
      return Card(
        color: Theme.of(context).colorScheme.brightness == Brightness.light
            ? Colors.blue.shade50
            : Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEnglish ? 'Current Weather' : '現在の天気',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _refreshWeather,
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: isEnglish ? 'Update weather' : '天気情報を更新',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isEnglish ? "Temperature" : "気温"}: ${_currentWeather!.temperature.toStringAsFixed(1)}℃',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          '${isEnglish ? "Humidity" : "湿度"}: ${_currentWeather!.humidity}%',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isEnglish ? "Condition" : "天候"}: ${_currentWeather!.description}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          '${isEnglish ? "Location" : "地点"}: ${_currentWeather!.cityName}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSettingField(SettingItem setting) {
    final trf420xCompositeField = _buildTrf420xCompositeField(setting);
    if (trf420xCompositeField != null) {
      return trf420xCompositeField;
    }

    if (setting.type == 'grid') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingLabel(setting),
          const SizedBox(height: 8),
          GridSelector(
            rows: setting.constraints['rows'] as int,
            cols: setting.constraints['cols'] as int,
            allowMultiple: setting.constraints['multiple'] as bool,
            initialValue: _getGridValue(setting.key),
            onChanged: (points) => _updateGridValue(setting.key, points),
          ),
        ],
      );
    }
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

  bool get _isTrf420x =>
      widget.originalCar.id == 'tamiya/trf420x' ||
      widget.originalCar.id == 'trf420x';

  bool _isTrf420xHiddenCompositePart(String key) {
    SettingItem? definitionSetting;
    for (final setting
        in _carSettingDefinition?.availableSettings ?? <SettingItem>[]) {
      if (setting.key == key) {
        definitionSetting = setting;
        break;
      }
    }

    if (definitionSetting?.constraints['hidden'] == true) {
      return true;
    }

    if (_isCompositePartKey(key)) {
      return true;
    }

    return _isTrf420x && key == 'ballastWeight';
  }

  bool _isCompositePartKey(String key) {
    final settings = _carSettingDefinition?.availableSettings;
    if (settings == null) {
      return false;
    }

    for (final setting in settings) {
      if (_compositeTypeForSetting(setting) == null) {
        continue;
      }

      final compositeKeys = <String>{
        ..._compositeKeys(
          setting,
          primaryKey: 'diameterKey',
          fallback: setting.key,
        ),
        _compositeKey(setting, 'noteKey', '${setting.key}Note'),
        _compositeKey(setting, 'oilTypeKey', '${setting.key}Type'),
        ..._compositeKeys(
          setting,
          primaryKey: 'oilKey',
          fallback: setting.key,
          aliasesKey: 'oilAliases',
        ),
        _compositeKey(setting, 'weightKey', '${setting.key}Weight'),
        ..._compositeKeys(
          setting,
          primaryKey: 'pistonKey',
          fallback: setting.key,
          aliasesKey: 'pistonAliases',
        ),
        ..._compositeKeys(
          setting,
          primaryKey: 'holeKey',
          fallback: '${setting.key}Hole',
          aliasesKey: 'holeAliases',
        ),
        ..._compositeKeys(
          setting,
          primaryKey: 'oilNameKey',
          fallback: '${setting.key}Name',
          aliasesKey: 'oilNameAliases',
        ),
      }..remove(setting.key);

      if (compositeKeys.contains(key)) {
        return true;
      }
    }

    return false;
  }

  Widget _buildSettingLabel(SettingItem setting) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final guideText = _trf420xTopPositionGuideText(
      setting.key,
      isEnglish: settingsProvider.isEnglish,
    );

    if (guideText == null) {
      return Text(setting.label);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: Text(setting.label)),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.help_outline, size: 18),
          onPressed: () {
            _showTrf420xTopPositionGuide(
              title: setting.label,
              message: guideText,
              isEnglish: settingsProvider.isEnglish,
            );
          },
          tooltip: settingsProvider.isEnglish ? 'Position guide' : '位置ガイド',
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  String? _trf420xTopPositionGuideText(
    String key, {
    required bool isEnglish,
  }) {
    if (!_isTrf420x) {
      return null;
    }

    return switch (key) {
      'ballastWeightA' => isEnglish ? 'Left front area' : '左前エリア',
      'ballastWeightB' => isEnglish ? 'Left rear area' : '左後エリア',
      'ballastWeightC' => isEnglish ? 'Center battery area' : '中央、バッテリー付近',
      'topScrewPositions' =>
        isEnglish ? '1 to 7 from left to right' : '左から右へ1〜7',
      'rearSusHardness' => isEnglish ? 'Right center area' : '右中央エリア',
      'frontSusArmSpacer' => isEnglish
          ? 'Front suspension arm spacer is on the center-left side.'
          : '中央左側のフロント側',
      'rearSusArmSpacer' => isEnglish
          ? 'Rear suspension arm spacer is on the right side.'
          : '右側のリア側',
      _ => null,
    };
  }

  void _showTrf420xTopPositionGuide({
    required String title,
    required String message,
    required bool isEnglish,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(isEnglish ? 'Close' : '閉じる'),
          ),
        ],
      ),
    );
  }

  Widget? _buildTrf420xCompositeField(SettingItem setting) {
    final compositeType = _compositeTypeForSetting(setting);
    if (compositeType == null) {
      return null;
    }

    return switch (compositeType) {
      'stabilizer' => _buildTrf420xStabilizerField(
          setting,
          diameterKey: _compositeKey(setting, 'diameterKey', setting.key),
          noteKey: _compositeKey(setting, 'noteKey', '${setting.key}Note'),
        ),
      'diffOil' => _buildTrf420xDiffOilField(
          setting,
          oilTypeKey:
              _compositeKey(setting, 'oilTypeKey', '${setting.key}Type'),
          oilKey: _compositeKey(setting, 'oilKey', setting.key),
          weightKey:
              _compositeKey(setting, 'weightKey', '${setting.key}Weight'),
        ),
      'damperPiston' => _buildTrf420xDamperPistonField(
          pistonKey: _compositeKey(setting, 'pistonKey', setting.key),
          holeKey: _compositeKey(setting, 'holeKey', '${setting.key}Hole'),
          pistonAliases: _compositeKeys(
            setting,
            primaryKey: 'pistonKey',
            fallback: setting.key,
            aliasesKey: 'pistonAliases',
          ).skip(1).toList(growable: false),
          holeAliases: _compositeKeys(
            setting,
            primaryKey: 'holeKey',
            fallback: '${setting.key}Hole',
            aliasesKey: 'holeAliases',
          ).skip(1).toList(growable: false),
        ),
      'damperOil' => _buildTrf420xDamperOilField(
          oilKey: _compositeKey(setting, 'oilKey', setting.key),
          oilNameKey:
              _compositeKey(setting, 'oilNameKey', '${setting.key}Name'),
          oilAliases: _compositeKeys(
            setting,
            primaryKey: 'oilKey',
            fallback: setting.key,
            aliasesKey: 'oilAliases',
          ).skip(1).toList(growable: false),
          oilNameAliases: _compositeKeys(
            setting,
            primaryKey: 'oilNameKey',
            fallback: '${setting.key}Name',
            aliasesKey: 'oilNameAliases',
          ).skip(1).toList(growable: false),
        ),
      _ => null,
    };
  }

  Widget _buildTrf420xStabilizerField(
    SettingItem setting, {
    required String diameterKey,
    required String noteKey,
  }) {
    final isEnglish =
        Provider.of<SettingsProvider>(context, listen: false).isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(setting.label)),
            const SizedBox(width: 8),
            SizedBox(
              width: 128,
              child: TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: 'φ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: settings[diameterKey]?.toString() ?? '',
                onChanged: (value) {
                  setState(() {
                    settings[diameterKey] = double.tryParse(value) ?? 0.0;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: isEnglish ? 'Stabilizer note' : ' ',
          ),
          initialValue: settings[noteKey]?.toString() ?? '',
          onChanged: (value) {
            setState(() {
              settings[noteKey] = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTrf420xDiffOilField(
    SettingItem setting, {
    required String oilTypeKey,
    required String oilKey,
    required String weightKey,
  }) {
    final isEnglish =
        Provider.of<SettingsProvider>(context, listen: false).isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final oilTypeField = TextFormField(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: isEnglish ? 'Oil type' : 'オイル種類',
              ),
              initialValue: settings[oilTypeKey]?.toString() ?? '',
              onChanged: (value) {
                setState(() {
                  settings[oilTypeKey] = value;
                });
              },
            );
            final oilField = TextFormField(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                prefixText: '# ',
                hintText: isEnglish ? 'Oil' : '番手',
              ),
              initialValue: settings[oilKey]?.toString() ?? '',
              onChanged: (value) {
                setState(() {
                  settings[oilKey] = value;
                });
              },
            );
            final weightField = TextFormField(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixText: 'g',
                hintText: isEnglish ? 'Weight' : '量',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              initialValue: settings[weightKey]?.toString() ?? '',
              onChanged: (value) {
                setState(() {
                  settings[weightKey] = value;
                });
              },
            );

            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(setting.label),
                  const SizedBox(height: 8),
                  oilTypeField,
                  const SizedBox(height: 8),
                  oilField,
                  const SizedBox(height: 8),
                  weightField,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(setting.label),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: oilTypeField),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: oilField),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: weightField),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTrf420xDamperPistonField({
    required String pistonKey,
    required String holeKey,
    List<String> pistonAliases = const [],
    List<String> holeAliases = const [],
  }) {
    final isEnglish =
        Provider.of<SettingsProvider>(context, listen: false).isEnglish;

    return LayoutBuilder(
      builder: (context, constraints) {
        final label = _buildTrf420xCompactLabel(
          isEnglish ? 'Piston' : 'ピストン',
          secondary: isEnglish ? null : 'Piston',
        );
        final inputs = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _buildTrf420xCompactTextField(
                settingKey: pistonKey,
                aliases: pistonAliases,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 6),
            const Text('φ', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Expanded(
              child: _buildTrf420xCompactTextField(
                settingKey: holeKey,
                aliases: holeAliases,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'hole(s)',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(fontSize: 12),
            ),
          ],
        );

        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: 8),
              inputs,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 72, child: label),
            const SizedBox(width: 8),
            Expanded(child: inputs),
          ],
        );
      },
    );
  }

  Widget _buildTrf420xDamperOilField({
    required String oilKey,
    required String oilNameKey,
    List<String> oilAliases = const [],
    List<String> oilNameAliases = const [],
  }) {
    final isEnglish =
        Provider.of<SettingsProvider>(context, listen: false).isEnglish;

    return LayoutBuilder(
      builder: (context, constraints) {
        final label = _buildTrf420xCompactLabel(
          isEnglish ? 'Oil' : 'オイル / Oil',
        );
        final oilNumberInput = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('#', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Expanded(
              child: _buildTrf420xCompactTextField(
                settingKey: oilKey,
                aliases: oilAliases,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        );
        final oilRow = constraints.maxWidth < 320
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  const SizedBox(height: 8),
                  oilNumberInput,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 92, child: label),
                  const SizedBox(width: 8),
                  Expanded(child: oilNumberInput),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            oilRow,
            const SizedBox(height: 8),
            _buildTrf420xCompactTextField(
              settingKey: oilNameKey,
              aliases: oilNameAliases,
              hintText: isEnglish ? 'Oil name' : 'オイル名',
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrf420xCompactLabel(String label, {String? secondary}) {
    return Text(
      secondary == null ? label : '$label\n$secondary',
      maxLines: secondary == null ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.1,
      ),
    );
  }

  Widget _buildTrf420xCompactTextField({
    required String settingKey,
    List<String> aliases = const [],
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return SizedBox(
      height: 44,
      child: TextFormField(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          hintText: hintText,
        ),
        keyboardType: keyboardType,
        initialValue: _settingTextForKey(settingKey, aliases: aliases),
        onChanged: (value) {
          _updateTextSettingWithAliases(settingKey, aliases, value);
        },
      ),
    );
  }

  List<Point> _getGridValue(String key) {
    final value = settings[key];
    if (value == null) return [];
    if (value is List) {
      return value.map((p) => Point.fromJson(p)).toList();
    }
    return [];
  }

  void _updateGridValue(String key, List<Point> points) {
    setState(() {
      settings[key] = points.map((p) => p.toJson()).toList();
    });
  }

  Widget _buildNumberField(SettingItem setting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingLabel(setting),
        const SizedBox(height: 8),
        TextFormField(
          key:
              ValueKey('${setting.key}_${settings[setting.key]}'), // 値が変わったら再構築
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixText: setting.unit,
            suffixIcon: _buildAutoFillIcon(setting),
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

  // 自動入力アイコンを構築
  Widget? _buildAutoFillIcon(SettingItem setting) {
    if (!setting.isAutoFilled) return null;

    if (setting.key == 'airTemp' || setting.key == 'humidity') {
      return IconButton(
        icon: _isWeatherLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.cloud,
                color: _currentWeather != null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
              ),
        onPressed: _isWeatherLoading ? null : _refreshWeather,
        tooltip: setting.key == 'airTemp' ? '現在の気温を取得' : '現在の湿度を取得',
      );
    }

    return null;
  }

  Widget _buildTextField(SettingItem setting) {
    if (_suggestionsForSetting(setting).isNotEmpty) {
      return _buildSuggestedTextField(setting);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingLabel(setting),
        const SizedBox(height: 8),
        TextFormField(
          key:
              ValueKey('${setting.key}_${settings[setting.key]}'), // 値が変わったら再構築
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixIcon: setting.key == 'date' && setting.isAutoFilled
                ? IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      setState(() {
                        settings[setting.key] =
                            DateTime.now().toString().split(' ')[0];
                      });
                    },
                    tooltip: '現在の日付を入力',
                  )
                : setting.key == 'surface'
                    ? Icon(
                        _currentTrack?.surfaceType == 'carpet'
                            ? Icons.texture
                            : Icons.straighten,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
          ),
          initialValue: setting.key == 'date' && setting.isAutoFilled
              ? DateTime.now().toString().split(' ')[0]
              : settings[setting.key]?.toString() ?? '',
          onChanged: (value) {
            setState(() {
              settings[setting.key] = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSuggestedTextField(SettingItem setting) {
    final initialText = settings[setting.key]?.toString() ?? '';
    final suggestions = _suggestionsForSetting(setting);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingLabel(setting),
        const SizedBox(height: 8),
        Autocomplete<String>(
          key: ValueKey('${setting.key}_suggested_$initialText'),
          initialValue: TextEditingValue(text: initialText),
          optionsBuilder: (TextEditingValue value) {
            return _suggestionsForSetting(
              setting,
              query: value.text,
            );
          },
          onSelected: (value) {
            setState(() {
              settings[setting.key] = value;
            });
          },
          fieldViewBuilder: (
            context,
            controller,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                hintText: suggestions.isNotEmpty ? suggestions.first : null,
              ),
              onChanged: (value) {
                setState(() {
                  settings[setting.key] = value;
                });
              },
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
        ),
      ],
    );
  }

  List<String> _suggestionsForSetting(
    SettingItem setting, {
    String query = '',
  }) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    return settingsProvider.getSuggestionsForSetting(
      setting.key,
      setting.options,
      query: query,
    );
  }

  Widget _buildSelectField(SettingItem setting) {
    // 現在の設定値を取得
    final currentValue = settings[setting.key];

    // 設定値がオプションに存在するかチェック
    String? validValue;
    if (currentValue != null &&
        setting.options != null &&
        setting.options!.contains(currentValue)) {
      validValue = currentValue;
    } else {
      // 値が無効な場合はnullに設定
      validValue = null;
      // 無効な値があった場合は設定からも削除
      if (currentValue != null) {
        // デバッグ情報を出力
        debugLog('無効なドロップダウン値を検出: ${setting.key} = "$currentValue"');
        debugLog('利用可能なオプション: ${setting.options}');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              settings[setting.key] = null;
            });
          }
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingLabel(setting),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          initialValue: validValue,
          items: _buildSelectMenuItems(setting),
          onChanged: (value) {
            if (_isSelectGuideValue(value)) {
              return;
            }
            setState(() {
              settings[setting.key] = value;
            });
          },
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>>? _buildSelectMenuItems(SettingItem setting) {
    final options = setting.options;
    if (options == null) {
      return null;
    }

    final guideLabels = _selectGuideLabels(setting);
    if (guideLabels == null) {
      return options.map(_buildSelectOptionMenuItem).toList();
    }

    return [
      _buildSelectGuideMenuItem(
        value: _selectGuideValue(setting.key, 'start'),
        label: guideLabels.start,
      ),
      ...options.map(_buildSelectOptionMenuItem),
      _buildSelectGuideMenuItem(
        value: _selectGuideValue(setting.key, 'end'),
        label: guideLabels.end,
      ),
    ];
  }

  DropdownMenuItem<String> _buildSelectOptionMenuItem(String option) {
    return DropdownMenuItem(
      value: option,
      child: Text(option),
    );
  }

  DropdownMenuItem<T> _buildSelectGuideMenuItem<T>({
    required T value,
    required String label,
  }) {
    return DropdownMenuItem(
      value: value,
      enabled: false,
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _SelectGuideLabels? _selectGuideLabels(SettingItem setting) {
    final guide = setting.constraints['selectGuide'];
    if (guide != 'insideOutside') {
      return null;
    }

    return _insideOutsideSelectGuideLabels();
  }

  _SelectGuideLabels _insideOutsideSelectGuideLabels() {
    final isEnglish = Provider.of<SettingsProvider>(context).isEnglish;
    return isEnglish
        ? const _SelectGuideLabels(start: 'Inside', end: 'Outside')
        : const _SelectGuideLabels(start: '内側', end: '外側');
  }

  Widget _buildSliderField(SettingItem setting) {
    final min = setting.constraints['min'] as double? ?? 0.0;
    final max = setting.constraints['max'] as double? ?? 100.0;
    final divisions = setting.constraints['divisions'] as int? ?? 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingLabel(setting),
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
}
