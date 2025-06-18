import '../models/track_location.dart';
import 'dart:math';

// トラック位置情報のデータベース
final List<TrackLocation> trackLocations = [
  // 関東地方
  TrackLocation(
    name: 'タミヤサーキット',
    latitude: 35.6762,
    longitude: 139.6503,
    radius: 1000, // 1km
    prefecture: '東京都',
    address: '東京都新宿区',
    type: 'indoor',
    surfaceType: 'carpet',
  ),
  TrackLocation(
    name: 'ヨコモドリフトミーティング',
    latitude: 35.6895,
    longitude: 139.6917,
    radius: 800,
    prefecture: '東京都',
    address: '東京都渋谷区',
    type: 'indoor',
    surfaceType: 'carpet',
  ),
  
  // 関西地方
  TrackLocation(
    name: '大阪RCサーキット',
    latitude: 34.6937,
    longitude: 135.5023,
    radius: 1200,
    prefecture: '大阪府',
    address: '大阪府大阪市',
    type: 'outdoor',
    surfaceType: 'asphalt',
  ),
  
  // 中部地方
  TrackLocation(
    name: '名古屋RCパーク',
    latitude: 35.1815,
    longitude: 136.9066,
    radius: 1000,
    prefecture: '愛知県',
    address: '愛知県名古屋市',
    type: 'outdoor',
    surfaceType: 'asphalt',
  ),
  
  // 九州地方
  TrackLocation(
    name: '福岡モデルサーキット',
    latitude: 33.5904,
    longitude: 130.4017,
    radius: 900,
    prefecture: '福岡県',
    address: '福岡県福岡市',
    type: 'indoor',
    surfaceType: 'carpet',
  ),
  
  // 北海道
  TrackLocation(
    name: '札幌RCクラブ',
    latitude: 43.0642,
    longitude: 141.3469,
    radius: 1500,
    prefecture: '北海道',
    address: '北海道札幌市',
    type: 'indoor',
    surfaceType: 'carpet',
  ),
  
  // 東北地方
  TrackLocation(
    name: '仙台モデルカーサーキット',
    latitude: 38.2682,
    longitude: 140.8694,
    radius: 1100,
    prefecture: '宮城県',
    address: '宮城県仙台市',
    type: 'outdoor',
    surfaceType: 'asphalt',
  ),
];

// 現在位置から最も近いトラックを検索する関数
TrackLocation? findNearestTrack(double latitude, double longitude) {
  TrackLocation? nearestTrack;
  double minDistance = double.infinity;
  
  for (final track in trackLocations) {
    final distance = _calculateDistance(
      latitude, longitude, 
      track.latitude, track.longitude
    );
    
    // トラックの範囲内かつ最も近い場合
    if (distance <= track.radius && distance < minDistance) {
      minDistance = distance;
      nearestTrack = track;
    }
  }
  
  return nearestTrack;
}

// 2点間の距離を計算（メートル単位）
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371000; // 地球の半径（メートル）
  
  final double dLat = _degreesToRadians(lat2 - lat1);
  final double dLon = _degreesToRadians(lon2 - lon1);
  
  final double a = 
    sin(dLat / 2) * sin(dLat / 2) +
    cos(lat1) * cos(lat2) * 
    sin(dLon / 2) * sin(dLon / 2);
  
  final double c = 2 * asin(sqrt(a));
  
  return earthRadius * c;
}

double _degreesToRadians(double degrees) {
  return degrees * (pi / 180);
}

// トラック名で検索する関数
List<TrackLocation> searchTracksByName(String query) {
  if (query.isEmpty) return [];
  
  return trackLocations.where((track) =>
    track.name.toLowerCase().contains(query.toLowerCase())
  ).toList();
}

// 都道府県でフィルタリングする関数
List<TrackLocation> getTracksByPrefecture(String prefecture) {
  return trackLocations.where((track) =>
    track.prefecture == prefecture
  ).toList();
}

// 全ての都道府県リストを取得
List<String> getAllPrefectures() {
  return trackLocations.map((track) => track.prefecture).toSet().toList()..sort();
}