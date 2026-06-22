import 'motor_name_options.dart';

const List<String> bodyNameOptions = [
  'ZooRacing Wolverine MAX 190mm',
  'ZooRacing Gorilla MAX 190mm',
  'ZooRacing GOAT 190mm',
  'ZooRacing JACKAL 190mm',
  'Protoform P63 190mm',
  'Bittydesign HYPER-HR 190mm',
  'Bittydesign HYPER 190mm',
  'Bittydesign Eptron 190mm',
  'Mon-Tech A-6R 190mm',
  'Mon-Tech IS-200 190mm',
];

const List<String> batteryNameOptions = [
  'SUNPADOW Competition Short-Pack LiPo 6000mAh 7.6V 100C',
  'SUNPADOW Platin LiHV Shorty 4600mAh 7.6V 140C',
  'SUNPADOW Platin LiHV Shorty 6500mAh 7.6V 140C',
  'Muchmore IMPACT Silicon Graphene LCG HV FD4 6000mAh 7.6V 130C',
  'Muchmore IMPACT Silicon Graphene Super LCG FD4 5800mAh 7.4V 130C',
  'Gens Ace Redline 2.0 6000mAh 7.6V 140C Shorty',
  'ProTek RC SG3 6000mAh 7.6V 150C Shorty',
  'ProTek RC SG3 6800mAh 7.6V 150C Shorty',
  'SMC HCL-RS 6000mAh 7.4V 150C LCG VTA',
];

const List<String> tireNameOptions = [
  'Rush Pre-Glued Touring Car Tire 32 Shore',
  'Rush VR3 32S',
  'Rush VR3 32X',
  'Volante V5 28R Indoor Carpet',
  'Volante V5 Tough Gold 36R',
  'Volante V8T 36R Outdoor Asphalt',
  'Sweep EXP EVO-R3 PRO 32deg Asphalt',
  'Sweep EXP EVO-R3 PRO 36deg Asphalt',
  'Sweep DX-R3 36deg Asphalt',
  'Matrix Pre-Mounted Touring Tire 28 Shore',
  'Matrix Pre-Mounted Touring Tire 32 Shore',
  'Matrix Pre-Mounted Touring Tire 36 Shore',
];

const Set<String> settingNameSuggestionKeys = {
  'motor',
  'battery',
  'body',
  'tire',
  'frontTire',
  'rearTire',
};

List<String> defaultNameOptionsForSetting(String key) {
  return switch (key) {
    'motor' => motorNameOptions,
    'body' => bodyNameOptions,
    'battery' => batteryNameOptions,
    'tire' || 'frontTire' || 'rearTire' => tireNameOptions,
    _ => const <String>[],
  };
}

List<String> historyKeysForSettingSuggestions(String key) {
  return switch (key) {
    'tire' || 'frontTire' || 'rearTire' => const [
        'tire',
        'frontTire',
        'rearTire',
      ],
    _ => [key],
  };
}

List<String> normalizeSettingNameOptions(
  String key,
  Iterable<String> options,
) {
  final normalized = <String>[];
  final seen = <String>{};

  for (final option in options) {
    final trimmed = option.trim();
    if (trimmed.isEmpty) {
      continue;
    }

    if (key == 'motor' && isTurnOnlyMotorName(trimmed)) {
      continue;
    }

    if (seen.add(trimmed)) {
      normalized.add(trimmed);
    }
  }

  return normalized;
}
