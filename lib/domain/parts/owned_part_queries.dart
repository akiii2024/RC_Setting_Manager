import '../../data/setting_name_options.dart';
import '../../models/owned_part.dart';
import '../../models/saved_setting.dart';

/// Pure lookup and projection rules for the owned-parts feature.
enum OwnedPartSort { name, category, createdAt }

abstract final class OwnedPartQueries {
  static List<OwnedPart> search(
    Iterable<OwnedPart> parts, {
    String query = '',
    OwnedPartSort sort = OwnedPartSort.name,
  }) {
    final normalized = query.trim().toLowerCase();
    final result = parts
        .where((part) => part.name.toLowerCase().contains(normalized))
        .toList();
    result.sort((a, b) {
      final comparison = switch (sort) {
        OwnedPartSort.name =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        OwnedPartSort.category => a.category.compareTo(b.category),
        OwnedPartSort.createdAt => b.createdAt.compareTo(a.createdAt),
      };
      if (comparison != 0) return comparison;
      final nameComparison = a.name.compareTo(b.name);
      return nameComparison != 0 ? nameComparison : a.id.compareTo(b.id);
    });
    return result;
  }

  static List<SavedSetting> references(
    OwnedPart part,
    Iterable<SavedSetting> savedSettings,
  ) {
    final keys = switch (part.category) {
      'spring' => const [
          'spring',
          'frontSpring',
          'rearSpring',
          'frontDamperSpring',
          'rearDamperSpring'
        ],
      'damper' => const ['damper', 'frontDamperType', 'rearDamperType'],
      'electronics' => const ['electronics', 'esc', 'servo', 'receiver'],
      _ => historyKeysForSettingSuggestions(part.category),
    };
    return savedSettings
        .where((setting) => keys.any((key) {
              final value = setting.settings[key];
              return value is String &&
                  findByName([part], part.category, value) != null;
            }))
        .toList(growable: false);
  }

  static List<OwnedPart> byCategory(
    Iterable<OwnedPart> parts,
    String category,
  ) {
    final matching = parts
        .where((part) => part.category == category)
        .toList(growable: false);
    matching.sort((a, b) => a.name.compareTo(b.name));
    return matching;
  }

  static OwnedPart? findByName(
    Iterable<OwnedPart> parts,
    String category,
    String name, {
    String? excludeId,
  }) {
    final normalizedName = name.trim().toLowerCase();
    for (final part in parts) {
      if (part.category == category &&
          part.id != excludeId &&
          part.name.trim().toLowerCase() == normalizedName) {
        return part;
      }
    }
    return null;
  }

  static List<String> suggestions({
    required String key,
    required List<String>? baseOptions,
    required Iterable<SavedSetting> savedSettings,
    required Iterable<OwnedPart> ownedParts,
    String query = '',
  }) {
    final base = [...?baseOptions, ...defaultNameOptionsForSetting(key)];
    if (!settingNameSuggestionKeys.contains(key)) {
      return List<String>.from(base);
    }

    final category = _categoryForSetting(key);
    final ownedNames = category == null
        ? const <String>[]
        : byCategory(ownedParts, category)
            .map((part) => part.name)
            .toList(growable: false);
    final normalizedOwnedNames = normalizeSettingNameOptions(key, ownedNames);
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty && normalizedOwnedNames.isNotEmpty) {
      return normalizedOwnedNames;
    }

    final historyKeys = historyKeysForSettingSuggestions(key);
    final savedNames = savedSettings.expand(
      (setting) => historyKeys
          .map((historyKey) => setting.settings[historyKey])
          .whereType<String>(),
    );
    final suggestions = normalizeSettingNameOptions(key, [
      ...normalizedOwnedNames,
      ...base,
      ...savedNames,
    ]);
    if (normalizedQuery.isEmpty) {
      return suggestions;
    }
    return suggestions
        .where((option) => option.toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
  }

  static List<OwnedPartImportCandidate> importCandidates({
    required Iterable<SavedSetting> savedSettings,
    required Iterable<OwnedPart> ownedParts,
  }) {
    final candidates = <OwnedPartImportCandidate>[];
    final seen = <String>{};

    void addCandidate(String category, dynamic value) {
      if (value is! String || value.trim().isEmpty) {
        return;
      }
      final normalized = normalizeSettingNameOptions(category, [value.trim()]);
      if (normalized.isEmpty) {
        return;
      }
      final normalizedName = normalized.first;
      if (findByName(ownedParts, category, normalizedName) != null) {
        return;
      }
      final identity =
          '${category.toLowerCase()}::${normalizedName.toLowerCase()}';
      if (seen.add(identity)) {
        candidates.add(
          OwnedPartImportCandidate(category: category, name: normalizedName),
        );
      }
    }

    for (final setting in savedSettings) {
      addCandidate('motor', setting.settings['motor']);
      addCandidate('battery', setting.settings['battery']);
      addCandidate('body', setting.settings['body']);
      addCandidate('tire', setting.settings['tire']);
      addCandidate('tire', setting.settings['frontTire']);
      addCandidate('tire', setting.settings['rearTire']);
    }

    candidates.sort((a, b) {
      final categoryCompare = a.category.compareTo(b.category);
      return categoryCompare != 0 ? categoryCompare : a.name.compareTo(b.name);
    });
    return candidates;
  }

  static String? _categoryForSetting(String key) {
    if (key == 'frontTire' || key == 'rearTire') {
      return 'tire';
    }
    return ownedPartCategories.contains(key) ? key : null;
  }
}
