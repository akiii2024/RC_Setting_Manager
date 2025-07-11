import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth? _firebaseAuth;
  User? _user;

  AuthService() : _firebaseAuth = _getFirebaseAuth() {
    _firebaseAuth?.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  static FirebaseAuth? _getFirebaseAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      print('Firebase Auth not available: $e');
      return null;
    }
  }

  User? get currentUser => _user;
  bool get isSignedIn => _user != null;
  bool get isFirebaseAvailable => _firebaseAuth != null;

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    if (_firebaseAuth == null) {
      throw Exception('Firebase認証は現在利用できません');
    }

    try {
      await _firebaseAuth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('サインインに失敗しました: $e');
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    if (_firebaseAuth == null) {
      throw Exception('Firebase認証は現在利用できません');
    }

    try {
      await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('アカウント作成に失敗しました: $e');
    }
  }

  Future<void> signOut() async {
    if (_firebaseAuth == null) {
      throw Exception('Firebase認証は現在利用できません');
    }

    try {
      await _firebaseAuth!.signOut();
    } catch (e) {
      throw Exception('サインアウトに失敗しました: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (_firebaseAuth == null) {
      throw Exception('Firebase認証は現在利用できません');
    }

    try {
      await _firebaseAuth!.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('パスワードリセットメールの送信に失敗しました: $e');
    }
  }
}
