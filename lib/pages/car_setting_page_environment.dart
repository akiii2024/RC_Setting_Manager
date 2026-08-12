// ignore_for_file: unused_element

part of 'car_setting_page.dart';

mixin _CarSettingEnvironment on State<CarSettingPage> {
  Map<String, dynamic> get settings;
  String get carName;
  bool get _isEditing;
  TextEditingController get _settingNameController;
  TextEditingController get _trackNameController;

  TrackLocation? get _currentTrack;
  set _currentTrack(TrackLocation? value);
  Position? get _currentPosition;
  set _currentPosition(Position? value);
  LocationStatus? get _locationFailureStatus;
  set _locationFailureStatus(LocationStatus? value);
  bool get _isLocationLoading;
  set _isLocationLoading(bool value);
  WeatherData? get _currentWeather;
  set _currentWeather(WeatherData? value);
  WeatherStatus? get _weatherErrorStatus;
  set _weatherErrorStatus(WeatherStatus? value);
  bool get _isWeatherLoading;
  set _isWeatherLoading(bool value);

  // 位置情報を取得してトラック名を自動入力
  Future<void> _initializeLocationAndTrack() async {
    if (!mounted) return;

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final consentGranted = await ApiConsentService.requestConsent(
      context,
      type: ApiConsentType.weatherAndLocation,
      isEnglish: settingsProvider.isEnglish,
    );
    if (!consentGranted || !mounted) {
      return;
    }

    setState(() {
      _isLocationLoading = true;
    });

    try {
      final locationService = LocationService.instance;
      final position = await locationService.determineCurrentPosition();
      _currentPosition = position;
      _locationFailureStatus = null;

      await TrackLocationService.instance.loadTrackLocations();
      final nearestTrack = TrackLocationService.instance.findNearestTrack(
        position.latitude,
        position.longitude,
      );

      if (nearestTrack != null && mounted) {
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
        debugLog('近くにトラックが見つかりませんでした。手動でトラックを選択してください。');
      }
    } on LocationException catch (e) {
      _locationFailureStatus = e.status;
      debugLog('位置情報取得エラー [${e.status.name}]: ${e.message}');
      if (!mounted) return;
      switch (e.status) {
        case LocationStatus.permissionDenied:
          _showLocationPermissionDialog();
        case LocationStatus.serviceDisabled:
          _showLocationServiceDialog();
        case LocationStatus.timeout:
        case LocationStatus.unavailable:
          _showLocationFailureSnackBar(e.status);
        case LocationStatus.available:
          break;
      }
    } catch (e) {
      debugLog('位置情報取得エラー: $e');
      // エラーが発生してもアプリは継続
    } finally {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
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
          if (mounted) {
            setState(() {
              _currentTrack = track;
              _trackNameController.text = track.name;

              // 路面情報を自動入力
              _updateSurfaceFromTrack(track);
            });
          }
        },
      ),
    );
  }

  // 現在位置を再取得
  Future<void> _refreshLocation() async {
    await _initializeLocationAndTrack();
  }

  // 天気情報を取得して気温・湿度を自動入力
  Future<void> _initializeWeather({bool forceRefresh = false}) async {
    if (!mounted) return;

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    final consentGranted = await ApiConsentService.requestConsent(
      context,
      type: ApiConsentType.weatherAndLocation,
      isEnglish: settingsProvider.isEnglish,
    );
    if (!consentGranted || !mounted) {
      return;
    }

    setState(() {
      _isWeatherLoading = true;
      _weatherErrorStatus = null;
    });

    try {
      final weatherService = WeatherService.instance;
      var position = _currentPosition;
      if (position == null && !forceRefresh && _locationFailureStatus != null) {
        throw LocationException(
          '直前の現在位置取得に失敗しました',
          _locationFailureStatus!,
        );
      }
      if (position == null || forceRefresh) {
        position = await LocationService.instance.determineCurrentPosition();
        _currentPosition = position;
        _locationFailureStatus = null;
      }

      debugLog('[Weather Debug] getCurrentWeather() を呼び出し中...');
      final weather = await weatherService.fetchWeatherByCoordinates(
        position.latitude,
        position.longitude,
        forceRefresh: forceRefresh,
      );
      debugLog('[Weather Debug] getCurrentWeather() = ${weather.toString()}');

      if (mounted) {
        setState(() {
          _currentWeather = weather;
          _weatherErrorStatus = null;
        });

        // 気温と湿度を自動入力
        _updateWeatherSettings(weather);

        debugLog('[Weather Debug] SUCCESS: 天気情報を取得しました: ${weather.toString()}');
      }
    } on LocationException catch (e, stackTrace) {
      final status = _weatherStatusForLocation(e.status);
      debugLog(
          '[Weather Debug] LOCATION FAILED [${e.status.name}]: ${e.message}');
      debugLog('[Weather Debug] StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _currentWeather = null;
          _weatherErrorStatus = status;
        });
      }
    } on WeatherException catch (e, stackTrace) {
      debugLog('[Weather Debug] FAILED [${e.status.name}]: ${e.message}');
      debugLog('[Weather Debug] StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _currentWeather = null;
          _weatherErrorStatus = e.status;
        });
      }
    } catch (e, stackTrace) {
      debugLog('[Weather Debug] EXCEPTION: $e');
      debugLog('[Weather Debug] StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _currentWeather = null;
          _weatherErrorStatus = WeatherStatus.error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWeatherLoading = false;
        });
      }
    }
  }

  // 天気情報から設定値を更新
  void _updateWeatherSettings(WeatherData weather) {
    if (!mounted) return;

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
    await _initializeWeather(forceRefresh: true);
  }

  String _weatherFailureMessage(bool isEnglish) {
    return switch (_weatherErrorStatus) {
      WeatherStatus.locationPermissionDenied => isEnglish
          ? 'Allow location access in the browser or device settings, then retry.'
          : 'ブラウザまたは端末の設定で位置情報を許可してから再取得してください。',
      WeatherStatus.locationServiceDisabled => isEnglish
          ? 'Turn on Location Services on this device, then retry.'
          : '端末の位置情報サービスを有効にしてから再取得してください。',
      WeatherStatus.locationTimeout => isEnglish
          ? 'Location retrieval timed out. Move to an open area and retry.'
          : '位置情報の取得がタイムアウトしました。開けた場所で再取得してください。',
      WeatherStatus.noLocation => isEnglish
          ? 'The current location could not be determined. Check location settings and retry.'
          : '現在位置を特定できませんでした。位置情報設定を確認して再取得してください。',
      WeatherStatus.serviceError => isEnglish
          ? 'The weather service could not be reached. Check the network and retry.'
          : '天気サービスに接続できませんでした。通信状態を確認して再取得してください。',
      WeatherStatus.invalidResponse => isEnglish
          ? 'The weather service returned an invalid response. Please retry later.'
          : '天気サービスから不正な応答が返されました。時間をおいて再取得してください。',
      _ => isEnglish
          ? 'Weather data is unavailable. Check location and network settings, then retry.'
          : '天気データを取得できませんでした。位置情報と通信設定を確認して再取得してください。',
    };
  }

  // トラック情報から路面情報を更新
  void _updateSurfaceFromTrack(TrackLocation track) {
    final surfaceText = track.surfaceType == 'carpet' ? 'カーペット' : 'アスファルト';
    debugLog('路面情報を更新: ${track.name} -> $surfaceText'); // デバッグ用ログ
    settings['surface'] = surfaceText;
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

  void _showLocationFailureSnackBar(LocationStatus status) {
    final isEnglish =
        Provider.of<SettingsProvider>(context, listen: false).isEnglish;
    final message = switch (status) {
      LocationStatus.timeout => isEnglish
          ? 'Location retrieval timed out. Move to an open area and retry.'
          : '位置情報の取得がタイムアウトしました。開けた場所で再取得してください。',
      _ => isEnglish
          ? 'The current location could not be determined. Please retry.'
          : '現在位置を特定できませんでした。再取得してください。',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
