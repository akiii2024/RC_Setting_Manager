import 'package:rc_setting_manager/utils/app_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/car.dart';
import '../models/owned_part.dart';
import '../models/run_log.dart';
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
    debugLog('Attempting to save setting: ${setting.id}');
    debugLog('User ID: $userId');
    debugLog('Is Guest User: $isGuestUser');
    debugLog('User Collection: ${userCollection?.path}');

    if (userCollection == null) {
      debugLog('ERROR: User collection is null - user may not be logged in');
      throw Exception('User is not signed in.');
    }

    try {
      final docRef = userCollection!
          .doc('settings')
          .collection('saved_settings')
          .doc(setting.id);
      debugLog('Saving to document: ${docRef.path}');
      await docRef.set(setting.toJson());
      debugLog('Setting saved successfully');
    } catch (e) {
      debugLog('Error saving setting: $e');
      debugLog('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        debugLog('Firebase Error Code: ${e.code}');
        debugLog('Firebase Error Message: ${e.message}');
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
        final data = doc.data();
        return SavedSetting.fromJson(data);
      }).toList();
    } catch (e) {
      debugLog('Error loading settings: $e');
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
      debugLog('Error deleting setting: $e');
      rethrow;
    }
  }

  Future<void> saveRunLog(RunLog runLog) async {
    if (userCollection == null) {
      throw Exception('User is not signed in.');
    }

    try {
      await userCollection!
          .doc('run_logs')
          .collection('items')
          .doc(runLog.id)
          .set(runLog.toJson());
    } catch (e) {
      debugLog('Error saving run log: $e');
      rethrow;
    }
  }

  Future<List<RunLog>> getRunLogs() async {
    if (userCollection == null) {
      return [];
    }

    try {
      final snapshot =
          await userCollection!.doc('run_logs').collection('items').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return RunLog.fromJson(data);
      }).toList();
    } catch (e) {
      debugLog('Error loading run logs: $e');
      return [];
    }
  }

  Future<void> deleteRunLog(String runLogId) async {
    if (userCollection == null) {
      throw Exception('User is not signed in.');
    }

    try {
      await userCollection!
          .doc('run_logs')
          .collection('items')
          .doc(runLogId)
          .delete();
    } catch (e) {
      debugLog('Error deleting run log: $e');
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
      debugLog('Error saving cars: $e');
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
      debugLog('Error loading cars: $e');
      return [];
    }
  }

  Future<void> saveOwnedParts(List<OwnedPart> ownedParts) async {
    if (userCollection == null) {
      throw Exception('User is not signed in.');
    }

    try {
      final ownedPartsJson = ownedParts.map((part) => part.toJson()).toList();
      await userCollection!
          .doc('owned_parts')
          .set({'ownedParts': ownedPartsJson});
    } catch (e) {
      debugLog('Error saving owned parts: $e');
      rethrow;
    }
  }

  Future<List<OwnedPart>> getOwnedParts() async {
    if (userCollection == null) {
      return [];
    }

    try {
      final snapshot = await userCollection!.doc('owned_parts').get();
      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final ownedPartsData = data['ownedParts'] as List<dynamic>? ?? [];
      return ownedPartsData
          .map((partData) => OwnedPart.fromJson(
                Map<String, dynamic>.from(partData as Map),
              ))
          .toList();
    } catch (e) {
      debugLog('Error loading owned parts: $e');
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
      debugLog('Error saving visibility settings: $e');
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
      debugLog('Error loading visibility settings: $e');
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
      debugLog('Error saving language settings: $e');
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
      debugLog('Error loading language settings: $e');
      return false;
    }
  }

  Future<void> syncAllData({
    required List<SavedSetting> savedSettings,
    required List<RunLog> runLogs,
    required List<Car> cars,
    required List<OwnedPart> ownedParts,
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
      final runLogsCollection =
          userCollection!.doc('run_logs').collection('items');
      final existingRunLogsSnapshot = await runLogsCollection.get();
      final localRunLogIds = runLogs.map((runLog) => runLog.id).toSet();
      final batch = _firestore.batch();

      for (final doc in existingSnapshot.docs) {
        if (!localSettingIds.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      for (final doc in existingRunLogsSnapshot.docs) {
        if (!localRunLogIds.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      for (final setting in savedSettings) {
        batch.set(settingsCollection.doc(setting.id), setting.toJson());
      }

      for (final runLog in runLogs) {
        batch.set(runLogsCollection.doc(runLog.id), runLog.toJson());
      }

      final carsJson = cars.map((car) => car.toJson()).toList();
      batch.set(userCollection!.doc('cars'), {'cars': carsJson});

      final ownedPartsJson = ownedParts.map((part) => part.toJson()).toList();
      batch.set(
          userCollection!.doc('owned_parts'), {'ownedParts': ownedPartsJson});

      final visibilityJson = <String, dynamic>{};
      visibilitySettings.forEach((key, value) {
        visibilityJson[key] = value.toJson();
      });
      batch.set(userCollection!.doc('visibility_settings'), visibilityJson);

      batch.set(
          userCollection!.doc('language_settings'), {'isEnglish': isEnglish});

      await batch.commit();
    } catch (e) {
      debugLog('Error syncing data: $e');
      rethrow;
    }
  }
}
