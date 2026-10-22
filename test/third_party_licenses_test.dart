import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/app/third_party_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled supplemental and font licenses are readable in the registry',
      () async {
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    registerThirdPartyLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    String textFor(String package) => entries
        .where((entry) => entry.packages.contains(package))
        .expand((entry) => entry.paragraphs)
        .map((paragraph) => paragraph.text)
        .join('\n');

    for (final font in ['Noto Sans JP', 'Inter', 'Space Grotesk']) {
      expect(textFor(font), contains('SIL OPEN FONT LICENSE'));
      expect(textFor(font), contains('Copyright'));
    }
    expect(textFor('image'), contains('notmasteryet'));
    expect(textFor('image'), contains('Apache Batik'));
    expect(textFor('image'), contains('TERMS AND CONDITIONS'));
    expect(textFor('archive'), contains('imaya'));
    expect(textFor('archive'), contains('JCraft'));
    expect(textFor('archive'), contains('Julian R Seward'));
    expect(textFor('Android native SDKs'),
        contains('com.google.firebase:firebase-firestore:'));
    expect(textFor('Android native SDKs'),
        contains('androidx.media3:media3-exoplayer:'));
    expect(textFor('Android native SDKs'),
        contains('Play Integrity API Terms of Service'));
  });
}
