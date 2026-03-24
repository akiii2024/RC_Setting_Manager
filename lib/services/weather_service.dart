import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_secrets.dart';
import 'location_service.dart';

class WeatherService {
  static WeatherService? _instance;
  static WeatherService get instance => _instance ??= WeatherService._();

  WeatherService._();

  static String get _apiKey => AppSecrets.openWeatherApiKey;

  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  Future<WeatherData?> getCurrentWeather() async {
    try {
      final position = await LocationService.instance.getCurrentPosition();
      if (position == null) {
        print('Unable to get current location for weather lookup.');
        return null;
      }

      return getWeatherByCoordinates(position.latitude, position.longitude);
    } catch (e) {
      print('Weather lookup failed: $e');
      return null;
    }
  }

  Future<WeatherData?> getWeatherByCoordinates(double lat, double lon) async {
    if (!isApiKeyConfigured()) {
      print('OpenWeather API key is not configured.');
      return null;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=ja',
      );

      print('Weather API request URL: $url');

      final response = await http.get(url);
      print('Weather API status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('Weather API city: ${data['name']}');
        return WeatherData.fromJson(data);
      }

      if (response.statusCode == 401) {
        print('OpenWeather API key is invalid.');
        return null;
      }

      print('Weather API error body: ${response.body}');
      return null;
    } catch (e) {
      print('Weather lookup failed: $e');
      return null;
    }
  }

  bool isApiKeyConfigured() => AppSecrets.hasOpenWeatherApiKey;

  Future<bool> validateApiKey() async {
    if (!isApiKeyConfigured()) {
      return false;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl?lat=35.6762&lon=139.6503&appid=$_apiKey&units=metric',
      );

      final response = await http.get(url);
      return response.statusCode == 200;
    } catch (e) {
      print('Weather API validation failed: $e');
      return false;
    }
  }

  WeatherData getMockWeatherData() {
    return WeatherData(
      temperature: 25.0,
      humidity: 60,
      description: 'Sunny',
      feelsLike: 27.0,
      pressure: 1013,
      visibility: 10000,
      windSpeed: 3.5,
      windDirection: 180,
      cloudiness: 20,
      cityName: 'Test Course',
    );
  }
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
  noApiKey,
  noLocation,
}

class WeatherException implements Exception {
  final String message;
  final WeatherStatus status;

  WeatherException(this.message, this.status);

  @override
  String toString() => 'WeatherException: $message';
}
