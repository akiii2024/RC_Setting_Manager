import 'package:rc_setting_manager/utils/app_logger.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/track_location.dart';
import '../services/track_location_service.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  // 位置情報の権限を確認・要求
  Future<bool> requestLocationPermission() async {
    if (kIsWeb) {
      // Web環境では位置情報APIが異なる処理を行う
      return await _requestWebLocationPermission();
    }

    try {
      // Geolocatorで権限を確認・要求
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugLog('位置情報の権限が永続的に拒否されています。設定から許可してください。');
        return false;
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugLog('権限確認エラー: $e');
      return false;
    }
  }

  // Web環境での位置情報権限要求
  Future<bool> _requestWebLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      switch (permission) {
        case LocationPermission.denied:
          permission = await Geolocator.requestPermission();
          return permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always;
        case LocationPermission.deniedForever:
          return false;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return true;
        case LocationPermission.unableToDetermine:
          // Permissions APIを完全にはサポートしないSafariでは権限状態を
          // 判定できない。実際の位置情報取得時に許可ダイアログを表示する。
          return true;
      }
    } catch (e) {
      debugLog('Web位置情報権限エラー: $e');
      // Safariではnavigator.permissionsの照会だけが失敗し、
      // navigator.geolocation自体は利用できる場合がある。
      return true;
    }
  }

  // 位置情報サービスが有効かチェック
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // 現在位置を取得
  Future<Position> determineCurrentPosition() async {
    try {
      if (!kIsWeb) {
        // WebではPermissions APIの実装がブラウザごとに異なるため、
        // navigator.geolocation相当の実取得に権限要求を任せる。
        if (!await requestLocationPermission()) {
          throw LocationException(
            '位置情報の権限が許可されていません',
            LocationStatus.permissionDenied,
          );
        }

        if (!await isLocationServiceEnabled()) {
          throw LocationException(
            '位置情報サービスが無効です',
            LocationStatus.serviceDisabled,
          );
        }
      }

      final locationSettings = LocationSettings(
        accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
    } on LocationException {
      rethrow;
    } on PermissionDeniedException catch (e) {
      throw LocationException(
        e.message ?? '位置情報の権限が許可されていません',
        LocationStatus.permissionDenied,
      );
    } on LocationServiceDisabledException catch (e) {
      throw LocationException(
        '位置情報サービスが無効です: $e',
        LocationStatus.serviceDisabled,
      );
    } on TimeoutException catch (e) {
      throw LocationException(
        e.message ?? '位置情報の取得がタイムアウトしました',
        LocationStatus.timeout,
      );
    } catch (e) {
      throw LocationException(
        '現在位置を取得できませんでした: $e',
        LocationStatus.unavailable,
      );
    }
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await determineCurrentPosition();
    } on LocationException catch (e) {
      debugLog('位置情報取得エラー [${e.status.name}]: ${e.message}');
      return null;
    }
  }

  // 現在位置から最も近いトラックを検索
  Future<TrackLocation?> findNearestTrack() async {
    try {
      Position? position = await getCurrentPosition();
      if (position == null) return null;

      // トラック位置データを読み込み
      await TrackLocationService.instance.loadTrackLocations();

      return TrackLocationService.instance
          .findNearestTrack(position.latitude, position.longitude);
    } catch (e) {
      debugLog('最寄りトラック検索エラー: $e');
      return null;
    }
  }

  // 位置情報の設定状況を取得
  Future<LocationStatus> getLocationStatus() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    bool permissionGranted = await requestLocationPermission();

    if (!serviceEnabled) {
      return LocationStatus.serviceDisabled;
    } else if (!permissionGranted) {
      return LocationStatus.permissionDenied;
    } else {
      return LocationStatus.available;
    }
  }

  // 位置情報の監視を開始（リアルタイム更新用）
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // 100m移動したら更新
      ),
    );
  }

  // 2点間の距離を計算（メートル単位）
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}

enum LocationStatus {
  available,
  serviceDisabled,
  permissionDenied,
  timeout,
  unavailable,
}

// 位置情報エラーのカスタム例外
class LocationException implements Exception {
  final String message;
  final LocationStatus status;

  LocationException(this.message, this.status);

  @override
  String toString() => 'LocationException: $message';
}
