import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/app/app_bootstrap.dart';
import 'package:rc_setting_manager/app/app_error_view.dart';
import 'package:rc_setting_manager/providers/app_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppModeProvider', () {
    test('オンライン選択とFirebase準備が揃った場合だけ有効になる', () {
      final offline = AppModeProvider(
        preferredOnline: false,
        isFirebaseReady: true,
      );
      final unready = AppModeProvider(
        preferredOnline: true,
        isFirebaseReady: false,
      );
      final online = AppModeProvider(
        preferredOnline: true,
        isFirebaseReady: true,
      );
      final offlineOnlyBuild = AppModeProvider(
        preferredOnline: true,
        isFirebaseReady: true,
        onlineCapabilityEnabled: false,
      );
      addTearDown(offline.dispose);
      addTearDown(unready.dispose);
      addTearDown(online.dispose);
      addTearDown(offlineOnlyBuild.dispose);

      expect(offline.isOnlineActive, isFalse);
      expect(unready.isOnlineActive, isFalse);
      expect(online.isOnlineActive, isTrue);
      expect(offlineOnlyBuild.isOnlineActive, isFalse);
    });

    test('オフライン専用ビルドは保存済みオンライン選択を上書きしない', () async {
      SharedPreferences.setMockInitialValues({
        AppModeProvider.onlineModePrefKey: true,
      });
      final mode = AppModeProvider(
        preferredOnline: false,
        isFirebaseReady: false,
        onlineCapabilityEnabled: false,
      );
      addTearDown(mode.dispose);

      await mode.setOnlineAndInit();
      await mode.setOffline();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppModeProvider.onlineModePrefKey), isTrue);
      expect(mode.preferredOnline, isFalse);
      expect(mode.isOnlineActive, isFalse);
    });

    test('online_mode false result restores polluted cache and live state',
        () async {
      const key = AppModeProvider.onlineModePrefKey;
      SharedPreferences.setMockInitialValues({key: true});
      final originalPreferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesAppModePreferencesRepository(
        preferencesWriter: (preferences, key, value) async {
          await preferences.setBool(key, value);
          SharedPreferences.setMockInitialValues({key: true});
          return false;
        },
      );
      final mode = AppModeProvider(
        preferredOnline: true,
        isFirebaseReady: true,
        preferencesRepository: repository,
      );
      addTearDown(mode.dispose);
      var notificationCount = 0;
      mode.addListener(() => notificationCount++);

      await expectLater(mode.setOffline(), throwsStateError);

      expect(mode.preferredOnline, isTrue);
      expect(mode.isFirebaseReady, isTrue);
      expect(mode.isOnlineActive, isTrue);
      expect(notificationCount, 0);
      expect(originalPreferences.getBool(key), isTrue);
      expect(await AppModeProvider.loadStoredPreference(), isTrue);
    });

    test('online_mode exception restores polluted cache and live state',
        () async {
      const key = AppModeProvider.onlineModePrefKey;
      SharedPreferences.setMockInitialValues({key: true});
      final originalPreferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesAppModePreferencesRepository(
        preferencesWriter: (preferences, key, value) async {
          await preferences.setBool(key, value);
          SharedPreferences.setMockInitialValues({key: true});
          throw StateError('simulated platform exception');
        },
      );
      final mode = AppModeProvider(
        preferredOnline: true,
        isFirebaseReady: true,
        preferencesRepository: repository,
      );
      addTearDown(mode.dispose);
      var notificationCount = 0;
      mode.addListener(() => notificationCount++);

      await expectLater(mode.setOffline(), throwsStateError);

      expect(mode.preferredOnline, isTrue);
      expect(mode.isFirebaseReady, isTrue);
      expect(mode.isOnlineActive, isTrue);
      expect(notificationCount, 0);
      expect(originalPreferences.getBool(key), isTrue);
      expect(await AppModeProvider.loadStoredPreference(), isTrue);
    });

    test('online_mode cache reload failure is explicit and state stays intact',
        () async {
      SharedPreferences.setMockInitialValues({
        AppModeProvider.onlineModePrefKey: true,
      });
      final repository = SharedPreferencesAppModePreferencesRepository(
        preferencesWriter: (preferences, key, value) async => false,
        preferencesReloader: (preferences) =>
            Future<void>.error(StateError('reload failed')),
      );
      final mode = AppModeProvider(
        preferredOnline: true,
        isFirebaseReady: true,
        preferencesRepository: repository,
      );
      addTearDown(mode.dispose);
      var notificationCount = 0;
      mode.addListener(() => notificationCount++);

      await expectLater(
        mode.setOffline(),
        throwsA(
          isA<StateError>().having(
            (error) => '$error',
            'message',
            contains('restore'),
          ),
        ),
      );

      expect(mode.preferredOnline, isTrue);
      expect(mode.isFirebaseReady, isTrue);
      expect(mode.isOnlineActive, isTrue);
      expect(notificationCount, 0);
    });
  });

  group('ApplicationBootstrap', () {
    testWidgets('初期化失敗後のRetryで依存ツリーだけを再生成する', (tester) async {
      var factoryCallCount = 0;
      final successfulSession = _FakeBootstrapSession('ready');
      final retryResult = Completer<ApplicationBootstrapSession>();

      Future<ApplicationBootstrapSession> factory() async {
        factoryCallCount++;
        if (factoryCallCount == 1) {
          throw StateError('first initialization failed');
        }
        return retryResult.future;
      }

      await tester.pumpWidget(
        ApplicationBootstrap(sessionFactory: factory),
      );
      await tester.pumpAndSettle();

      expect(find.text('Application failed to start.'), findsOneWidget);
      expect(factoryCallCount, 1);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      retryResult.complete(successfulSession);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('session-ready')), findsOneWidget);
      expect(factoryCallCount, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(successfulSession.disposeCount, 1);
    });

    testWidgets('Retry時に旧セッションを破棄して新しい世代へ置き換える', (tester) async {
      final firstSession = _FakeBootstrapSession('first');
      final secondSession = _FakeBootstrapSession('second');
      final sessions = <ApplicationBootstrapSession>[
        firstSession,
        secondSession,
      ];
      final retryResult = Completer<ApplicationBootstrapSession>();
      var factoryCallCount = 0;

      Future<ApplicationBootstrapSession> factory() {
        factoryCallCount++;
        if (factoryCallCount == 1) {
          return Future.value(sessions.first);
        }
        return retryResult.future;
      }

      await tester.pumpWidget(
        ApplicationBootstrap(sessionFactory: factory),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('session-first')), findsOneWidget);

      await tester.tap(find.byKey(const Key('session-retry')));
      await tester.pump();

      expect(firstSession.disposeCount, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      retryResult.complete(sessions.last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('session-second')), findsOneWidget);
      expect(factoryCallCount, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(firstSession.disposeCount, 1);
      expect(secondSession.disposeCount, 1);
    });

    testWidgets('Retryの新しい依存生成は旧セッション破棄後に開始する', (tester) async {
      final events = <String>[];
      final firstSession = _FakeBootstrapSession(
        'first',
        onDispose: () => events.add('dispose-first'),
      );
      final secondSession = _FakeBootstrapSession('second');
      final secondResult = Completer<ApplicationBootstrapSession>();
      var factoryCallCount = 0;

      Future<ApplicationBootstrapSession> factory() {
        factoryCallCount++;
        events.add('factory-$factoryCallCount');
        return factoryCallCount == 1
            ? Future.value(firstSession)
            : secondResult.future;
      }

      await tester.pumpWidget(
        ApplicationBootstrap(sessionFactory: factory),
      );
      await tester.pumpAndSettle();

      firstSession.retry!();
      expect(factoryCallCount, 1);
      expect(firstSession.disposeCount, 0);

      await tester.pump();
      expect(
        events,
        ['factory-1', 'dispose-first', 'factory-2'],
      );

      secondResult.complete(secondSession);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('session-second')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(secondSession.disposeCount, 1);
    });

    testWidgets('旧セッションのRetry callbackを無視する', (tester) async {
      final firstSession = _FakeBootstrapSession('first');
      final secondSession = _FakeBootstrapSession('second');
      final retryResult = Completer<ApplicationBootstrapSession>();
      var factoryCallCount = 0;

      Future<ApplicationBootstrapSession> factory() {
        factoryCallCount++;
        return factoryCallCount == 1
            ? Future.value(firstSession)
            : retryResult.future;
      }

      await tester.pumpWidget(
        ApplicationBootstrap(sessionFactory: factory),
      );
      await tester.pumpAndSettle();

      final retry = firstSession.retry!;
      retry();
      await tester.pump();
      retry();

      expect(firstSession.disposeCount, 1);
      expect(factoryCallCount, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      retryResult.complete(secondSession);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('session-second')), findsOneWidget);
      expect(factoryCallCount, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(secondSession.disposeCount, 1);
    });

    testWidgets('破棄後に完了した初期化セッションを直ちに破棄する', (tester) async {
      final pendingResult = Completer<ApplicationBootstrapSession>();
      final lateSession = _FakeBootstrapSession('late');

      await tester.pumpWidget(
        ApplicationBootstrap(sessionFactory: () => pendingResult.future),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      pendingResult.complete(lateSession);
      await tester.pump();

      expect(lateSession.disposeCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Provider subtreeの破棄後に所有セッションを破棄する', (tester) async {
      final disposeEvents = <String>[];
      final session = _OrderingBootstrapSession(disposeEvents);

      await tester.pumpWidget(
        ApplicationBootstrap(
          sessionFactory: () async => session,
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());

      expect(disposeEvents, ['child', 'session']);
    });
  });

  testWidgets('global error fallback is safe under unbounded constraints',
      (tester) async {
    final details = FlutterErrorDetails(
      exception: StateError('broken child'),
      stack: StackTrace.current,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          children: [AppErrorView.build(details)],
        ),
      ),
    );

    expect(find.text('An unexpected UI error occurred.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeBootstrapSession implements ApplicationBootstrapSession {
  _FakeBootstrapSession(this.name, {this.onDispose});

  final String name;
  final VoidCallback? onDispose;
  var disposeCount = 0;
  VoidCallback? retry;

  @override
  Widget build(VoidCallback onRetry) {
    retry = onRetry;
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text(name, key: Key('session-$name')),
            ElevatedButton(
              key: const Key('session-retry'),
              onPressed: onRetry,
              child: const Text('retry session'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    disposeCount++;
    onDispose?.call();
  }
}

class _OrderingBootstrapSession implements ApplicationBootstrapSession {
  _OrderingBootstrapSession(this.disposeEvents);

  final List<String> disposeEvents;

  @override
  Widget build(VoidCallback onRetry) {
    return MaterialApp(
      home: _DisposeProbe(
        onDispose: () => disposeEvents.add('child'),
      ),
    );
  }

  @override
  void dispose() {
    disposeEvents.add('session');
  }
}

class _DisposeProbe extends StatefulWidget {
  const _DisposeProbe({required this.onDispose});

  final VoidCallback onDispose;

  @override
  State<_DisposeProbe> createState() => _DisposeProbeState();
}

class _DisposeProbeState extends State<_DisposeProbe> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}
