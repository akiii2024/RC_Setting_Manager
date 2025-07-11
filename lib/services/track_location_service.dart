import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track_location.dart';

class TrackLocationService {
  static TrackLocationService? _instance;
  static TrackLocationService get instance =>
      _instance ??= TrackLocationService._();
  TrackLocationService._();

  List<TrackLocation> _trackLocations = [];
  bool _isLoaded = false;

  // トラック位置データを読み込み
  Future<List<TrackLocation>> loadTrackLocations() async {
    if (_isLoaded && _trackLocations.isNotEmpty) {
      return _trackLocations;
    }

    try {
      // まずカスタムトラックを読み込み
      await _loadCustomTracks();

      // 次にデフォルトトラックを読み込み
      await _loadDefaultTracks();

      _isLoaded = true;
      return _trackLocations;
    } catch (e) {
      print('トラック位置データの読み込みエラー: $e');
      return [];
    }
  }

  // デフォルトのトラック位置データを読み込み
  Future<void> _loadDefaultTracks() async {
    try {
      final String jsonString =
          await rootBundle.loadString('lib/data/track_locations.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> tracksJson = jsonData['tracks'];

      final List<TrackLocation> defaultTracks = tracksJson.map((trackJson) {
        return TrackLocation.fromJson({
          ...trackJson,
          'id': trackJson['id'], // IDを追加
        });
      }).toList();

      // デフォルトトラックを追加（重複チェック）
      for (final track in defaultTracks) {
        if (!_trackLocations.any((existing) => existing.name == track.name)) {
          _trackLocations.add(track);
        }
      }
    } catch (e) {
      print('デフォルトトラック読み込みエラー: $e');
    }
  }

  // カスタムトラックを読み込み
  Future<void> _loadCustomTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? customTracksJson = prefs.getString('custom_tracks');

      if (customTracksJson != null) {
        final List<dynamic> tracksJson = json.decode(customTracksJson);
        final List<TrackLocation> customTracks = tracksJson.map((trackJson) {
          return TrackLocation.fromJson(trackJson);
        }).toList();

        _trackLocations.addAll(customTracks);
      }
    } catch (e) {
      print('カスタムトラック読み込みエラー: $e');
    }
  }

  // カスタムトラックを保存
  Future<void> saveCustomTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // カスタムトラックのみを抽出（IDがcustom_で始まるもの）
      final customTracks = _trackLocations.where((track) {
        // TrackLocationモデルにIDフィールドを追加する必要があります
        return track.name.startsWith('カスタム') || track.address.contains('カスタム');
      }).toList();

      final String customTracksJson =
          json.encode(customTracks.map((track) => track.toJson()).toList());

      await prefs.setString('custom_tracks', customTracksJson);
    } catch (e) {
      print('カスタムトラック保存エラー: $e');
    }
  }

  // 新しいトラックを追加
  Future<void> addTrack(TrackLocation track) async {
    _trackLocations.add(track);
    await saveCustomTracks();
  }

  // トラックを削除
  Future<void> removeTrack(String trackName) async {
    _trackLocations.removeWhere((track) => track.name == trackName);
    await saveCustomTracks();
  }

  // トラックを更新
  Future<void> updateTrack(String oldName, TrackLocation newTrack) async {
    final index = _trackLocations.indexWhere((track) => track.name == oldName);
    if (index != -1) {
      _trackLocations[index] = newTrack;
      await saveCustomTracks();
    }
  }

  // 現在位置から最も近いトラックを検索
  TrackLocation? findNearestTrack(double latitude, double longitude) {
    if (_trackLocations.isEmpty) return null;

    TrackLocation? nearestTrack;
    double minDistance = double.infinity;

    for (final track in _trackLocations) {
      final distance = _calculateDistance(
          latitude, longitude, track.latitude, track.longitude);

      // トラックの範囲内かつ最も近い場合
      if (distance <= track.radius && distance < minDistance) {
        minDistance = distance;
        nearestTrack = track;
      }
    }

    return nearestTrack;
  }

  // トラック名で検索
  List<TrackLocation> searchTracksByName(String query) {
    if (query.isEmpty) return _trackLocations;

    return _trackLocations
        .where((track) =>
            track.name.toLowerCase().contains(query.toLowerCase()) ||
            track.address.toLowerCase().contains(query.toLowerCase()) ||
            track.prefecture.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // 都道府県でフィルタリング
  List<TrackLocation> getTracksByPrefecture(String prefecture) {
    return _trackLocations
        .where((track) => track.prefecture == prefecture)
        .toList();
  }

  // タイプでフィルタリング
  List<TrackLocation> getTracksByType(String type) {
    return _trackLocations.where((track) => track.type == type).toList();
  }

  // 全ての都道府県リストを取得
  List<String> getAllPrefectures() {
    return _trackLocations.map((track) => track.prefecture).toSet().toList()
      ..sort();
  }

  // 全てのトラックを取得
  List<TrackLocation> getAllTracks() {
    return List.from(_trackLocations);
  }

  // データをリロード
  Future<void> reload() async {
    _trackLocations.clear();
    _isLoaded = false;
    await loadTrackLocations();
  }

  // 2点間の距離を計算（メートル単位）
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 地球の半径（メートル）

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}
