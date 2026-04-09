import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/manufacturer.dart';
import '../providers/settings_provider.dart';
import 'car_setting_page.dart';

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

        if (groupedGarageCars.isEmpty) {
          return _GarageEmptyState(
            isEnglish: isEnglish,
            onBrowseModels: () => _handleBrowseModels(context),
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(16, embedded ? 24 : 16, 16, 24),
          children: [
            _GarageSummaryCard(
              isEnglish: isEnglish,
              totalCars: settingsProvider.garageCars.length,
              onBrowseModels: () => _handleBrowseModels(context),
            ),
            const SizedBox(height: 24),
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
              builder: (context) => CarSettingPage(originalCar: car),
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
