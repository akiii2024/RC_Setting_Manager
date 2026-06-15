import 'firebase_functions_service.dart';
import 'location_service.dart';

class WeatherService {
  static WeatherService? _instance;
  static WeatherService get instance => _instance ??= WeatherService._();

  WeatherService._();

  Future<WeatherData?> getCurrentWeather() async {
    try {
      print('[Weather Debug] getCurrentWeather: 位置情報を取得中...');
      final position = await LocationService.instance.getCurrentPosition();
      if (position == null) {
        print('[Weather Debug] getCurrentWeather: 位置情報がnull → return null');
        return null;
      }
      print('[Weather Debug] getCurrentWeather: 位置情報取得成功 lat=${position.latitude}, lon=${position.longitude}');

      return getWeatherByCoordinates(position.latitude, position.longitude);
    } catch (e, stackTrace) {
      print('[Weather Debug] getCurrentWeather EXCEPTION: $e');
      print('[Weather Debug] getCurrentWeather StackTrace: $stackTrace');
      return null;
    }
  }

  Future<WeatherData?> getWeatherByCoordinates(double lat, double lon) async {
    try {
      print('[Weather Debug] getWeatherByCoordinates: Firebase Functions呼び出し中 lat=$lat, lon=$lon');
      final data = await FirebaseFunctionsService.call(
        'getCurrentWeather',
        {
          'lat': lat,
          'lon': lon,
        },
      );
      print('[Weather Debug] getWeatherByCoordinates: レスポンス受信 city=${data['name']}');
      return WeatherData.fromJson(data);
    } catch (e, stackTrace) {
      print('[Weather Debug] getWeatherByCoordinates EXCEPTION: $e');
      print('[Weather Debug] getWeatherByCoordinates StackTrace: $stackTrace');
      return null;
    }
  }

  bool isApiKeyConfigured() => true;

  Future<bool> validateApiKey() async {
    try {
      print('[Weather Debug] validateApiKey: Firebase Functions呼び出し中...');
      final response = await FirebaseFunctionsService.call(
        'validateOpenWeatherApiKey',
        const {},
      );
      print('[Weather Debug] validateApiKey: レスポンス = $response');
      final isValid = response['valid'] == true;
      print('[Weather Debug] validateApiKey: isValid = $isValid');
      return isValid;
    } catch (e, stackTrace) {
      print('[Weather Debug] validateApiKey EXCEPTION: $e');
      print('[Weather Debug] validateApiKey StackTrace: $stackTrace');
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
