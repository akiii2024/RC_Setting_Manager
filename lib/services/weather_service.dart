import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class WeatherService {
  static WeatherService? _instance;
  static WeatherService get instance => _instance ??= WeatherService._();
  WeatherService._();

  // OpenWeatherMap API Key
  // 環境変数から読み込むか、デフォルト値を使用
  static String get _apiKey {
    // 環境変数から読み込みを試行
    try {
      // flutter_dotenvが利用可能な場合
      if (const bool.fromEnvironment('dart.vm.product')) {
        // 本番環境では環境変数から読み込み
        return const String.fromEnvironment('OPENWEATHER_API_KEY',
            defaultValue: '246dd320b476949a3891b9113da1bfce');
      }
    } catch (e) {
      print('環境変数読み込みエラー: $e');
    }
    // デフォルト値（開発用）
    return '246dd320b476949a3891b9113da1bfce';
  }

  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  /// 現在位置の天気情報を取得
  Future<WeatherData?> getCurrentWeather() async {
    try {
      // 現在位置を取得
      final locationService = LocationService.instance;
      final position = await locationService.getCurrentPosition();

      if (position == null) {
        print('位置情報を取得できませんでした');
        return null;
      }

      return await getWeatherByCoordinates(
          position.latitude, position.longitude);
    } catch (e) {
      print('天気情報取得エラー: $e');
      return null;
    }
  }

  /// 指定した座標の天気情報を取得
  Future<WeatherData?> getWeatherByCoordinates(double lat, double lon) async {
    try {
      final url = Uri.parse(
          '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=ja');

      print('天気API リクエスト URL: $url'); // デバッグ用

      final response = await http.get(url);

      print('天気API レスポンス: ${response.statusCode}'); // デバッグ用

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('天気データ取得成功: ${data['name']}'); // デバッグ用
        return WeatherData.fromJson(data);
      } else {
        print('天気API エラー: ${response.statusCode}');
        print('エラーレスポンス: ${response.body}'); // エラー詳細を表示

        // 401エラーの場合は特別な処理
        if (response.statusCode == 401) {
          print('APIキーが無効です。OpenWeatherMapでAPIキーを確認してください。');
          throw WeatherException('APIキーが無効です', WeatherStatus.noApiKey);
        }

        return null;
      }
    } catch (e) {
      print('天気情報取得エラー: $e');
      return null;
    }
  }

  /// APIキーが設定されているかチェック
  bool isApiKeyConfigured() {
    return _apiKey != 'YOUR_API_KEY_HERE' && _apiKey.isNotEmpty;
  }

  /// APIキーの有効性をテスト
  Future<bool> validateApiKey() async {
    try {
      // 東京の座標でテスト
      final url = Uri.parse(
          '$_baseUrl?lat=35.6762&lon=139.6503&appid=$_apiKey&units=metric');

      final response = await http.get(url);
      return response.statusCode == 200;
    } catch (e) {
      print('APIキー検証エラー: $e');
      return false;
    }
  }

  /// モックデータを返す（APIキーが設定されていない場合のテスト用）
  WeatherData getMockWeatherData() {
    return WeatherData(
      temperature: 25.0,
      humidity: 60,
      description: '晴れ',
      feelsLike: 27.0,
      pressure: 1013,
      visibility: 10000,
      windSpeed: 3.5,
      windDirection: 180,
      cloudiness: 20,
      cityName: 'テスト地点',
    );
  }
}

class WeatherData {
  final double temperature; // 気温 (℃)
  final int humidity; // 湿度 (%)
  final String description; // 天気の説明
  final double feelsLike; // 体感温度 (℃)
  final int pressure; // 気圧 (hPa)
  final int visibility; // 視程 (m)
  final double windSpeed; // 風速 (m/s)
  final int windDirection; // 風向 (度)
  final int cloudiness; // 雲量 (%)
  final String cityName; // 都市名

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
    return 'WeatherData(temp: ${temperature.toStringAsFixed(1)}℃, humidity: $humidity%, desc: $description)';
  }
}

/// 天気情報の取得状況を表す列挙型
enum WeatherStatus {
  loading, // 取得中
  success, // 取得成功
  error, // エラー
  noApiKey, // APIキー未設定
  noLocation, // 位置情報なし
}

/// 天気情報取得のカスタム例外
class WeatherException implements Exception {
  final String message;
  final WeatherStatus status;

  WeatherException(this.message, this.status);

  @override
  String toString() => 'WeatherException: $message';
}
