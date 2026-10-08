import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/utils/app_metadata.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the version from the project pubspec', () async {
    final source = await File('pubspec.yaml').readAsString();
    expect(await AppMetadata.loadVersion(), AppMetadata.parseVersion(source));
  });

  test('follows future version updates with build numbers', () {
    expect(AppMetadata.parseVersion('version: 1.2.3+42\n'), '1.2.3+42');
    expect(AppMetadata.parseVersion("version: '1.2.3+42' # release\n"),
        '1.2.3+42');
  });

  test('parsing fails when the pubspec has no version', () {
    expect(
      () => AppMetadata.parseVersion('name: rc_setting_manager\n'),
      throwsA(isA<StateError>()),
    );
    expect(
      () => AppMetadata.parseVersion('version:\nname: rc_setting_manager\n'),
      throwsA(isA<StateError>()),
    );
  });
}
