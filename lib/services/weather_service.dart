import 'package:rc_setting_manager/utils/app_logger.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_functions_service.dart';
import 'location_service.dart';

class WeatherService {
  static WeatherService? _instance;
  static WeatherService get instance => _instance ??= WeatherService._();

  static const String _weatherCacheKey = 'weather_cache_current_v1';
  static const Duration _weatherCacheDuration = Duration(minutes: 30);
  static const double _weatherCacheMaxDistanceMeters = 5000;

  WeatherService._();

  Future<WeatherData?> getCurrentWeather({bool forceRefresh = false}) async {
    try {
      return await fetchCurrentWeather(forceRefresh: forceRefresh);
    } on WeatherException catch (e, stackTrace) {
      debugLog(
        '[Weather Debug] getCurrentWeather FAILED [${e.status.name}]: '
        '${e.message}',
      );
      debugLog('[Weather Debug] getCurrentWeather StackTrace: $stackTrace');
      return null;
    } catch (e, stackTrace) {
      debugLog('[Weather Debug] getCurrentWeather EXCEPTION: $e');
      debugLog('[Weather Debug] getCurrentWeather StackTrace: $stackTrace');
      return null;
    }
  }

  Future<WeatherData> fetchCurrentWeather({bool forceRefresh = false}) async {
    try {
      debugLog(
        '[Weather Debug] getCurrentWeather: getting current position...',
      );
      final position =
          await LocationService.instance.determineCurrentPosition();
      debugLog(
        '[Weather Debug] getCurrentWeather: lat=${position.latitude}, '
        'lon=${position.longitude}',
      );

      return fetchWeatherByCoordinates(
        position.latitude,
        position.longitude,
        forceRefresh: forceRefresh,
      );
    } on LocationException catch (e) {
      throw WeatherException(
        e.message,
        switch (e.status) {
          LocationStatus.permissionDenied =>
            WeatherStatus.locationPermissionDenied,
          LocationStatus.serviceDisabled =>
            WeatherStatus.locationServiceDisabled,
          LocationStatus.timeout => WeatherStatus.locationTimeout,
          _ => WeatherStatus.noLocation,
        },
      );
    }
  }

  Future<WeatherData?> getWeatherByCoordinates(
    double lat,
    double lon, {
    bool forceRefresh = false,
  }) async {
    try {
      return await fetchWeatherByCoordinates(
        lat,
        lon,
        forceRefresh: forceRefresh,
      );
    } on WeatherException catch (e, stackTrace) {
      debugLog(
        '[Weather Debug] getWeatherByCoordinates FAILED [${e.status.name}]: '
        '${e.message}',
      );
      debugLog(
        '[Weather Debug] getWeatherByCoordinates StackTrace: $stackTrace',
      );
      return null;
    }
  }

  Future<WeatherData> fetchWeatherByCoordinates(
    double lat,
    double lon, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedWeather = await _getCachedWeather(lat, lon);
      if (cachedWeather != null) {
        debugLog('[Weather Debug] getWeatherByCoordinates: cache hit');
        return cachedWeather;
      }
    }

    debugLog(
      '[Weather Debug] getWeatherByCoordinates: calling Firebase Functions '
      'lat=$lat, lon=$lon',
    );

    final Map<String, dynamic> data;
    try {
      data = await FirebaseFunctionsService.call(
        'getCurrentWeather',
        {
          'lat': lat,
          'lon': lon,
        },
      );
    } catch (e) {
      throw WeatherException.fromServiceError(e);
    }

    debugLog(
      '[Weather Debug] getWeatherByCoordinates: response city=${data['name']}',
    );

    final WeatherData weather;
    try {
      weather = WeatherData.fromJson(data);
    } catch (e) {
      throw WeatherException(
        '天気サービスから不正な応答を受信しました: $e',
        WeatherStatus.invalidResponse,
      );
    }

    await _saveWeatherCache(lat, lon, weather);
    return weather;
  }

  Future<WeatherData?> _getCachedWeather(double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_weatherCacheKey);
      if (cached == null) return null;

      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(
        decoded['fetchedAt'] as int,
      );
      final age = DateTime.now().difference(fetchedAt);
      if (age > _weatherCacheDuration) return null;

      final cachedLat = (decoded['lat'] as num).toDouble();
      final cachedLon = (decoded['lon'] as num).toDouble();
      final distance = _distanceInMeters(lat, lon, cachedLat, cachedLon);
      if (distance > _weatherCacheMaxDistanceMeters) return null;

      return WeatherData.fromCacheJson(
        Map<String, dynamic>.from(decoded['data'] as Map),
      );
    } catch (e) {
      debugLog('[Weather Debug] _getCachedWeather EXCEPTION: $e');
      return null;
    }
  }

  Future<void> _saveWeatherCache(
    double lat,
    double lon,
    WeatherData weather,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _weatherCacheKey,
        jsonEncode({
          'fetchedAt': DateTime.now().millisecondsSinceEpoch,
          'lat': lat,
          'lon': lon,
          'data': weather.toJson(),
        }),
      );
    } catch (e) {
      debugLog('[Weather Debug] _saveWeatherCache EXCEPTION: $e');
    }
  }

  double _distanceInMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final rLat1 = _degreesToRadians(lat1);
    final rLat2 = _degreesToRadians(lat2);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final clampedA = a.clamp(0.0, 1.0);
    final c = 2 * math.atan2(math.sqrt(clampedA), math.sqrt(1 - clampedA));
    return earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
}

