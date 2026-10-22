import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/utils/external_url_launcher.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.aki.rcsettings/external_links');

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('opens an HTTPS hyperlink using the native browser channel', () async {
    MethodCall? received;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      received = call;
      return null;
    });
    await openWebUrl('https://openweathermap.org/');
    expect(received?.method, 'openUrl');
    expect(received?.arguments, {'url': 'https://openweathermap.org/'});
  });

  test('browser failures propagate so the UI can offer a retry', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    await expectLater(openWebUrl('https://openweathermap.org/'),
        throwsA(isA<PlatformException>()));
  });
}
