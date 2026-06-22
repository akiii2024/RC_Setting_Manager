import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/manufacturer.dart';
import '../models/owned_part.dart';
import '../providers/settings_provider.dart';
import 'history_page.dart';

String _garageText(bool isEnglish, String en, String ja) => isEnglish ? en : ja;

class MyGaragePage extends StatelessWidget {
  final bool embedded;
  final VoidCallback? onBrowseModels;

  const MyGaragePage({
    super.key,
    this.embedded = false,
    this.onBrowseModels,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final content = _MyGarageContent(
      embedded: embedded,
      onBrowseModels: onBrowseModels,
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_garageText(isEnglish, 'My Garage', 'マイガレージ')),
      ),
      body: content,
    );
  }
}

class _MyGarageContent extends StatelessWidget {
  final bool embedded;
  final VoidCallback? onBrowseModels;

  const _MyGarageContent({
    required this.embedded,
    required this.onBrowseModels,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final isEnglish = settingsProvider.isEnglish;
        final groupedGarageCars =
            settingsProvider.getGarageCarsByManufacturer();

        return ListView(
          padding: EdgeInsets.fromLTRB(16, embedded ? 24 : 16, 16, 24),
          children: [
            _GarageSummaryCard(
              isEnglish: isEnglish,
              totalCars: settingsProvider.garageCars.length,
              onBrowseModels: () => _handleBrowseModels(context),
            ),
            const SizedBox(height: 24),
            _OwnedPartsSection(isEnglish: isEnglish),
            const SizedBox(height: 24),
            if (groupedGarageCars.isEmpty)
              _GarageNoCarsCard(
                isEnglish: isEnglish,
                onBrowseModels: () => _handleBrowseModels(context),
              )
            else
              ...groupedGarageCars.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _ManufacturerGarageSection(
                    manufacturer: entry.key,
                    cars: entry.value,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _handleBrowseModels(BuildContext context) {
    final action = onBrowseModels;
    if (action != null) {
      action();
      return;
    }

    Navigator.pushNamed(context, '/car-selection');
  }
}

class _GarageSummaryCard extends StatelessWidget {
  final bool isEnglish;
  final int totalCars;
  final VoidCallback onBrowseModels;

  const _GarageSummaryCard({
    required this.isEnglish,
    required this.totalCars,
    required this.onBrowseModels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF005BCF),
            Color(0xFF1A73E8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _garageText(isEnglish, 'MY GARAGE', 'マイガレージ'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _garageText(
              isEnglish,
              '$totalCars chassis ready to tune',
              '$totalCars 台のシャーシを管理中',
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _garageText(
              isEnglish,
              'Open a saved chassis directly or browse all models to add more.',
              '保有車種をすぐ開くか、全車種一覧から追加できます。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onBrowseModels,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            icon: const Icon(Icons.manage_search_rounded),
            label: Text(
              _garageText(isEnglish, 'Browse All Models', '車種一覧を見る'),
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _garagePartCategories = ['motor', 'battery', 'body', 'tire'];

String _partCategoryLabel(String category, bool isEnglish) {
  switch (category) {
    case 'motor':
      return _garageText(isEnglish, 'Motor', 'モーター');
    case 'battery':
      return _garageText(isEnglish, 'Battery', 'バッテリー');
    case 'body':
      return _garageText(isEnglish, 'Body', 'ボディ');
    case 'tire':
      return _garageText(isEnglish, 'Tire', 'タイヤ');
  }
  return category;
}

String _candidateKey(OwnedPartImportCandidate candidate) =>
    '${candidate.category}::${candidate.name}';

class _OwnedPartsSection extends StatelessWidget {
  final bool isEnglish;

  const _OwnedPartsSection({
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _garageText(isEnglish, 'Owned Parts', '所持パーツ'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _garageText(
                          isEnglish,
                          'Empty input fields show only these parts first.',
                          '入力欄が空のときは、ここに登録したパーツだけを候補に出します。',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _showPartDialog(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_garageText(isEnglish, 'Add Part', 'パーツを追加')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showImportDialog(context),
                  icon: const Icon(Icons.history_rounded),
                  label: Text(
                    _garageText(isEnglish, 'Import from History', '履歴から追加'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final category in _garagePartCategories) ...[
              _OwnedPartCategoryList(
                category: category,
                isEnglish: isEnglish,
                parts: settingsProvider.getOwnedPartsByCategory(category),
                onEdit: (part) => _showPartDialog(context, part: part),
                onDelete: (part) => _confirmDelete(context, part),
              ),
              if (category != _garagePartCategories.last)
                const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPartDialog(
    BuildContext context, {
    OwnedPart? part,
  }) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    var selectedCategory = part?.category ?? _garagePartCategories.first;
    final controller = TextEditingController(text: part?.name ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                part == null
                    ? _garageText(isEnglish, 'Add Owned Part', '所持パーツを追加')
                    : _garageText(isEnglish, 'Edit Owned Part', '所持パーツを編集'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: InputDecoration(
                      labelText: _garageText(isEnglish, 'Category', 'カテゴリ'),
                    ),
                    items: _garagePartCategories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child:
                                Text(_partCategoryLabel(category, isEnglish)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: _garageText(isEnglish, 'Part Name', 'パーツ名'),
                    ),
                    onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_garageText(isEnglish, 'Cancel', 'キャンセル')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(_garageText(isEnglish, 'Save', '保存')),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !context.mounted) {
      controller.dispose();
      return;
    }

    final name = controller.text;
    controller.dispose();

    if (part == null) {
      final added = await settingsProvider.addOwnedPart(selectedCategory, name);
      if (added == null && context.mounted) {
        _showPartSnackBar(
          context,
          _garageText(
              isEnglish, 'Enter a valid part name.', '有効なパーツ名を入力してください。'),
        );
      }
      return;
    }

    final updated = await settingsProvider.updateOwnedPart(
      part.id,
      category: selectedCategory,
      name: name,
    );
    if (!updated && context.mounted) {
      _showPartSnackBar(
        context,
        _garageText(
          isEnglish,
          'Part name is empty or already registered.',
          'パーツ名が空、または同じカテゴリに登録済みです。',
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, OwnedPart part) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(_garageText(isEnglish, 'Delete Part', 'パーツを削除')),
            content: Text(part.name),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_garageText(isEnglish, 'Cancel', 'キャンセル')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(_garageText(isEnglish, 'Delete', '削除')),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await settingsProvider.deleteOwnedPart(part.id);
    }
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final candidates =
        settingsProvider.getOwnedPartImportCandidatesFromHistory();

    if (candidates.isEmpty) {
      _showPartSnackBar(
        context,
        _garageText(
          isEnglish,
          'No new parts were found in saved settings.',
          '保存済みセッティングに未登録パーツはありません。',
        ),
      );
      return;
    }

    final selectedKeys =
        candidates.map((candidate) => _candidateKey(candidate)).toSet();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedCandidates = candidates
                .where((candidate) =>
                    selectedKeys.contains(_candidateKey(candidate)))
                .toList(growable: false);

            return AlertDialog(
              title: Text(
                _garageText(isEnglish, 'Import from History', '履歴から追加'),
              ),
              content: SizedBox(
                width: 420,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    final key = _candidateKey(candidate);
                    return CheckboxListTile(
                      value: selectedKeys.contains(key),
                      title: Text(candidate.name),
                      subtitle: Text(
                          _partCategoryLabel(candidate.category, isEnglish)),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value ?? false) {
                            selectedKeys.add(key);
                          } else {
                            selectedKeys.remove(key);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(_garageText(isEnglish, 'Cancel', 'キャンセル')),
                ),
                FilledButton(
                  onPressed: selectedCandidates.isEmpty
                      ? null
                      : () async {
                          await settingsProvider
                              .importOwnedPartsFromHistory(selectedCandidates);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  child: Text(_garageText(isEnglish, 'Import', '追加')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPartSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _OwnedPartCategoryList extends StatelessWidget {
  final String category;
  final bool isEnglish;
  final List<OwnedPart> parts;
  final ValueChanged<OwnedPart> onEdit;
  final ValueChanged<OwnedPart> onDelete;

  const _OwnedPartCategoryList({
    required this.category,
    required this.isEnglish,
    required this.parts,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _partCategoryLabel(category, isEnglish),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (parts.isEmpty)
          Text(
            _garageText(isEnglish, 'No parts registered.', '登録済みパーツはありません。'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...parts.map(
            (part) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(part.name),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: _garageText(isEnglish, 'Edit', '編集'),
                    onPressed: () => onEdit(part),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: _garageText(isEnglish, 'Delete', '削除'),
                    onPressed: () => onDelete(part),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ManufacturerGarageSection extends StatelessWidget {
  final Manufacturer manufacturer;
  final List<Car> cars;

  const _ManufacturerGarageSection({
    required this.manufacturer,
    required this.cars,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          manufacturer.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _garageText(
            isEnglish,
            '${cars.length} model${cars.length == 1 ? '' : 's'}',
            '${cars.length} 台を登録中',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...cars.map((car) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GarageCarCard(car: car),
            )),
      ],
    );
  }
}

class _GarageNoCarsCard extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onBrowseModels;

  const _GarageNoCarsCard({
    required this.isEnglish,
    required this.onBrowseModels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.garage_rounded,
              color: colorScheme.primary,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _garageText(
                      isEnglish,
                      'No chassis in My Garage',
                      'マイガレージに車種がありません',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _garageText(
                      isEnglish,
                      'Add a chassis to open its setup history quickly.',
                      '車種を追加すると、履歴をすばやく開けます。',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: onBrowseModels,
                    icon: const Icon(Icons.manage_search_rounded),
                    label: Text(
                      _garageText(isEnglish, 'Browse Models', '車種を探す'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GarageCarCard extends StatelessWidget {
  final Car car;

  const _GarageCarCard({
    required this.car,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: Text(
                    _garageText(
                      isEnglish,
                      '${car.name} History',
                      '${car.name} の履歴',
                    ),
                  ),
                ),
                body: HistoryPage(filterCar: car),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      car.manufacturer.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await settingsProvider.setGarageMembership(
                            car.id, false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _garageText(
                                  isEnglish,
                                  '${car.name} removed from My Garage',
                                  '${car.name} をマイガレージから外しました',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      label: Text(
                        _garageText(
                          isEnglish,
                          'Remove from My Garage',
                          'マイガレージから外す',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _GarageEmptyState extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onBrowseModels;

  const _GarageEmptyState({
    required this.isEnglish,
    required this.onBrowseModels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.garage_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _garageText(
                  isEnglish,
                  'Your garage is empty',
                  'マイガレージはまだ空です',
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _garageText(
                  isEnglish,
                  'Add the models you own so you can open them quickly from one place.',
                  '持っている車種を登録すると、ここからすぐに開けます。',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onBrowseModels,
                icon: const Icon(Icons.manage_search_rounded),
                label: Text(
                  _garageText(isEnglish, 'Browse Models', '車種一覧を開く'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
