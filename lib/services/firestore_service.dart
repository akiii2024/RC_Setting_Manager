import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/saved_setting.dart';
import '../models/car.dart';
import '../models/visibility_settings.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  // ユーザーのコレクション参照を取得
  CollectionReference? get userCollection {
    if (userId == null) return null;
    return _firestore.collection('users').doc(userId).collection('data');
  }

  // 保存された設定をFirestoreに保存
  Future<void> saveSetting(SavedSetting setting) async {
    if (userCollection == null) throw Exception('ユーザーがログインしていません');
    
    try {
      await userCollection!.doc('settings').collection('saved_settings').doc(setting.id).set(setting.toJson());
    } catch (e) {
      print('設定保存エラー: $e');
      rethrow;
    }
  }

  // 保存された設定をFirestoreから取得
  Future<List<SavedSetting>> getSavedSettings() async {
    if (userCollection == null) return [];
    
    try {
      QuerySnapshot snapshot = await userCollection!.doc('settings').collection('saved_settings').get();
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return SavedSetting.fromJson(data);
      }).toList();
    } catch (e) {
      print('設定取得エラー: $e');
      return [];
    }
  }

  // 設定を削除
  Future<void> deleteSetting(String settingId) async {
    if (userCollection == null) throw Exception('ユーザーがログインしていません');
    
    try {
      await userCollection!.doc('settings').collection('saved_settings').doc(settingId).delete();
    } catch (e) {
      print('設定削除エラー: $e');
      rethrow;
    }
  }

  // 車種リストを保存
  Future<void> saveCars(List<Car> cars) async {
    if (userCollection == null) throw Exception('ユーザーがログインしていません');
    
    try {
      List<Map<String, dynamic>> carsJson = cars.map((car) => car.toJson()).toList();
      await userCollection!.doc('cars').set({'cars': carsJson});
    } catch (e) {
      print('車種保存エラー: $e');
      rethrow;
    }
  }

  // 車種リストを取得
  Future<List<Car>> getCars() async {
    if (userCollection == null) return [];
    
    try {
      DocumentSnapshot snapshot = await userCollection!.doc('cars').get();
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        List<dynamic> carsData = data['cars'] ?? [];
        return carsData.map((carData) => Car.fromJson(carData as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('車種取得エラー: $e');
      return [];
    }
  }

  // 表示設定を保存
  Future<void> saveVisibilitySettings(Map<String, VisibilitySettings> visibilitySettings) async {
    if (userCollection == null) throw Exception('ユーザーがログインしていません');
    
    try {
      Map<String, dynamic> visibilityJson = {};
      visibilitySettings.forEach((key, value) {
        visibilityJson[key] = value.toJson();
      });
      await userCollection!.doc('visibility_settings').set(visibilityJson);
    } catch (e) {
      print('表示設定保存エラー: $e');
      rethrow;
    }
  }

  // 表示設定を取得
  Future<Map<String, VisibilitySettings>> getVisibilitySettings() async {
    if (userCollection == null) return {};
    
    try {
      DocumentSnapshot snapshot = await userCollection!.doc('visibility_settings').get();
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        Map<String, VisibilitySettings> visibilitySettings = {};
        data.forEach((key, value) {
          visibilitySettings[key] = VisibilitySettings.fromJson(value as Map<String, dynamic>);
        });
        return visibilitySettings;
      }
      return {};
    } catch (e) {
      print('表示設定取得エラー: $e');
      return {};
    }
  }

  // 言語設定を保存
  Future<void> saveLanguageSettings(bool isEnglish) async {
    if (userCollection == null) throw Exception('ユーザーがログインしていません');
    
    try {
      await userCollection!.doc('language_settings').set({'isEnglish': isEnglish});
    } catch (e) {
      print('言語設定保存エラー: $e');
      rethrow;
    }
  }

  // 言語設定を取得
  Future<bool> getLanguageSettings() async {
    if (userCollection == null) return false;
    
    try {
      DocumentSnapshot snapshot = await userCollection!.doc('language_settings').get();
      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        return data['isEnglish'] ?? false;
      }
      return false;
    } catch (e) {
      print('言語設定取得エラー: $e');
      return false;
    }
  }

  // すべてのデータを同期
  Future<void> syncAllData({
    required List<SavedSetting> savedSettings,
    required List<Car> cars,
    required Map<String, VisibilitySettings> visibilitySettings,
    required bool isEnglish,
  }) async {
    if (userCollection == null) throw Exception('ユーザーがログインしていません');
    
    try {
      // バッチ書き込みを使用して一括更新
      WriteBatch batch = _firestore.batch();
      
      // 保存された設定
      for (SavedSetting setting in savedSettings) {
        DocumentReference settingRef = userCollection!.doc('settings').collection('saved_settings').doc(setting.id);
        batch.set(settingRef, setting.toJson());
      }
      
      // 車種リスト
      List<Map<String, dynamic>> carsJson = cars.map((car) => car.toJson()).toList();
      DocumentReference carsRef = userCollection!.doc('cars');
      batch.set(carsRef, {'cars': carsJson});
      
      // 表示設定
      Map<String, dynamic> visibilityJson = {};
      visibilitySettings.forEach((key, value) {
        visibilityJson[key] = value.toJson();
      });
      DocumentReference visibilityRef = userCollection!.doc('visibility_settings');
      batch.set(visibilityRef, visibilityJson);
      
      // 言語設定
      DocumentReference languageRef = userCollection!.doc('language_settings');
      batch.set(languageRef, {'isEnglish': isEnglish});
      
      await batch.commit();
    } catch (e) {
      print('データ同期エラー: $e');
      rethrow;
    }
  }
}