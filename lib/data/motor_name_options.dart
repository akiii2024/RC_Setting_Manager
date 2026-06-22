const List<String> motorNameOptions = [
  'Hobbywing XeRun V10 G5 13.5T',
  'Hobbywing XeRun V10 G5 17.5T',
  'Hobbywing XeRun V10 G4R 13.5T',
  'Hobbywing XeRun V10 G4R 17.5T',
  'Hobbywing XeRun V10 G4R 21.5T',
  'Hobbywing XeRun Bandit G4R 13.5T Torque',
  'Hobbywing XeRun Bandit G4R 13.5T OBL',
  'Hobbywing XeRun Bandit G4R 17.5T',
  'Muchmore FLETA ZX V3 10.5T',
  'Muchmore FLETA ZX V3 13.5T',
  'Muchmore FLETA ZX V3 17.5T',
  'Muchmore FLETA ZX V3 Specter 13.5T',
  'Yokomo Racing Performer M4 17.5T',
  'Yokomo FANTOM HELIX V2 SPEC EDITION 17.5T',
  'R1WURKS V21-S 13.5 Motor ROAR',
  'R1WURKS V21-S 17.5 Motor ROAR',
  'R1WURKS V21-S 21.5 Motor ROAR',
  'Trinity Slot Machine 2 10.5T',
  'Trinity Slot Machine 2 13.5T',
  'Trinity Slot Machine 2 17.5T',
  'ORCA BLITREME3 10.5T ROAR SPEC',
  'ORCA MODTREME2 7.5T',
];

bool isTurnOnlyMotorName(String value) {
  return RegExp(r'^\d+(?:\.\d+)?T$', caseSensitive: false)
      .hasMatch(value.trim());
}

List<String> normalizeMotorNameOptions(Iterable<String> options) {
  final normalized = <String>[];
  final seen = <String>{};

  for (final option in options) {
    final trimmed = option.trim();
    if (trimmed.isEmpty || isTurnOnlyMotorName(trimmed)) {
      continue;
    }

    if (seen.add(trimmed)) {
      normalized.add(trimmed);
    }
  }

  return normalized;
}
