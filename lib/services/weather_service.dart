import 'package:rc_setting_manager/utils/app_logger.dart';
import 'dart:convert';
import 'dart:math' as math;

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
      debugLog(
        '[Weather Debug] getCurrentWeather: getting current position...',
      );
      final position = await LocationService.instance.getCurrentPosition();
      if (position == null) {
        debugLog('[Weather Debug] getCurrentWeather: position is null');
        return null;
      }
      debugLog(
        '[Weather Debug] getCurrentWeather: lat=${position.latitude}, '
        'lon=${position.longitude}',
      );

      return getWeatherByCoordinates(
        position.latitude,
        position.longitude,
        forceRefresh: forceRefresh,
      );
    } catch (e, stackTrace) {
      debugLog('[Weather Debug] getCurrentWeather EXCEPTION: $e');
      debugLog('[Weather Debug] getCurrentWeather StackTrace: $stackTrace');
      return null;
    }
  }

  Future<WeatherData?> getWeatherByCoordinates(
    double lat,
    double lon, {
    bool forceRefresh = false,
  }) async {
    try {
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
      final data = await FirebaseFunctionsService.call(
        'getCurrentWeather',
        {
          'lat': lat,
          'lon': lon,
        },
      );
      debugLog(
        '[Weather Debug] getWeatherByCoordinates: response city=${data['name']}',
      );

      final weather = WeatherData.fromJson(data);
      await _saveWeatherCache(lat, lon, weather);
      return weather;
    } catch (e, stackTrace) {
      debugLog('[Weather Debug] getWeatherByCoordinates EXCEPTION: $e');
      debugLog(
        '[Weather Debug] getWeatherByCoordinates StackTrace: $stackTrace',
      );
      return null;
    }
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
}

class WeatherException implements Exception {
  final String message;
  final WeatherStatus status;

  WeatherException(this.message, this.status);

  @override
  String toString() => 'WeatherException: $message';
}
