const int firestoreSyncBatchSize = 450;

/// Splits idempotent Firestore synchronization operations below the service
/// limit while leaving headroom for future metadata writes.
List<List<T>> planFirestoreSyncBatches<T>(Iterable<T> operations) {
  final values = List<T>.of(operations, growable: false);
  final batches = <List<T>>[];
  for (var offset = 0;
      offset < values.length;
      offset += firestoreSyncBatchSize) {
    final end = (offset + firestoreSyncBatchSize < values.length)
        ? offset + firestoreSyncBatchSize
        : values.length;
    batches.add(List<T>.unmodifiable(values.sublist(offset, end)));
  }
  return List<List<T>>.unmodifiable(batches);
}
