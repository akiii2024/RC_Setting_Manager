import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/services/weather_service.dart';

void main() {
  group('WeatherData', () {
    test('OpenWeather response can be serialized and restored from cache', () {
      final weather = WeatherData.fromJson({
        'main': {
          'temp': 24.6,
          'humidity': 58,
          'feels_like': 25.1,
          'pressure': 1012,
        },
        'weather': [
          {'description': 'Sunny'},
        ],
        'visibility': 9000,
        'wind': {
          'speed': 2.4,
          'deg': 120,
        },
        'clouds': {
          'all': 15,
        },
        'name': 'Test Track',
      });

      final restored = WeatherData.fromCacheJson(weather.toJson());

      expect(restored.temperature, 24.6);
      expect(restored.humidity, 58);
      expect(restored.description, 'Sunny');
      expect(restored.feelsLike, 25.1);
      expect(restored.pressure, 1012);
      expect(restored.visibility, 9000);
      expect(restored.windSpeed, 2.4);
      expect(restored.windDirection, 120);
      expect(restored.cloudiness, 15);
      expect(restored.cityName, 'Test Track');
    });
  });
}