class WeatherData {
  final double temperature;
  final int humidity;
  final String description;
  final double feelsLike;
  final int pressure;
  final int visibility;
  final double windSpeed;
  final int windDirection;
  final int cloudiness;
  final String cityName;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.description,
    required this.feelsLike,
    required this.pressure,
    required this.visibility,
    required this.windSpeed,
    required this.windDirection,
    required this.cloudiness,
    required this.cityName,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['main']['temp'] as num).toDouble(),
      humidity: json['main']['humidity'] as int,
      description: json['weather'][0]['description'] as String,
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      pressure: json['main']['pressure'] as int,
      visibility: json['visibility'] as int? ?? 10000,
      windSpeed: (json['wind']?['speed'] as num?)?.toDouble() ?? 0.0,
      windDirection: json['wind']?['deg'] as int? ?? 0,
      cloudiness: json['clouds']['all'] as int,
      cityName: json['name'] as String,
    );
  }

  factory WeatherData.fromCacheJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: json['humidity'] as int,
      description: json['description'] as String,
      feelsLike: (json['feelsLike'] as num).toDouble(),
      pressure: json['pressure'] as int,
      visibility: json['visibility'] as int,
      windSpeed: (json['windSpeed'] as num).toDouble(),
      windDirection: json['windDirection'] as int,
      cloudiness: json['cloudiness'] as int,
      cityName: json['cityName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'description': description,
      'feelsLike': feelsLike,
      'pressure': pressure,
      'visibility': visibility,
      'windSpeed': windSpeed,
      'windDirection': windDirection,
      'cloudiness': cloudiness,
      'cityName': cityName,
    };
  }

  @override
  String toString() {
    return 'WeatherData(temp: ${temperature.toStringAsFixed(1)}C, humidity: '
        '$humidity%, desc: $description)';
  }
}

enum WeatherStatus {
  loading,
  success,
  error,
  noLocation,
  locationPermissionDenied,
  locationServiceDisabled,
  locationTimeout,
  serviceError,
  invalidResponse,
}

class WeatherException implements Exception {
  final String message;
  final WeatherStatus status;
  final String? diagnosticCode;

  WeatherException(this.message, this.status, {this.diagnosticCode});

  factory WeatherException.fromServiceError(Object error) {
    // SDKのメッセージやdetailsにはURL等が含まれ得るため、画面には
    // プラグイン名とコードのみを渡す。座標・トークンは表示しない。
    final code = error is FirebaseException
        ? '${error.plugin}/${error.code}'
        : 'weather/unexpected-error';
    return WeatherException(
      '天気サービスの呼び出しに失敗しました',
      WeatherStatus.serviceError,
      diagnosticCode: code,
    );
  }

  String? serviceFailureMessage(bool isEnglish) {
    final diagnostic = diagnosticCode;
    if (diagnostic == null) return null;

    final String description;
    if (diagnostic == 'firebase_app_check/missing-site-key') {
      description = isEnglish
          ? 'The web app is missing its verification configuration. Please contact the administrator.'
          : 'Web版のアクセス検証設定が不足しています。管理者にお知らせください。';
    } else if (diagnostic.startsWith('firebase_auth/')) {
      description = isEnglish
          ? 'Authentication for the weather service failed. Please retry or report the code below.'
          : '天気サービスの認証に失敗しました。再取得しても続く場合は下のコードをお知らせください。';
    } else if (diagnostic.startsWith('firebase_app_check/') ||
        diagnostic.endsWith('/unauthenticated') ||
        diagnostic.endsWith('/permission-denied')) {
      description = isEnglish
          ? 'The weather service could not verify access. Please retry or report the code below.'
          : '天気サービスのアクセス検証に失敗しました。再取得しても続く場合は下のコードをお知らせください。';
    } else if (diagnostic.endsWith('/failed-precondition') ||
        diagnostic.endsWith('/not-found')) {
      description = isEnglish
          ? 'The weather service configuration needs checking. Please contact the administrator.'
          : '天気サービスの設定確認が必要です。管理者にお知らせください。';
    } else if (diagnostic.endsWith('/resource-exhausted')) {
      description = isEnglish
          ? 'The weather service usage limit was reached. Please retry later.'
          : '天気サービスの利用上限に達しました。時間をおいて再取得してください。';
    } else {
      description = isEnglish
          ? 'The weather service request failed. Please retry or report the code below.'
          : '天気サービスの処理に失敗しました。再取得しても続く場合は下のコードをお知らせください。';
    }
    return '$description\n${isEnglish ? 'Error code' : 'エラーコード'}: $diagnostic';
  }

  @override
  String toString() => 'WeatherException: $message';
}
