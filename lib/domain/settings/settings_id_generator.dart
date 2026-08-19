import 'dart:math';

abstract interface class SettingsIdGenerator {
  String nextId();
}

/// Generates RFC 4122 version 4 identifiers without relying on clock precision.
class SecureSettingsIdGenerator implements SettingsIdGenerator {
  SecureSettingsIdGenerator({Random? random})
      : _random = random ?? Random.secure();

  final Random _random;

  @override
  String nextId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
