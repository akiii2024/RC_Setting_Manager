import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/utils/platform_detection.dart';

void main() {
  group('isIOSWebPlatform', () {
    test('iOS browser is detected', () {
      expect(
        isIOSWebPlatform(
          isWeb: true,
          platform: TargetPlatform.iOS,
        ),
        isTrue,
      );
    });

    test('Android browser is not detected as iOS', () {
      expect(
        isIOSWebPlatform(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });

    test('native iOS is outside the PWA restriction', () {
      expect(
        isIOSWebPlatform(
          isWeb: false,
          platform: TargetPlatform.iOS,
        ),
        isFalse,
      );
    });
  });
}
