import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rc_setting_manager/services/setting_draft_service.dart';

Map<String, dynamic> draft(String name) => {
      'settings': {'motor': '17.5T'},
      'name': name,
      'trackName': 'Circuit',
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('debounces changes and persists only the latest draft',
      (tester) async {
    final service = SettingDraftService('car', 'setting');
    service.schedule(draft('first'));
    await tester.pump(const Duration(milliseconds: 400));
    service.schedule(draft('latest'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(await service.read(), isNull);
    await tester.pump(const Duration(milliseconds: 200));
    expect((await service.read())?['name'], 'latest');
  });

  test('flush preserves changes when leaving before debounce completes',
      () async {
    final service = SettingDraftService('car', null);
    service.schedule(draft('new'));
    await service.flush();
    expect(await SettingDraftService('car', null).read(), draft('new'));
    expect(await SettingDraftService('other', null).read(), isNull);
    expect(await SettingDraftService('car', 'id').read(), isNull);
  });

  test('clear cancels pending and queued writes', () async {
    final service = SettingDraftService('car', 'id');
    service.schedule(draft('queued'));
    final write = service.flush();
    service.schedule(draft('pending'));
    await service.clear();
    await write;
    await service.flush();
    expect(await service.read(), isNull);
  });

  test('invalid drafts leave saved data intact', () async {
    final service = SettingDraftService('car', 'id');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(service.key, '{broken');
    await prefs.setString('saved_settings', 'unchanged');
    expect(await service.read(), isNull);
    expect(prefs.getString('saved_settings'), 'unchanged');
  });

  test('invalid drafts do not interrupt a pending valid draft', () async {
    final service = SettingDraftService('car', 'id');
    expect(service.schedule(draft('valid')), isTrue);
    expect(service.schedule({...draft('invalid'), 'value': double.infinity}),
        isFalse);
    await service.flush();
    expect((await service.read())?['name'], 'valid');
  });

  test(
      'invalid drafts do not overwrite a saved draft and later valid changes resume',
      () async {
    final service = SettingDraftService('car', 'id');
    expect(service.schedule(draft('saved')), isTrue);
    await service.flush();

    for (final invalid in <Map<String, dynamic>>[
      {...draft('infinity'), 'value': double.infinity},
      {...draft('nan'), 'value': double.nan},
      {...draft('unsupported'), 'value': Object()},
    ]) {
      expect(service.schedule(invalid), isFalse);
    }
    expect((await service.read())?['name'], 'saved');

    expect(service.schedule(draft('updated')), isTrue);
    await service.flush();
    expect((await service.read())?['name'], 'updated');
  });
}
