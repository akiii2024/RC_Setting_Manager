import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_security_service.dart';

abstract interface class AppModePreferencesRepository {
  Future<bool?> loadPreferredOnline();

  Future<bool> savePreferredOnline(
    bool value, {
    bool Function()? shouldWrite,
  });
}

typedef AppModeSharedPreferencesLoader = Future<SharedPreferences> Function();
typedef AppModeSharedPreferencesWriter = Future<bool> Function(
  SharedPreferences preferences,
  String key,
  bool value,
);
typedef AppModeSharedPreferencesReloader = Future<void> Function(
  SharedPreferences preferences,
);

class SharedPreferencesAppModePreferencesRepository
    implements AppModePreferencesRepository {
  SharedPreferencesAppModePreferencesRepository({
    AppModeSharedPreferencesLoader? preferencesLoader,
    AppModeSharedPreferencesWriter? preferencesWriter,
    AppModeSharedPreferencesReloader? preferencesReloader,
  })  : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
        _preferencesWriter = preferencesWriter ??
            ((preferences, key, value) => preferences.setBool(key, value)),
        _preferencesReloader =
            preferencesReloader ?? ((preferences) => preferences.reload());

  final AppModeSharedPreferencesLoader _preferencesLoader;
  final AppModeSharedPreferencesWriter _preferencesWriter;
  final AppModeSharedPreferencesReloader _preferencesReloader;

  @override
  Future<bool?> loadPreferredOnline() async {
    final preferences = await _preferencesLoader();
    if (!preferences.containsKey(AppModeProvider.onlineModePrefKey)) {
      return null;
    }
    return preferences.getBool(AppModeProvider.onlineModePrefKey);
  }

  @override
  Future<bool> savePreferredOnline(
    bool value, {
    bool Function()? shouldWrite,
  }) async {
    final preferences = await _preferencesLoader();
    if (shouldWrite != null && !shouldWrite()) {
      return true;
    }
    late final bool didSave;
    try {
      didSave = await _preferencesWriter(
        preferences,
        AppModeProvider.onlineModePrefKey,
        value,
      );
    } catch (error, stackTrace) {
      await _restoreCache(preferences, saveFailure: error);
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (!didSave) {
      await _restoreCache(
        preferences,
        saveFailure: StateError('App mode preference writer returned false.'),
      );
    }
    return didSave;
  }

  Future<void> _restoreCache(
    SharedPreferences preferences, {
    required Object saveFailure,
  }) async {
    try {
      await _preferencesReloader(preferences);
    } catch (reloadError, reloadStackTrace) {
      Error.throwWithStackTrace(
        StateError(
          'Failed to restore the SharedPreferences cache after an online '
          'mode save failure ($saveFailure): $reloadError',
        ),
        reloadStackTrace,
      );
    }
  }
}

/// アプリのオンラインモードと Firebase 初期化状態を管理する。
class AppModeProvider extends ChangeNotifier {
  static const String onlineModePrefKey = 'online_mode';

  bool? _preferredOnline;
  bool _isFirebaseReady;
  bool _isInitializingFirebase;
  Future<void> _operationQueue = Future<void>.value();
  var _operationGeneration = 0;
  var _isDisposed = false;

  AppModeProvider({
    required bool? preferredOnline,
    required bool isFirebaseReady,
    bool isInitializingFirebase = false,
    this.onlineCapabilityEnabled = true,
    AppModePreferencesRepository? preferencesRepository,
  })  : _preferredOnline = preferredOnline,
        _isFirebaseReady = isFirebaseReady,
        _isInitializingFirebase = isInitializingFirebase,
        _preferencesRepository = preferencesRepository ??
            SharedPreferencesAppModePreferencesRepository();

  /// このビルドでオンライン機能を提供するか。
  final bool onlineCapabilityEnabled;
  final AppModePreferencesRepository _preferencesRepository;

  bool? get preferredOnline => _preferredOnline;
  bool get isFirebaseReady => _isFirebaseReady;
  bool get isInitializingFirebase => _isInitializingFirebase;

  /// 利用者の選択と Firebase の準備が揃った場合だけオンライン機能を有効にする。
  bool get isOnlineActive =>
      onlineCapabilityEnabled && _preferredOnline == true && _isFirebaseReady;

  static Future<bool?> loadStoredPreference({
    AppModePreferencesRepository? preferencesRepository,
  }) =>
      (preferencesRepository ?? SharedPreferencesAppModePreferencesRepository())
          .loadPreferredOnline();

  Future<void> setOffline() {
    final generation = ++_operationGeneration;
    return _serializeOperation(() async {
      if (generation != _operationGeneration || _isDisposed) {
        return;
      }

      if (!onlineCapabilityEnabled) {
        _commitOfflineState();
        return;
      }

      final didSave = await _preferencesRepository.savePreferredOnline(
        false,
        shouldWrite: () => generation == _operationGeneration && !_isDisposed,
      );
      if (!didSave) {
        throw StateError('オフラインモード設定の保存に失敗しました。');
      }
      if (generation != _operationGeneration || _isDisposed) {
        return;
      }

      _commitOfflineState();
    });
  }

  Future<void> setOnlineAndInit() {
    final generation = ++_operationGeneration;
    return _serializeOperation(() async {
      if (generation != _operationGeneration || _isDisposed) {
        return;
      }

      // オフライン専用ビルドでは保存済みの選択を変更しない。
      if (!onlineCapabilityEnabled) {
        _commitOfflineState();
        return;
      }

      _isInitializingFirebase = true;
      _notifyListenersIfActive();

      try {
        await _initializeFirebaseIfNeeded();
        if (generation != _operationGeneration || _isDisposed) {
          return;
        }

        final didSave = await _preferencesRepository.savePreferredOnline(
          true,
          shouldWrite: () => generation == _operationGeneration && !_isDisposed,
        );
        if (!didSave) {
          throw StateError('オンラインモード設定の保存に失敗しました。');
        }
        if (generation != _operationGeneration || _isDisposed) {
          return;
        }

        _preferredOnline = true;
        _isFirebaseReady = true;
      } finally {
        _isInitializingFirebase = false;
        _notifyListenersIfActive();
      }
    });
  }

  Future<void> _serializeOperation(Future<void> Function() operation) {
    final result = _operationQueue.then((_) => operation());
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  void _commitOfflineState() {
    final didChange = _preferredOnline != false ||
        _isFirebaseReady ||
        _isInitializingFirebase;
    _preferredOnline = false;
    _isFirebaseReady = false;
    _isInitializingFirebase = false;
    if (didChange) {
      _notifyListenersIfActive();
    }
  }

  void _notifyListenersIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _initializeFirebaseIfNeeded() async {
    await FirebaseSecurityService.ensureReady();
    FirebaseAuth.instance;
    FirebaseFirestore.instance;
  }

  @override
  void dispose() {
    _isDisposed = true;
    ++_operationGeneration;
    super.dispose();
  }
}
