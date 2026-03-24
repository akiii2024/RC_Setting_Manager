import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/car.dart';
import '../models/saved_setting.dart';
import '../models/visibility_settings.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;
  bool get isGuestUser => _auth.currentUser?.isAnonymous ?? false;

  CollectionReference? get userCollection {
    if (userId == null) {
      return null;
    }

    if (isGuestUser) {
      return _firestore
          .collection('guest_users')
          .doc(userId)
          .collection('data');
    }

    return _firestore.collection('users').doc(userId).collection('data');
  }

  Future<void> saveSetting(SavedSetting setting) async {
    print('Attempting to save setting: ${setting.id}');
    print('User ID: $userId');
    print('Is Guest User: $isGuestUser');
    print('User Collection: ${userCollection?.path}');

    if (userCollection == null) {
      print('ERROR: User collection is null - user may not be logged in');
      throw Exception('User is not signed in.');
    }

    try {
      final docRef = userCollection!
          .doc('settings')
          .collection('saved_settings')
          .doc(setting.id);
      print('Saving to document: ${docRef.path}');
      await docRef.set(setting.toJson());
      print('Setting saved successfully');
    } catch (e) {
      print('Error saving setting: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('Firebase Error Code: ${e.code}');
        print('Firebase Error Message: ${e.message}');
        throw Exception('Failed to save setting: ${e.code} - ${e.message}');
      }
      throw Exception('Failed to save setting: $e');
    }
  }

  Future<List<SavedSetting>> getSavedSettings() async {
    if (userCollection == null) {
      return [];
    }

    try {
      final snapshot = await userCollection!
          .doc('settings')
          .collection('saved_settings')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SavedSetting.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error loading settings: $e');
      return [];
    }
  }

  Future<void> deleteSetting(String settingId) async {
    if (userCollection == null) {
      throw Exception('User is not signed in.');
    }

    try {
      await userCollection!
          .doc('settings')
          .collection('saved_settings')
          .doc(settingId)
          .delete();
    } catch (e) {
      print('Error deleting setting: $e');
      rethrow;
    }
  }

  Future<void> saveCars(List<Car> cars) async {
    if (userCollection == null) {
      throw Exception('User is not signed in.');
    }

    try {
      final carsJson = cars.map((car) => car.toJson()).toList();
      await userCollection!.doc('cars').set({'cars': carsJson});
    } catch (e) {
      print('Error saving cars: $e');
      rethrow;
    }
  }

  Future<List<Car>> getCars() async {
    if (userCollection == null) {
      return [];
    }

    try {
      final snapshot = await userCollection!.doc('cars').get();
      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final carsData = data['cars'] as List<dynamic>? ?? [];
      return carsData
          .map((carData) => Car.fromJson(carData as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading cars: $e');
      return [];
    }
  }

  Future<void> saveVisibilitySettings(
      Map<String, VisibilitySettings> visibilitySettings) async {
    if (userCollection == null) {
      throw Exception('User is not signed in.');
    }

    try {
      final visibilityJson = <String, dynamic>{};
      visibilitySettings.forEach((key, value) {
        visibilityJson[key] = value.toJson();
      });
      await userCollection!.doc('visibility_settings').set(visibilityJson);
    } catch (e) {
      print('Error saving visibility settings: $e');
      rethrow;
    }
  }

  Future<Map<String, VisibilitySettings>> getVisibilitySettings() async {
    if (userCollection == null) {
      return {};
    }

    try {
      final snapshot = await userCollection!.doc('visibility_settings').get();
      if (!snapshot.exists) {
        return {};
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final visibilitySettings = <String, VisibilitySettings>{};
      data.forEach((key, value) {
        visibilitySettings[key] =
            VisibilitySettings.fromJson(value as Map<String, dynamic>);
      });
      return visibilitySettings;
    } catch (e) {
      print('Error loading visibility settings: $e');
      return {};
    }
  }

  Future<void> saveLanguageSettings(bool isEnglish) async {
    if (userCollection == null) {
      throw Exception('User is not signed in.');
    }

    try {
      await userCollection!
          .doc('language_settings')
          .set({'isEnglish': isEnglish});
    } catch (e) {
      print('Error saving language settings: $e');
      rethrow;
    }
  }

  Future<bool> getLanguageSettings() async {
    if (userCollection == null) {
      return false;
    }

    try {
      final snapshot = await userCollection!.doc('language_settings').get();
      if (!snapshot.exists) {
        return false;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      return data['isEnglish'] as bool? ?? false;
    } catch (e) {
      print('Error loading language settings: $e');
      return false;
    }
  }

  Future<void> syncAllData({
    required List<SavedSetting> savedSettings,
    required List<Car> cars,
    required Map<String, VisibilitySettings> visibilitySettings,
    required bool isEnglish,
  }) async {
    if (userCollection == null) {
      throw Exception('User is not signed in.');
    }

    try {
      final settingsCollection =
          userCollection!.doc('settings').collection('saved_settings');
      final existingSnapshot = await settingsCollection.get();
      final localSettingIds =
          savedSettings.map((setting) => setting.id).toSet();
      final batch = _firestore.batch();

      for (final doc in existingSnapshot.docs) {
        if (!localSettingIds.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      for (final setting in savedSettings) {
        batch.set(settingsCollection.doc(setting.id), setting.toJson());
      }

      final carsJson = cars.map((car) => car.toJson()).toList();
      batch.set(userCollection!.doc('cars'), {'cars': carsJson});

      final visibilityJson = <String, dynamic>{};
      visibilitySettings.forEach((key, value) {
        visibilityJson[key] = value.toJson();
      });
      batch.set(userCollection!.doc('visibility_settings'), visibilityJson);

      batch.set(
          userCollection!.doc('language_settings'), {'isEnglish': isEnglish});

      await batch.commit();
    } catch (e) {
      print('Error syncing data: $e');
      rethrow;
    }
  }
}
