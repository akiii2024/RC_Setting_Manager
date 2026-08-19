import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/services/auth_service.dart';

void main() {
  test('dispose cancels auth changes and prevents notifications afterwards',
      () async {
    final authChanges = StreamController<User?>.broadcast(sync: true);
    final service = AuthService(authStateChanges: authChanges.stream);
    var notificationCount = 0;
    service.addListener(() => notificationCount++);

    authChanges.add(null);
    expect(notificationCount, 1);
    expect(authChanges.hasListener, isTrue);

    service.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(authChanges.hasListener, isFalse);

    authChanges.add(null);
    expect(notificationCount, 1);

    service.dispose();
    await authChanges.close();
  });
}
