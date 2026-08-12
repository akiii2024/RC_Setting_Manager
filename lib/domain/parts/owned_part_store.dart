import '../../models/owned_part.dart';
import '../../models/saved_setting.dart';
import 'owned_part_queries.dart';

typedef OwnedPartAddResult = ({OwnedPart? part, bool changed});

/// 所有パーツの状態とCRUD規則を保持する内部ストア。
class OwnedPartStore {
  List<OwnedPart> _parts = [];

  List<OwnedPart> get parts => _parts;

  void replace(List<OwnedPart> parts, {bool sortByName = false}) {
    _parts = parts;
    if (sortByName) {
      _parts.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  List<OwnedPart> byCategory(String category) {
    return OwnedPartQueries.byCategory(_parts, category);
  }

  List<String> suggestions({
    required String key,
    required List<String>? baseOptions,
    required Iterable<SavedSetting> savedSettings,
    String query = '',
  }) {
    return OwnedPartQueries.suggestions(
      key: key,
      baseOptions: baseOptions,
      savedSettings: savedSettings,
      ownedParts: _parts,
      query: query,
    );
  }

  OwnedPartAddResult add(String category, String name) {
    final normalizedName = name.trim();
    if (!ownedPartCategories.contains(category) || normalizedName.isEmpty) {
      return (part: null, changed: false);
    }

    final existing = OwnedPartQueries.findByName(
      _parts,
      category,
      normalizedName,
    );
    if (existing != null) {
      return (part: existing, changed: false);
    }

    final now = DateTime.now();
    final part = OwnedPart(
      id: now.microsecondsSinceEpoch.toString(),
      category: category,
      name: normalizedName,
      createdAt: now,
    );
    _parts.add(part);
    return (part: part, changed: true);
  }

  bool update(
    String id, {
    required String category,
    required String name,
  }) {
    final normalizedName = name.trim();
    if (!ownedPartCategories.contains(category) || normalizedName.isEmpty) {
      return false;
    }

    final index = _parts.indexWhere((part) => part.id == id);
    if (index == -1 ||
        OwnedPartQueries.findByName(
              _parts,
              category,
              normalizedName,
              excludeId: id,
            ) !=
            null) {
      return false;
    }

    _parts[index] = _parts[index].copyWith(
      category: category,
      name: normalizedName,
    );
    return true;
  }

  void delete(String id) {
    _parts.removeWhere((part) => part.id == id);
  }

  List<OwnedPartImportCandidate> importCandidates(
    Iterable<SavedSetting> savedSettings,
  ) {
    return OwnedPartQueries.importCandidates(
      savedSettings: savedSettings,
      ownedParts: _parts,
    );
  }

  bool importFromHistory(
    Iterable<OwnedPartImportCandidate> selectedCandidates,
  ) {
    var changed = false;
    for (final candidate in selectedCandidates) {
      final category = candidate.category;
      final name = candidate.name.trim();
      if (!ownedPartCategories.contains(category) ||
          name.isEmpty ||
          OwnedPartQueries.findByName(_parts, category, name) != null) {
        continue;
      }
      final now = DateTime.now();
      _parts.add(
        OwnedPart(
          id: '${now.microsecondsSinceEpoch}-${_parts.length}',
          category: category,
          name: name,
          createdAt: now,
        ),
      );
      changed = true;
    }
    return changed;
  }
}
