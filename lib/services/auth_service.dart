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

  // 外部からアクセス可能にする
  FirebaseAuth? get firebaseAuth => _firebaseAuth;

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
      print('ERROR: Firebase Auth is null - Firebase may not be initialized');
      throw Exception('Firebase認証は現在利用できません。Firebaseが初期化されていない可能性があります。');
    }

    print('Attempting to sign in with email: $email');
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Sign in successful: ${credential.user?.uid}');
    } catch (e) {
      print('Sign in error: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseAuthException) {
        print('Firebase Auth Error Code: ${e.code}');
        print('Firebase Auth Error Message: ${e.message}');
        throw Exception('サインインに失敗しました: ${e.code} - ${e.message}');
      }
      throw Exception('サインインに失敗しました: $e');
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    if (_firebaseAuth == null) {
      print('ERROR: Firebase Auth is null - Firebase may not be initialized');
      throw Exception('Firebase認証は現在利用できません。Firebaseが初期化されていない可能性があります。');
    }

    print('Attempting to create account with email: $email');
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Account creation successful: ${credential.user?.uid}');
    } catch (e) {
      print('Account creation error: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseAuthException) {
        print('Firebase Auth Error Code: ${e.code}');
        print('Firebase Auth Error Message: ${e.message}');
        throw Exception('アカウント作成に失敗しました: ${e.code} - ${e.message}');
      }
      throw Exception('アカウント作成に失敗しました: $e');
    }
  }

  Future<void> signOut() async {
    if (_firebaseAuth == null) {
      throw Exception('Firebase認証は現在利用できません');
    }

    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('サインアウトに失敗しました: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (_firebaseAuth == null) {
      throw Exception('Firebase認証は現在利用できません');
    }

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('パスワードリセットメールの送信に失敗しました: $e');
    }
  }

  Future<void> signInAnonymously() async {
    if (_firebaseAuth == null) {
      print('ERROR: Firebase Auth is null - Firebase may not be initialized');
      throw Exception('Firebase認証は現在利用できません。Firebaseが初期化されていない可能性があります。');
    }

    print('Attempting to sign in anonymously');
    try {
      final credential = await _firebaseAuth.signInAnonymously();
      print('Anonymous sign in successful: ${credential.user?.uid}');
      print('Is anonymous: ${credential.user?.isAnonymous}');
    } catch (e) {
      print('Anonymous sign in error: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseAuthException) {
        print('Firebase Auth Error Code: ${e.code}');
        print('Firebase Auth Error Message: ${e.message}');
        throw Exception('ゲストログインに失敗しました: ${e.code} - ${e.message}');
      }
      throw Exception('ゲストログインに失敗しました: $e');
    }
  }

  bool get isGuestUser => _user?.isAnonymous ?? false;
  String get displayName =>
      _user?.displayName ?? (isGuestUser ? 'ゲストユーザー' : '');

  // ゲストユーザーからアカウント作成（アップグレード）
  Future<void> convertGuestToAccount(String email, String password) async {
    if (_firebaseAuth == null) {
      print('ERROR: Firebase Auth is null - Firebase may not be initialized');
      throw Exception('Firebase認証は現在利用できません。Firebaseが初期化されていない可能性があります。');
    }

    if (!isGuestUser) {
      throw Exception('現在のユーザーはゲストユーザーではありません。');
    }

    print('Attempting to convert guest user to account with email: $email');
    try {
      final credential =
          EmailAuthProvider.credential(email: email, password: password);
      final result = await _user!.linkWithCredential(credential);
      print('Guest account converted successfully: ${result.user?.uid}');
      print('Is anonymous after conversion: ${result.user?.isAnonymous}');
    } catch (e) {
      print('Guest account conversion error: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseAuthException) {
        print('Firebase Auth Error Code: ${e.code}');
        print('Firebase Auth Error Message: ${e.message}');
        throw Exception('アカウント作成に失敗しました: ${e.code} - ${e.message}');
      }
      throw Exception('アカウント作成に失敗しました: $e');
    }
  }
}
