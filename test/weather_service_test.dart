import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/services/weather_service.dart';

void main() {
  group('Weather service diagnostics', () {
    final cases = <(String, String, String)>[
      ('firebase_app_check', 'missing-site-key', 'Web版のアクセス検証設定が不足'),
      ('firebase_auth', 'operation-not-allowed', '天気サービスの認証に失敗'),
      ('firebase_app_check', 'recaptcha-error', 'アクセス検証に失敗'),
      ('cloud_functions', 'unauthenticated', 'アクセス検証に失敗'),
      ('cloud_functions', 'failed-precondition', '天気サービスの設定確認が必要'),
      ('cloud_functions', 'not-found', '天気サービスの設定確認が必要'),
      ('cloud_functions', 'resource-exhausted', '利用上限に達しました'),
      ('cloud_functions', 'internal', '天気サービスの処理に失敗'),
    ];
    for (final (plugin, code, expected) in cases) {
      test('$plugin/$code is distinguishable without developer tools', () {
        final error = WeatherException.fromServiceError(FirebaseException(
          plugin: plugin,
          code: code,
          message: 'private response payload',
        ));
        expect(error.status, WeatherStatus.serviceError);
        expect(error.serviceFailureMessage(false), contains(expected));
        expect(error.serviceFailureMessage(false), contains('$plugin/$code'));
        expect(error.serviceFailureMessage(true), contains('$plugin/$code'));
        expect(error.serviceFailureMessage(false), isNot(contains('private')));
        expect(error.toString(), isNot(contains('private')));
      });
    }

    test('unknown failures are not claimed to be network failures', () {
      final error = WeatherException.fromServiceError(StateError('private'));
      expect(error.diagnosticCode, 'weather/unexpected-error');
      expect(error.serviceFailureMessage(false), isNot(contains('通信状態')));
      expect(error.serviceFailureMessage(false), isNot(contains('private')));
    });

    test('location failures keep their existing separate explanation', () {
      expect(
        WeatherException('denied', WeatherStatus.locationPermissionDenied)
            .serviceFailureMessage(false),
        isNull,
      );
    });
  });

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
