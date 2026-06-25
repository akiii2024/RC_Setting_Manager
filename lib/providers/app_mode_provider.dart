import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_security_service.dart';

/// アプリのオンラインモードと Firebase 初期化状態を管理する。
class AppModeProvider extends ChangeNotifier {
  static const String onlineModePrefKey = 'online_mode';

  bool? preferredOnline;
  bool isFirebaseReady;
  bool isInitializingFirebase;

  AppModeProvider({
    required this.preferredOnline,
    required this.isFirebaseReady,
    this.isInitializingFirebase = false,
  });

  static Future<bool?> loadStoredPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(onlineModePrefKey)) {
      return null;
    }
    return prefs.getBool(onlineModePrefKey);
  }

  Future<void> setOffline() async {
    preferredOnline = false;
    isFirebaseReady = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onlineModePrefKey, false);
    notifyListeners();
  }

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
      preferredOnline = null;
      rethrow;
    } finally {
      isInitializingFirebase = false;
      notifyListeners();
    }
  }

  Future<void> _initializeFirebaseIfNeeded() async {
    await FirebaseSecurityService.ensureReady();
    FirebaseAuth.instance;
    FirebaseFirestore.instance;
  }
}
