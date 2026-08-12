import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/models/saved_setting.dart';
import 'package:rc_setting_manager/services/xml_data_codec.dart';
import 'package:xml/xml.dart';

void main() {
  test('保存済み設定は旧形式どおり数値をdouble優先で復元する', () {
    expect(XmlDataCodec.parseSavedSettingValue('1'), 1.0);
    expect(XmlDataCodec.parseSavedSettingValue('1'), isA<double>());
    expect(XmlDataCodec.parseSavedSettingValue('1.5'), 1.5);
    expect(XmlDataCodec.parseSavedSettingValue('TRUE'), isTrue);
    expect(XmlDataCodec.parseSavedSettingValue('soft'), 'soft');
  });

  test('走行ログ変更値は旧形式どおり整数をint優先で復元する', () {
    expect(XmlDataCodec.parseRunChangeValue('1'), 1);
    expect(XmlDataCodec.parseRunChangeValue('1'), isA<int>());
    expect(XmlDataCodec.parseRunChangeValue('1.5'), 1.5);
    expect(XmlDataCodec.parseRunChangeValue('false'), isFalse);
    expect(XmlDataCodec.parseRunChangeValue('soft'), 'soft');
  });

  test('任意数値、空文字、旧kindの既定値を従来どおり変換する', () {
    expect(XmlDataCodec.parseOptionalDouble(' 23,5 '), 23.5);
    expect(XmlDataCodec.parseOptionalDouble(''), isNull);
    expect(XmlDataCodec.parseOptionalDouble('unknown'), isNull);
    expect(XmlDataCodec.emptyToNull(null), isNull);
    expect(XmlDataCodec.emptyToNull(''), isNull);
    expect(XmlDataCodec.emptyToNull(' '), ' ');
    expect(
      XmlDataCodec.parseSavedSettingKind('runResult'),
      SavedSettingKind.runResult,
    );
    expect(
      XmlDataCodec.parseSavedSettingKind('unknown'),
      SavedSettingKind.manual,
    );
    expect(XmlDataCodec.parseSavedSettingKind(null), SavedSettingKind.manual);
  });

  test('XML入力サイズとルート要素をサービス外で検証できる', () {
    expect(
      () => XmlImportValidator.validateContentLength('abc', 2),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'XMLデータは5 MiB以下にしてください。',
        ),
      ),
    );
    expect(
      () => XmlImportValidator.validateRoot(
        XmlDocument.parse('<invalid />').rootElement,
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          'Exception: Invalid XML format: Root element must be '
              'RCCarSettingsData',
        ),
      ),
    );
    expect(
      () => XmlImportValidator.validateRoot(
        XmlDocument.parse('<RCCarSettingsData />').rootElement,
      ),
      returnsNormally,
    );
  });
}
