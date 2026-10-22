/// メーカー標準の内部減速比。駆動プーリーを変更した車両では上書きして使う。
abstract final class CarDriveRatios {
  // タミヤ: デフ37T / センター20T。
  // TRF420/420X: https://tamiya.com/cms/images/stories/alljapan/2025/RCCGP2024122702.pdf
  // TRF421: https://d7z22c0gz59ng.cloudfront.net/cms/japan/download/rcmanual/42384.pdf
  // TRF421X: https://d7z22c0gz59ng.cloudfront.net/cms/japan/download/rcmanual/42391.pdf (p31)
  // ヨコモ: BD11/BD12/MS1.0はデフ38T / センター20T、MS2.0は42T / 21T。
  // BD11/BD12の仕様は1.9。MS1.0は両車と同じB10-630MA/B9-503GHAを使用。
  // https://www.teamyokomo.com/collections/speed-kit/products/mrtc-bd11-1
  // https://www.teamyokomo.com/collections/speed-kit/products/msr-bd12a-1
  // https://cdn.shopify.com/s/files/1/0722/1133/3229/files/BD11_Manual.pdf
  // https://cdn.shopify.com/s/files/1/0722/1133/3229/files/BD12_Manual.pdf
  // https://cdn.shopify.com/s/files/1/0722/1133/3229/files/MS1.0_Instruction_Manual.pdf
  // https://cdn.shopify.com/s/files/1/0722/1133/3229/files/MS2.0_Instruction_Manual.pdf (p26)
  static const _standardRatios = <String, double>{
    'tamiya/trf420': 1.85,
    'tamiya/trf420x': 1.85,
    'tamiya/trf421': 1.85,
    'tamiya/trf421x': 1.85,
    'yokomo/bd11': 1.9,
    'yokomo/bd12': 1.9,
    'yokomo/ms1_0': 1.9,
    'yokomo/ms2_0': 2.0,
  };

  static double? forCarId(String? carId) => _standardRatios[carId];
}
