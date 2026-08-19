/// Creates an immutable, detached copy of a JSON-compatible value.
///
/// Persisted settings are intentionally limited to JSON values. Rejecting
/// unsupported objects here prevents callers from retaining a mutable alias to
/// provider state and makes serialization failures deterministic.
Object? freezeJsonValue(Object? value) {
  if (value == null || value is String || value is bool) {
    return value;
  }
  if (value is num) {
    if (value is double && !value.isFinite) {
      throw ArgumentError.value(
          value, 'value', 'Must be a finite JSON number.');
    }
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(freezeJsonValue));
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(
            key, 'key', 'JSON object keys must be strings.');
      }
      result[key] = freezeJsonValue(entry.value);
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  throw ArgumentError.value(
    value,
    'value',
    'Only JSON-compatible values can be persisted.',
  );
}

Map<String, dynamic> freezeJsonMap(Map<String, dynamic> value) {
  return freezeJsonValue(value)! as Map<String, dynamic>;
}
