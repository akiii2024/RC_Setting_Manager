import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

/// アプリのオンライン/オフラインモードとFirebase初期化状態を管理するプロバイダ
class AppModeProvider extends ChangeNotifier {
  static const String onlineModePrefKey = 'online_mode';

  bool? preferredOnline; // null: 未選択, true: オンライン希望, false: オフライン
  bool isFirebaseReady;
  bool isInitializingFirebase;

  AppModeProvider({
    required this.preferredOnline,
    required this.isFirebaseReady,
    this.isInitializingFirebase = false,
  });

  /// 事前に保存されたモード（存在しない場合はnull）を読み取る
  static Future<bool?> loadStoredPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(onlineModePrefKey)) return null;
    return prefs.getBool(onlineModePrefKey);
  }

  /// オフラインモードを設定（Firebaseは初期化しない）
  Future<void> setOffline() async {
    preferredOnline = false;
    isFirebaseReady = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onlineModePrefKey, false);
    notifyListeners();
  }

  /// オンラインモードを選択し、Firebaseを初期化
  Future<void> setOnlineAndInit() async {
    preferredOnline = true;
    isInitializingFirebase = true;
    notifyListeners();

    try {
      await _initializeFirebaseIfNeeded();
      isFirebaseReady = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(onlineModePrefKey, true);
    } catch (_) {
      // 失敗時は未選択扱いに戻す
      preferredOnline = null;
      rethrow;
    } finally {
      isInitializingFirebase = false;
      notifyListeners();
    }
  }

  Future<void> _initializeFirebaseIfNeeded() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    FirebaseOptions options =
        kIsWeb ? DefaultFirebaseOptions.web : DefaultFirebaseOptions.currentPlatform;

    await Firebase.initializeApp(options: options);

    // インスタンス生成で早期エラーを検知
    FirebaseAuth.instance;
    FirebaseFirestore.instance;
  }
}



