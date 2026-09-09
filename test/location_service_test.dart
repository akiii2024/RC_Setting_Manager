import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rc_setting_manager/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/geolocator');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = LocationService.instance;
  late List<String> calls;
  late bool enabled;
  late LocationPermission permission;
  late LocationPermission requestedPermission;
  Completer<int>? permissionResult;
  PlatformException? positionError;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls = [];
    enabled = true;
    permission = LocationPermission.denied;
    requestedPermission = LocationPermission.whileInUse;
    permissionResult = null;
    positionError = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isLocationServiceEnabled':
          return enabled;
        case 'checkPermission':
          return permission.index;
        case 'requestPermission':
          return permissionResult == null
              ? requestedPermission.index
              : await permissionResult!.future;
        case 'getCurrentPosition':
          if (positionError != null) throw positionError!;
          return {'latitude': 35.0, 'longitude': 139.0};
        default:
          throw MissingPluginException(call.method);
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS first use requests permission before fetching coordinates',
      () async {
    final position = await service.determineCurrentPosition();
    expect(position.latitude, 35.0);
    expect(position.longitude, 139.0);
    expect(calls, [
      'isLocationServiceEnabled',
      'checkPermission',
      'requestPermission',
      'getCurrentPosition',
    ]);
  });

  test('concurrent location requests share one permission and position request',
      () async {
    final results = await Future.wait([
      service.determineCurrentPosition(),
      service.determineCurrentPosition(),
    ]);
    expect(results[0], results[1]);
    expect(
        calls.where((method) => method == 'requestPermission'), hasLength(1));
    expect(
        calls.where((method) => method == 'getCurrentPosition'), hasLength(1));

    await service.determineCurrentPosition();
    expect(
        calls.where((method) => method == 'getCurrentPosition'), hasLength(2));
  });

  test('concurrent permission checks share the pending iOS dialog', () async {
    permissionResult = Completer<int>();
    final first = service.requestLocationPermission();
    final second = service.requestLocationPermission();
    permissionResult!.complete(LocationPermission.whileInUse.index);
    expect(await Future.wait([first, second]), [true, true]);
    expect(calls, ['checkPermission', 'requestPermission']);
  });

  test('disabled location services do not request permission', () async {
    enabled = false;
    await expectLater(
      service.determineCurrentPosition(),
      throwsA(isA<LocationException>().having(
        (error) => error.status,
        'status',
        LocationStatus.serviceDisabled,
      )),
    );
    expect(await service.getLocationStatus(), LocationStatus.serviceDisabled);
    expect(calls, ['isLocationServiceEnabled', 'isLocationServiceEnabled']);
  });

  for (final denied in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
  ]) {
    test('denied permission ($denied) can recover after settings change',
        () async {
      permission = denied;
      requestedPermission = LocationPermission.denied;
      await expectLater(
        service.determineCurrentPosition(),
        throwsA(isA<LocationException>().having(
          (error) => error.status,
          'status',
          LocationStatus.permissionDenied,
        )),
      );
      expect(calls, isNot(contains('getCurrentPosition')));
      if (denied == LocationPermission.deniedForever) {
        expect(calls, isNot(contains('requestPermission')));
      }
      permission = LocationPermission.whileInUse;
      expect((await service.determineCurrentPosition()).latitude, 35.0);
    });
  }

  test('a failed shared position request can be retried', () async {
    permission = LocationPermission.whileInUse;
    positionError = PlatformException(code: 'POSITION_UNAVAILABLE');
    final first = service.determineCurrentPosition();
    final second = service.determineCurrentPosition();
    final failure = throwsA(isA<LocationException>().having(
      (error) => error.status,
      'status',
      LocationStatus.unavailable,
    ));
    await Future.wait(
        [expectLater(first, failure), expectLater(second, failure)]);
    positionError = null;
    expect((await service.determineCurrentPosition()).latitude, 35.0);
    expect(
        calls.where((method) => method == 'getCurrentPosition'), hasLength(2));
  });
}
