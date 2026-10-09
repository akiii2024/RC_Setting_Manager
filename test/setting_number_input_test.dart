import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/utils/setting_number_input.dart';

void main() {
  test('全角の数字・小数点・符号・空白をASCIIへ正規化する', () {
    expect(normalizeSettingNumberInput('　２．５　'), '2.5');
    expect(normalizeSettingNumberInput('＋２．５'), '+2.5');
    expect(normalizeSettingNumberInput('－２'), '-2');
    expect(normalizeSettingNumberInput('−２'), '-2');
    expect(normalizeSettingNumberInput('ー2'), 'ー2');
  });

  test('キャンバーの符号なし入力だけをネガティブとして解釈する', () {
    for (final key in ['frontCamber', 'rearCamberAngle']) {
      expect(parseSettingNumberInput(key, '2'), -2);
      expect(parseSettingNumberInput(key, ' 2.5 '), -2.5);
      expect(parseSettingNumberInput(key, '２．５'), -2.5);
      expect(parseSettingNumberInput(key, '＋２．５'), 2.5);
      expect(parseSettingNumberInput(key, '－２'), -2);
      expect(parseSettingNumberInput(key, '−２'), -2);
      expect(parseSettingNumberInput(key, '+2'), 2);
      expect(parseSettingNumberInput(key, '-2'), -2);
      expect(parseSettingNumberInput(key, '0'), 0);
      expect(parseSettingNumberInput(key, '+0'), 0);
      expect(parseSettingNumberInput(key, '-0'), 0);
      expect(parseSettingNumberInput(key, '.5'), -0.5);
      expect(parseSettingNumberInput(key, '2e-1'), -0.2);
      expect(parseSettingNumberInput(key, '+2e-1'), 0.2);
      expect(parseSettingNumberInput(key, '＋２ｅ−１'), isNull);
      expect(parseSettingNumberInput(key, '+'), isNull);
      expect(parseSettingNumberInput(key, '-'), isNull);
      expect(parseSettingNumberInput(key, 'ー2'), isNull);
      expect(parseSettingNumberInput(key, 'abc'), isNull);
    }
  });

  test('車高などの他の数値入力とキャンバー関連の別項目には影響しない', () {
    for (final key in ['frontRideHeight', 'frontToeAngle', 'frontCamberLink']) {
      expect(parseSettingNumberInput(key, '2'), 2);
      expect(parseSettingNumberInput(key, '２．５'), 2.5);
      expect(parseSettingNumberInput(key, '+2'), 2);
      expect(parseSettingNumberInput(key, '-2'), -2);
      expect(formatSettingNumberInput(key, 2), '2');
    }
  });

  test('トーの設定キー判定は対象キーだけを符号付き角度として扱う', () {
    for (final key in [
      'frontToe',
      'rearToe',
      'toeAngle',
      'frontToeAngle',
      'rearToeAngle',
    ]) {
      expect(isToeSettingKey(key), isTrue);
      expect(isSignedAngleSettingKey(key), isTrue);
    }
    for (final key in ['toeLink', 'toeAngleNote']) {
      expect(isToeSettingKey(key), isFalse);
      expect(isSignedAngleSettingKey(key), isFalse);
    }
  });

  test('キャンバーも共通の符号付き角度として判定する', () {
    expect(isToeSettingKey('frontCamber'), isFalse);
    expect(isSignedAngleSettingKey('frontCamber'), isTrue);
  });

  test('トーの符号なし入力は従来どおりプラスとして解釈する', () {
    for (final key in ['frontToe', 'rearToeAngle']) {
      expect(parseSettingNumberInput(key, '2'), 2);
      expect(parseSettingNumberInput(key, '２．５'), 2.5);
      expect(parseSettingNumberInput(key, '+2'), 2);
      expect(parseSettingNumberInput(key, '-2'), -2);
    }
  });
  test('保存値の符号を再編集と表示の往復で維持する', () {
    for (final key in ['frontCamber', 'rearCamberAngle']) {
      for (final value in [-2.5, 0.0, 2.5]) {
        final displayed = formatSettingNumberInput(key, value);
        expect(parseSettingNumberInput(key, displayed), value);
      }
      expect(formatSettingNumberInput(key, 2), '+2');
      expect(formatSettingNumberInput(key, '２．０'), '+2.0');
      expect(formatSettingNumberInput(key, '＋２．０'), '+2.0');
      expect(formatSettingNumberInput(key, '2.0'), '+2.0');
      expect(formatSettingNumberInput(key, '+2.0'), '+2.0');
      expect(formatSettingNumberInput(key, -2), '-2');
      expect(formatSettingNumberInput(key, null), '0');
    }
  });
}
