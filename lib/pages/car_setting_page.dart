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
import '../widgets/grid_selector.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../models/track_location.dart';
import '../data/track_locations.dart';
import './ocr_import_page.dart';

class CarSettingPage extends StatefulWidget {
  final Car originalCar;
  final Map<String, dynamic>? savedSettings;
  final String? savedSettingId;
  final String? settingName;

  const CarSettingPage({
    super.key,
    required this.originalCar,
    this.savedSettings,
    this.savedSettingId,
    this.settingName,
  });

  @override
  State<CarSettingPage> createState() => _CarSettingPageState();
}

class _CarSettingPageState extends State<CarSettingPage> {
  late String carName;
  late Map<String, dynamic> settings;
  bool _isLoading = true;
  final TextEditingController _settingNameController = TextEditingController();
  final TextEditingController _trackNameController = TextEditingController();
  bool _isEditing = false;
  CarSettingDefinition? _carSettingDefinition;
  TrackLocation? _currentTrack;
  bool _isLocationLoading = false;
  WeatherData? _currentWeather;
  bool _isWeatherLoading = false;

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
      // セッティング名の初期値を日付-車種名に設定
      final now = DateTime.now();
      final formattedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      _settingNameController.text = '$formattedDate-$carName';
    }

    _initializeSettings();
    // 位置情報と天気情報の初期化を少し遅延させる
    Future.delayed(const Duration(milliseconds: 500), () {
      _initializeLocationAndTrack();
      _initializeWeather();
    });
  }

  // 設定項目の型に応じたデフォルト値を返す
  dynamic _getDefaultValueForType(SettingItem setting) {
    switch (setting.type) {
      case 'number':
        return setting.constraints['default'] ?? 0.0;
      case 'text':
        if (setting.key == 'date' && setting.isAutoFilled) {
          return DateTime.now().toString().split(' ')[0];
        }
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

  // 位置情報を取得してトラック名を自動入力
  Future<void> _initializeLocationAndTrack() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      final locationService = LocationService.instance;

      // 位置情報の権限状況を確認
      final locationStatus = await locationService.getLocationStatus();

      if (locationStatus == LocationStatus.permissionDenied) {
        print('位置情報の権限が拒否されています。手動でトラックを選択してください。');
        _showLocationPermissionDialog();
        return;
      }

      if (locationStatus == LocationStatus.serviceDisabled) {
        print('位置情報サービスが無効です。設定で有効にしてください。');
        _showLocationServiceDialog();
        return;
      }

      final nearestTrack = await locationService.findNearestTrack();

      if (nearestTrack != null) {
        setState(() {
          _currentTrack = nearestTrack;
          _trackNameController.text = nearestTrack.name;

          // 路面情報を自動入力
          _updateSurfaceFromTrack(nearestTrack);

          // セッティング名にトラック名を含める（新規作成時のみ）
          if (!_isEditing) {
            final now = DateTime.now();
            final formattedDate =
                '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            _settingNameController.text =
                '$formattedDate-${nearestTrack.name}-$carName';
          }
        });
      } else {
        print('近くにトラックが見つかりませんでした。手動でトラックを選択してください。');
      }
    } catch (e) {
      print('位置情報取得エラー: $e');
      // エラーが発生してもアプリは継続
    } finally {
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  // 手動でトラック検索
  Future<void> _searchTrackManually() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) => _TrackSearchDialog(
        isEnglish: isEnglish,
        onTrackSelected: (track) {
          setState(() {
            _currentTrack = track;
            _trackNameController.text = track.name;

            // 路面情報を自動入力
            _updateSurfaceFromTrack(track);
          });
        },
      ),
    );
  }

  // 現在位置を再取得
  Future<void> _refreshLocation() async {
    await _initializeLocationAndTrack();
  }

  // 天気情報を取得して気温・湿度を自動入力
  Future<void> _initializeWeather() async {
    setState(() {
      _isWeatherLoading = true;
    });

    try {
      final weatherService = WeatherService.instance;

      // APIキーが設定されているかチェック
      if (!weatherService.isApiKeyConfigured()) {
        print('天気APIキーが設定されていません。モックデータを使用します。');
        final mockWeather = weatherService.getMockWeatherData();
        setState(() {
          _currentWeather = mockWeather;
        });
        _updateWeatherSettings(mockWeather);
        return;
      }

      // APIキーの有効性をテスト
      final isValidApiKey = await weatherService.validateApiKey();
      if (!isValidApiKey) {
        print('APIキーが無効です。モックデータを使用します。');
        final mockWeather = weatherService.getMockWeatherData();
        setState(() {
          _currentWeather = mockWeather;
        });
        _updateWeatherSettings(mockWeather);
        return;
      }

      final weather = await weatherService.getCurrentWeather();

      if (weather != null) {
        setState(() {
          _currentWeather = weather;
        });

        // 気温と湿度を自動入力
        _updateWeatherSettings(weather);

        print('天気情報を取得しました: ${weather.toString()}');
      } else {
        print('天気情報を取得できませんでした。モックデータを使用します。');
        final mockWeather = weatherService.getMockWeatherData();
        setState(() {
          _currentWeather = mockWeather;
        });
        _updateWeatherSettings(mockWeather);
      }
    } catch (e) {
      print('天気情報取得エラー: $e');
      print('モックデータを使用します。');
      final weatherService = WeatherService.instance;
      final mockWeather = weatherService.getMockWeatherData();
      setState(() {
        _currentWeather = mockWeather;
      });
      _updateWeatherSettings(mockWeather);
    } finally {
      setState(() {
        _isWeatherLoading = false;
      });
    }
  }

  // 天気情報から設定値を更新
  void _updateWeatherSettings(WeatherData weather) {
    setState(() {
      // 気温を自動入力（小数点第1位まで）
      settings['airTemp'] =
          double.parse(weather.temperature.toStringAsFixed(1));

      // 湿度を自動入力
      settings['humidity'] = weather.humidity.toDouble();

      // コンディション情報も更新（オプション）
      if (settings['condition'] == null ||
          settings['condition'].toString().isEmpty) {
        settings['condition'] = weather.description;
      }
    });
  }

  // 天気情報を手動で再取得
  Future<void> _refreshWeather() async {
    await _initializeWeather();
  }

  // トラック情報から路面情報を更新
  void _updateSurfaceFromTrack(TrackLocation track) {
    final surfaceText = track.surfaceType == 'carpet' ? 'カーペット' : 'アスファルト';
    print('路面情報を更新: ${track.name} -> $surfaceText'); // デバッグ用ログ
    settings['surface'] = surfaceText;
  }

  // OCRから設定をインポート
  Future<void> _importFromOCR() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => OCRImportPage(
          car: widget.originalCar,
          currentSettings: settings,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        settings = result;
      });

      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final isEnglish = settingsProvider.isEnglish;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'Settings imported successfully'
              : 'セッティングをインポートしました'),
        ),
      );
    }
  }

  // 位置情報権限のダイアログを表示
  void _showLocationPermissionDialog() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(isEnglish ? 'Location Permission Required' : '位置情報の権限が必要です'),
        content: Text(isEnglish
            ? 'This app needs location permission to automatically detect nearby tracks. You can still manually select tracks.'
            : 'このアプリは近くのトラックを自動検出するために位置情報の権限が必要です。手動でトラックを選択することもできます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isEnglish ? 'OK' : 'OK'),
          ),
        ],
      ),
    );
  }

  // 位置情報サービスのダイアログを表示
  void _showLocationServiceDialog() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEnglish ? 'Location Service Disabled' : '位置情報サービスが無効です'),
        content: Text(isEnglish
            ? 'Please enable location services in your device settings to use automatic track detection.'
            : 'デバイスの設定で位置情報サービスを有効にして、自動トラック検出機能をご利用ください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isEnglish ? 'OK' : 'OK'),
          ),
        ],
      ),
    );
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
            icon: const Icon(Icons.document_scanner),
            onPressed: _importFromOCR,
            tooltip: isEnglish ? 'Import from Image' : '画像から読み込み',
          ),
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

            // Track name input with location features
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _trackNameController,
                    decoration: InputDecoration(
                      labelText: isEnglish ? 'Track Name' : 'トラック名',
                      hintText:
                          isEnglish ? 'e.g. Tamiya Circuit' : '例：タミヤサーキット',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 16.0),
                      prefixIcon: _currentTrack != null
                          ? Icon(
                              _currentTrack!.type == 'indoor'
                                  ? Icons.home_work
                                  : Icons.landscape,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const Icon(Icons.place),
                      suffixIcon: _isLocationLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      helperText: _currentTrack != null
                          ? '${_currentTrack!.prefecture} • ${isEnglish ? (_currentTrack!.type == 'indoor' ? 'Indoor' : 'Outdoor') : (_currentTrack!.type == 'indoor' ? '屋内' : '屋外')} • ${_currentTrack!.surfaceType == 'carpet' ? (isEnglish ? 'Carpet' : 'カーペット') : (isEnglish ? 'Asphalt' : 'アスファルト')}'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _refreshLocation,
                  icon: const Icon(Icons.my_location),
                  tooltip: isEnglish ? 'Get current location' : '現在位置を取得',
                ),
                IconButton(
                  onPressed: _searchTrackManually,
                  icon: const Icon(Icons.search),
                  tooltip: isEnglish ? 'Search track' : 'トラック検索',
                ),
              ],
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
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FloatingActionButton(
              heroTag: 'saveButton',
              onPressed: _saveAsNewSetting,
              tooltip: isEnglish ? 'Save as New' : '新規保存',
              child: const Icon(Icons.save_as),
            ),
          ),
          FloatingActionButton(
            heroTag: 'updateButton',
            onPressed: _updateSetting,
            tooltip: isEnglish ? 'Update' : '更新',
            child: const Icon(Icons.update),
          ),
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
          backgroundColor: Theme.of(context).colorScheme.error,
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

  void _saveAsNewSetting() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    if (_settingNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isEnglish ? 'Please enter a setting name' : 'セッティング名を入力してください'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_settingNameController.text == widget.settingName) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'Please change the setting name to save as new'
              : '新規保存するにはセッティング名を変更してください'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

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

  void _updateSetting() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish ? 'No setting to update' : '更新する設定がありません'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
      'favorites': isEnglish ? 'Favorites' : 'よく使う項目',
      'basic': isEnglish ? 'Basic' : '基本',
      'front': isEnglish ? 'Front' : 'フロント',
      'rear': isEnglish ? 'Rear' : 'リア',
      'top': isEnglish ? 'Top Deck' : 'トップデッキ',
      'other': isEnglish ? 'Other' : 'その他',
      'memo': isEnglish ? 'Memo' : 'メモ',
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
                // よく使う項目タブの場合
                if (category == 'favorites') {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildFavoriteSettings(),
                  );
                }
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isEnglish
                  ? 'No favorite items yet.\nTap the star icon on any setting to add it here.'
                  : 'よく使う項目がまだありません。\n各設定項目の星アイコンをタップして追加してください。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    // よく使う項目として選択された設定を表示
    final favoriteSettings = _carSettingDefinition!.availableSettings
        .where((setting) => favoriteKeys.contains(setting.key))
        .toList();

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
        }).toList(),
      ],
    );
  }

  Widget _buildCategorySettings(String category) {
    final categorySettings = _carSettingDefinition!.availableSettings
        .where((setting) => setting.category == category)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 基本設定タブの場合、天気情報の状況を表示
        if (category == 'basic') _buildWeatherInfoCard(),
        ...categorySettings.map((setting) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildSettingFieldWithFavorite(setting),
          );
        }).toList(),
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
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
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
                      isEnglish
                          ? 'Weather data not available. Using manual input.'
                          : '天気データが利用できません。手動入力を使用してください。',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5)),
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
      // モックデータかどうかを判定
      final isUsingMockData = _currentWeather!.cityName == 'テスト地点';

      return Card(
        color: Theme.of(context).colorScheme.brightness == Brightness.light
            ? (isUsingMockData ? Colors.orange.shade50 : Colors.blue.shade50)
            : (isUsingMockData
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primaryContainer),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isUsingMockData ? Icons.warning : Icons.cloud,
                    color: isUsingMockData
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isUsingMockData
                        ? (isEnglish ? 'Sample Weather Data' : 'サンプル天気データ')
                        : (isEnglish ? 'Current Weather' : '現在の天気'),
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
              if (isUsingMockData) ...[
                const SizedBox(height: 4),
                Text(
                  isEnglish
                      ? 'API key not configured or invalid. Using sample data.'
                      : 'APIキーが未設定または無効です。サンプルデータを使用中。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
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
                        if (!isUsingMockData)
                          Text(
                            '${isEnglish ? "Location" : "地点"}: ${_currentWeather!.cityName}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5)),
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
    if (setting.type == 'grid') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(setting.label),
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
        Text(setting.label),
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
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
        onPressed: _isWeatherLoading ? null : _refreshWeather,
        tooltip: setting.key == 'airTemp' ? '現在の気温を取得' : '現在の湿度を取得',
      );
    }

    return null;
  }

  Widget _buildTextField(SettingItem setting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(setting.label),
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
                  _buildTRF420XSettingFieldWithFavorite(
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
                        _buildTRF420XSettingsRow(
                          _buildTRF420XSettingFieldWithFavorite(
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
                          _buildTRF420XSettingFieldWithFavorite(
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
                          _buildTRF420XSettingFieldWithFavorite(
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
                          _buildTRF420XSettingFieldWithFavorite(
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

// トラック検索ダイアログ
class _TrackSearchDialog extends StatefulWidget {
  final bool isEnglish;
  final Function(TrackLocation) onTrackSelected;

  const _TrackSearchDialog({
    required this.isEnglish,
    required this.onTrackSelected,
  });

  @override
  State<_TrackSearchDialog> createState() => _TrackSearchDialogState();
}

class _TrackSearchDialogState extends State<_TrackSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<TrackLocation> _searchResults = [];
  String? _selectedPrefecture;

  @override
  void initState() {
    super.initState();
    _searchResults = trackLocations; // 初期状態では全てのトラックを表示
  }

  void _performSearch() {
    setState(() {
      String query = _searchController.text.trim();
      if (query.isEmpty && _selectedPrefecture == null) {
        _searchResults = trackLocations;
      } else {
        _searchResults = trackLocations.where((track) {
          bool matchesName = query.isEmpty ||
              track.name.toLowerCase().contains(query.toLowerCase());
          bool matchesPrefecture = _selectedPrefecture == null ||
              track.prefecture == _selectedPrefecture;
          return matchesName && matchesPrefecture;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEnglish ? 'Search Track' : 'トラック検索'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // 検索フィールド
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: widget.isEnglish ? 'Track Name' : 'トラック名',
                hintText: widget.isEnglish ? 'Enter track name' : 'トラック名を入力',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => _performSearch(),
            ),
            const SizedBox(height: 16),

            // 都道府県フィルター
            DropdownButtonFormField<String>(
              value: _selectedPrefecture,
              decoration: InputDecoration(
                labelText: widget.isEnglish ? 'Prefecture' : '都道府県',
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(widget.isEnglish ? 'All Prefectures' : '全ての都道府県'),
                ),
                ...getAllPrefectures().map(
                  (prefecture) => DropdownMenuItem<String>(
                    value: prefecture,
                    child: Text(prefecture),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPrefecture = value;
                });
                _performSearch();
              },
            ),
            const SizedBox(height: 16),

            // 検索結果リスト
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        widget.isEnglish ? 'No tracks found' : 'トラックが見つかりません',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final track = _searchResults[index];
                        final surfaceText = track.surfaceType == 'carpet'
                            ? (widget.isEnglish ? 'Carpet' : 'カーペット')
                            : (widget.isEnglish ? 'Asphalt' : 'アスファルト');
                        final typeText = track.type == 'indoor'
                            ? (widget.isEnglish ? 'Indoor' : '屋内')
                            : (widget.isEnglish ? 'Outdoor' : '屋外');

                        return ListTile(
                          title: Text(track.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${track.prefecture} - ${track.address}'),
                              Text(
                                '$typeText • $surfaceText',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                track.surfaceType == 'carpet'
                                    ? Icons.texture
                                    : Icons.straighten,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                track.type == 'indoor'
                                    ? Icons.home
                                    : Icons.landscape,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                          onTap: () {
                            widget.onTrackSelected(track);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.isEnglish ? 'Cancel' : 'キャンセル'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
