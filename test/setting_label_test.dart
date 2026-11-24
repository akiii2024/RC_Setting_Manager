import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/data/car_settings_definitions.dart';
import 'package:rc_setting_manager/domain/settings/display_settings_store.dart';
import 'package:rc_setting_manager/domain/settings/setting_label_mode.dart';
import 'package:rc_setting_manager/models/car_setting_definition.dart';
import 'package:rc_setting_manager/utils/setting_label.dart';

SettingItem _item({String? labelEn}) => SettingItem(
      key: 'frontGroundClearance',
      type: 'number',
      category: 'front',
      label: '車高',
      labelEn: labelEn,
    );

void main() {
  test('表記モードの既定値は自動', () {
    expect(DisplaySettingsStore().settingLabelMode, SettingLabelMode.auto);
  });

  test('UI 言語と表記モードに従い、英語表記がなければ日本語を使う', () {
    const en = 'Ride Height';
    const ja = '車高';
    for (final (mode, isEnglish, expected) in [
      (SettingLabelMode.auto, false, ja),
      (SettingLabelMode.auto, true, en),
      (SettingLabelMode.japanese, false, ja),
      (SettingLabelMode.japanese, true, ja),
      (SettingLabelMode.english, false, en),
      (SettingLabelMode.english, true, en),
    ]) {
      expect(
        resolveSettingLabel(_item(labelEn: en),
            isEnglish: isEnglish, mode: mode),
        expected,
        reason: '$mode / $isEnglish',
      );
      expect(
        resolveSettingLabel(_item(), isEnglish: isEnglish, mode: mode),
        ja,
        reason: '$mode / $isEnglish',
      );
    }
  });

  test('英語表記付きの SettingItem を JSON で往復する', () {
    final json = _item(labelEn: 'Ride Height').toJson();
    expect(json['labelEn'], 'Ride Height');
    final item = SettingItem.fromJson(json);
    expect(item.labelEn, 'Ride Height');
    expect(item.toJson(), json);
  });

  test('英語表記のない既存 JSON を読み込み、再保存時もキーを省略する', () {
    final json = _item().toJson();
    expect(json, isNot(contains('labelEn')));
    final item = SettingItem.fromJson(json);
    expect(item.labelEn, isNull);
    expect(item.toJson(), json);
  });

  test('英語表記を入れた車種は全項目に重複のない英語ラベルを持つ', () {
    final labels = {
      for (final item
          in carSettingsDefinitions['xray/x4_24']!.availableSettings)
        item.key: item.labelEn,
    };
    expect(labels['frontGroundClearance'], 'Front Ride Height');
    expect(labels['rearCamberAngle'], 'Rear Camber');
    expect(labels['frontDroop'], 'Front Downstop');
    expect(labels['rearStabilizer'], 'Rear Anti-roll Bar');
    expect(labels['surface'], 'Track Surface');
    expect(labels['airTemp'], isNull);

    const coveredIds = {
      'xray/x4_24',
      'tamiya/trf420',
      'tamiya/trf420x',
      'tamiya/trf421',
      'tamiya/trf421x',
      'yokomo/bd11',
      'yokomo/bd12',
      'yokomo/ms1_0',
      'yokomo/ms2_0',
    };
    for (final id in coveredIds) {
      final seen = <String>{};
      for (final item in carSettingsDefinitions[id]!.availableSettings) {
        if (item.category == 'basic' || item.category == 'memo') {
          continue;
        }
        final raw = item.labelEn;
        final reason = '$id / ${item.key}';
        if (raw == null) {
          // 原表記が無い項目は日本語ラベルへフォールバックする（仕様）。
          continue;
        }
        final label = raw.trim();
        expect(label, isNotEmpty, reason: reason);
        expect(seen.add(label), isTrue, reason: '$reason (重複: $label)');
      }
    }
  });
}
