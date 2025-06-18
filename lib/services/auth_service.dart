import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  User? _user;
  bool _isFirebaseAvailable = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  AuthService() {
    try {
      _auth = FirebaseAuth.instance;
      _isFirebaseAvailable = true;
      _auth!.authStateChanges().listen((User? user) {
        _user = user;
        notifyListeners();
      });
    } catch (e) {
      print('Firebase Auth初期化エラー: $e');
      _isFirebaseAvailable = false;
    }
  }

  // メールアドレスとパスワードでサインアップ
  Future<UserCredential?> signUpWithEmailAndPassword(
      String email, String password) async {
    if (!_isFirebaseAvailable || _auth == null) {
      throw Exception('Firebase is not available');
    }
    try {
      UserCredential result = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      print('サインアップエラー: $e');
      rethrow;
    }
  }

  // メールアドレスとパスワードでサインイン
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    if (!_isFirebaseAvailable || _auth == null) {
      throw Exception('Firebase is not available');
    }
    try {
      UserCredential result = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      print('サインインエラー: $e');
      rethrow;
    }
  }

  // サインアウト
  Future<void> signOut() async {
    if (!_isFirebaseAvailable || _auth == null) {
      throw Exception('Firebase is not available');
    }
    try {
      await _auth!.signOut();
    } catch (e) {
      print('サインアウトエラー: $e');
      rethrow;
    }
  }

  // パスワードリセット
  Future<void> sendPasswordResetEmail(String email) async {
    if (!_isFirebaseAvailable || _auth == null) {
      throw Exception('Firebase is not available');
    }
    try {
      await _auth!.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('パスワードリセットエラー: $e');
      rethrow;
    }
  }

  // 現在のユーザーを取得
  User? getCurrentUser() {
    if (!_isFirebaseAvailable || _auth == null) {
      return null;
    }
    return _auth!.currentUser;
  }
}