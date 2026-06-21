import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/car_settings_definitions.dart';
import '../data/run_feel_tags.dart';
import '../models/car.dart';
import '../models/car_setting_definition.dart';
import '../models/run_log.dart';
import '../models/saved_setting.dart';
import '../providers/settings_provider.dart';
import '../services/weather_service.dart';
import '../utils/run_log_formatters.dart';
import 'car_setting_page.dart';

String _t(bool isEnglish, String en, String ja) => isEnglish ? en : ja;

typedef WeatherFetcher = Future<WeatherData?> Function({
  bool forceRefresh,
});

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
  return null;
}

class QuickRunLogPage extends StatefulWidget {
  const QuickRunLogPage({
    super.key,
    this.weatherFetcher,
  });

  final WeatherFetcher? weatherFetcher;

  @override
  State<QuickRunLogPage> createState() => _QuickRunLogPageState();
}

class _QuickRunLogPageState extends State<QuickRunLogPage> {
  final TextEditingController _bestLapController = TextEditingController();
  final TextEditingController _airTempController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  final TextEditingController _weatherConditionController =
      TextEditingController();
  final TextEditingController _trackTempController = TextEditingController();
  final TextEditingController _trackConditionController =
      TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final List<RunSettingChange> _changes = [];
  final Set<String> _selectedFeelTagIds = {};

  Car? _selectedCar;
  SavedSetting? _selectedBaseSetting;
  String? _selectedTrackCondition;
  bool _isSaving = false;
  bool _isWeatherLoading = false;
  bool _hasWeatherError = false;
  bool _hasWeatherAttempted = false;
  bool _hasRequestedInitialWeather = false;
  WeatherData? _currentWeather;

  @override
  void dispose() {
    _bestLapController.dispose();
    _airTempController.dispose();
    _humidityController.dispose();
    _weatherConditionController.dispose();
    _trackTempController.dispose();
    _trackConditionController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<WeatherData?> _fetchWeather({bool forceRefresh = false}) {
    final fetcher =
        widget.weatherFetcher ?? WeatherService.instance.getCurrentWeather;
    return fetcher(forceRefresh: forceRefresh);
  }

  void _scheduleInitialWeatherFetch() {
    if (_hasRequestedInitialWeather) {
      return;
    }

    _hasRequestedInitialWeather = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadWeather(overwriteExisting: false);
      }
    });
  }

  Future<void> _loadWeather({
    required bool overwriteExisting,
    bool forceRefresh = false,
  }) async {
    if (_isWeatherLoading || !mounted) {
      return;
    }

    setState(() {
      _isWeatherLoading = true;
      _hasWeatherAttempted = true;
      _hasWeatherError = false;
    });

    WeatherData? weather;
    try {
      weather = await _fetchWeather(forceRefresh: forceRefresh);
    } catch (error) {
      debugPrint('Run log weather fetch failed: $error');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isWeatherLoading = false;
      _currentWeather = weather;
      _hasWeatherError = weather == null;
      if (weather != null) {
        _applyWeatherToInputs(
          weather,
          overwriteExisting: overwriteExisting,
        );
      }
    });
  }

  void _applyWeatherToInputs(
    WeatherData weather, {
    required bool overwriteExisting,
  }) {
    if (overwriteExisting || _airTempController.text.trim().isEmpty) {
      _airTempController.text = weather.temperature.toStringAsFixed(1);
    }
    if (overwriteExisting || _humidityController.text.trim().isEmpty) {
      _humidityController.text = weather.humidity.toString();
    }
    if (overwriteExisting || _weatherConditionController.text.trim().isEmpty) {
      _weatherConditionController.text = weather.description;
    }
  }

  Future<void> _refreshWeather() {
    return _loadWeather(
      overwriteExisting: true,
      forceRefresh: true,
    );
  }

  void _ensureInitialSelection(SettingsProvider provider) {
    if (_selectedCar != null &&
        provider.cars.any((car) => car.id == _selectedCar!.id)) {
      return;
    }

    final latestSetting = _firstOrNull(provider.savedSettings);
    final latestCar = latestSetting == null
        ? null
        : (provider.getCarById(latestSetting.car.id) ?? latestSetting.car);
    final fallbackCar = provider.garageCars.isNotEmpty
        ? provider.garageCars.first
        : _firstOrNull(provider.cars);

    _selectedCar = latestCar ?? fallbackCar;
    _selectedBaseSetting = _selectedCar == null
        ? null
        : provider.getLatestSettingForCar(_selectedCar!.id);
  }

  void _selectCar(SettingsProvider provider, String carId) {
    final car = provider.getCarById(carId);
    if (car == null) {
      return;
    }

    setState(() {
      _selectedCar = car;
      _selectedBaseSetting = provider.getLatestSettingForCar(car.id);
      _changes.clear();
    });
  }

  void _selectBaseSetting(SettingsProvider provider, String settingId) {
    SavedSetting? selected;
    if (settingId.isNotEmpty) {
      for (final setting in provider.savedSettings) {
        if (setting.id == settingId) {
          selected = setting;
          break;
        }
      }
    }

    setState(() {
      _selectedBaseSetting = selected;
      _changes.clear();
    });
  }

  String _trackConditionLabel(String value, bool isEnglish) {
    switch (value) {
      case 'very_good':
        return _t(isEnglish, 'Very good', 'とても良い');
      case 'good':
        return _t(isEnglish, 'Good', '良い');
      case 'normal':
        return _t(isEnglish, 'Normal', '普通');
      case 'bad':
        return _t(isEnglish, 'Bad', '悪い');
      case 'very_bad':
        return _t(isEnglish, 'Very bad', 'とても悪い');
      default:
        return value;
    }
  }

  String _buildTrackConditionText(bool isEnglish) {
    final selected = _selectedTrackCondition == null
        ? ''
        : _trackConditionLabel(_selectedTrackCondition!, isEnglish);
    final note = _trackConditionController.text.trim();

    if (selected.isEmpty) {
      return note;
    }
    if (note.isEmpty) {
      return selected;
    }
    return '$selected - $note';
  }

  Future<void> _addChange(SettingsProvider provider, bool isEnglish) async {
    final car = _selectedCar;
    if (car == null) {
      return;
    }

    final definition = getCarSettingDefinition(car.id);
    if (definition == null || definition.availableSettings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            isEnglish,
            'No setting definition is available for this car.',
            'この車両の設定定義がありません。',
          )),
        ),
      );
      return;
    }

    final change = await showDialog<RunSettingChange>(
      context: context,
      builder: (dialogContext) {
        return _RunChangeDialog(
          settings: definition.availableSettings,
          baseValues:
              _selectedBaseSetting?.settings ?? const <String, dynamic>{},
          isEnglish: isEnglish,
          onOpenDetailedEditor: _openDetailedEditor,
        );
      },
    );

    if (change == null) {
      return;
    }

    setState(() {
      final existingIndex =
          _changes.indexWhere((item) => item.settingKey == change.settingKey);
      if (existingIndex == -1) {
        _changes.add(change);
      } else {
        _changes[existingIndex] = change;
      }
    });
  }

  void _removeChange(RunSettingChange change) {
    setState(() {
      _changes.remove(change);
    });
  }

  void _openDetailedEditor() {
    final car = _selectedCar;
    if (car == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          final baseSetting = _selectedBaseSetting;
          if (baseSetting == null) {
            return CarSettingPage(originalCar: car);
          }

          return CarSettingPage(
            originalCar: car,
            savedSettings: baseSetting.settings,
            settingName: baseSetting.name,
            savedSettingId: baseSetting.id,
          );
        },
      ),
    );
  }

  Future<void> _saveRunLog(SettingsProvider provider, bool isEnglish) async {
    final car = _selectedCar;
    final bestLapMillis = parseBestLapMillis(_bestLapController.text);
    final airTempC = _parseOptionalNumber(_airTempController.text);
    final humidityPercent = _parseOptionalNumber(_humidityController.text);
    final trackTempC = _parseOptionalNumber(_trackTempController.text);

    if (car == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(isEnglish, 'Please select a car.', '車両を選択してください。')),
        ),
      );
      return;
    }

    if (bestLapMillis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            isEnglish,
            'Enter best lap as 13.52 or 0:13.52.',
            'ベストラップは 13.52 または 0:13.52 の形式で入力してください。',
          )),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_isInvalidOptionalNumber(_airTempController.text, airTempC) ||
        _isInvalidOptionalNumber(_humidityController.text, humidityPercent) ||
        _isInvalidOptionalNumber(_trackTempController.text, trackTempC)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            isEnglish,
            'Enter condition values as numbers.',
            'コンディションの数値は数字で入力してください。',
          )),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (humidityPercent != null &&
        (humidityPercent < 0 || humidityPercent > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            isEnglish,
            'Humidity must be between 0 and 100.',
            '湿度は0〜100の範囲で入力してください。',
          )),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await provider.addRunLog(
        runAt: DateTime.now(),
        car: car,
        baseSetting: _selectedBaseSetting,
        bestLapMillis: bestLapMillis,
        airTempC: airTempC,
        humidityPercent: humidityPercent,
        weatherCondition: _weatherConditionController.text,
        trackTempC: trackTempC,
        trackCondition: _buildTrackConditionText(isEnglish),
        feelTagIds: _selectedFeelTagIds.toList(),
        memo: _memoController.text,
        changes: List<RunSettingChange>.from(_changes),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            isEnglish,
            'Run log saved.',
            '走行ログを保存しました。',
          )),
        ),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  double? _parseOptionalNumber(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  bool _isInvalidOptionalNumber(String input, double? parsed) {
    return input.trim().isNotEmpty && parsed == null;
  }

  Widget _buildWeatherStatus(bool isEnglish) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final weather = _currentWeather;

    final Color backgroundColor;
    final Color borderColor;
    final Widget leading;
    final String title;
    final String message;

    if (_isWeatherLoading || !_hasWeatherAttempted) {
      backgroundColor = colorScheme.surfaceContainerLow;
      borderColor = colorScheme.outlineVariant.withValues(alpha: 0.45);
      leading = Icon(
        Icons.cloud_sync,
        color: colorScheme.primary,
      );
      title = _t(isEnglish, 'Loading weather', '天気情報を取得中');
      message = _t(
        isEnglish,
        'Current air temperature and humidity will be filled automatically.',
        '現在の気温と湿度を自動入力します。',
      );
    } else if (_hasWeatherError || weather == null) {
      backgroundColor = colorScheme.errorContainer.withValues(alpha: 0.35);
      borderColor = colorScheme.error.withValues(alpha: 0.35);
      leading = Icon(
        Icons.cloud_off,
        color: colorScheme.error,
      );
      title = _t(
        isEnglish,
        'Weather unavailable',
        '天気情報を取得できません',
      );
      message = _t(
        isEnglish,
        'Use manual input or retry when location and network are available.',
        '位置情報と通信を確認して再取得するか、手動で入力してください。',
      );
    } else {
      backgroundColor = colorScheme.primaryContainer.withValues(alpha: 0.35);
      borderColor = colorScheme.primary.withValues(alpha: 0.30);
      leading = Icon(
        Icons.cloud_done,
        color: colorScheme.primary,
      );
      title = _t(isEnglish, 'Current weather', '現在の天気');
      message =
          '${weather.temperature.toStringAsFixed(1)} C / ${weather.humidity}%'
          ' - ${weather.description}'
          '${weather.cityName.trim().isEmpty ? '' : ' (${weather.cityName})'}';
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _isWeatherLoading ? null : _refreshWeather,
              icon: const Icon(Icons.refresh),
              tooltip: _t(isEnglish, 'Update weather', '天気情報を更新'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        _ensureInitialSelection(provider);

        final isEnglish = provider.isEnglish;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final selectedCar = _selectedCar;
        final carSettings = selectedCar == null
            ? const <SavedSetting>[]
            : provider.getSavedSettingsForCar(selectedCar.id);

        if (selectedCar != null) {
          _scheduleInitialWeatherFetch();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_t(isEnglish, 'Quick Run Log', '走行メモ')),
          ),
          body: selectedCar == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _t(
                        isEnglish,
                        'Add a car before creating run logs.',
                        '走行ログを作成する前に車両を追加してください。',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    children: [
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(isEnglish, 'Run Target', '走行対象'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              key: ValueKey('car-${selectedCar.id}'),
                              initialValue: selectedCar.id,
                              decoration: InputDecoration(
                                labelText: _t(isEnglish, 'Car', '車両'),
                                prefixIcon: const Icon(Icons.directions_car),
                              ),
                              items: provider.cars
                                  .map(
                                    (car) => DropdownMenuItem<String>(
                                      value: car.id,
                                      child: Text(car.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _selectCar(provider, value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'base-${selectedCar.id}-${_selectedBaseSetting?.id ?? ''}',
                              ),
                              initialValue: _selectedBaseSetting?.id ?? '',
                              decoration: InputDecoration(
                                labelText: _t(
                                  isEnglish,
                                  'Base Setting',
                                  'ベース設定',
                                ),
                                prefixIcon: const Icon(Icons.tune),
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: '',
                                  child: Text(_t(
                                    isEnglish,
                                    'No base setting',
                                    'ベース設定なし',
                                  )),
                                ),
                                ...carSettings.map(
                                  (setting) => DropdownMenuItem<String>(
                                    value: setting.id,
                                    child: Text(
                                      setting.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                _selectBaseSetting(provider, value ?? '');
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(isEnglish, 'Conditions', 'コンディション'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildWeatherStatus(isEnglish),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _airTempController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration: InputDecoration(
                                labelText: _t(isEnglish, 'Air Temp', '気温'),
                                suffixText: '°C',
                                prefixIcon: const Icon(Icons.thermostat),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _humidityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: _t(isEnglish, 'Humidity', '湿度'),
                                suffixText: '%',
                                prefixIcon: const Icon(Icons.water_drop),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _weatherConditionController,
                              decoration: InputDecoration(
                                labelText: _t(isEnglish, 'Weather', '天候'),
                                hintText: _t(
                                  isEnglish,
                                  'Sunny, cloudy, rain...',
                                  '晴れ、くもり、雨など',
                                ),
                                prefixIcon: const Icon(Icons.cloud),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _trackTempController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration: InputDecoration(
                                labelText: _t(isEnglish, 'Track Temp', '路面温度'),
                                suffixText: '°C',
                                prefixIcon: const Icon(Icons.device_thermostat),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final value in const [
                                  'very_good',
                                  'good',
                                  'normal',
                                  'bad',
                                  'very_bad',
                                ])
                                  ChoiceChip(
                                    label: Text(
                                      _trackConditionLabel(value, isEnglish),
                                    ),
                                    selected: _selectedTrackCondition == value,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedTrackCondition =
                                            selected ? value : null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _trackConditionController,
                              decoration: InputDecoration(
                                labelText: _t(
                                  isEnglish,
                                  'Track Condition Note',
                                  '路面状況メモ',
                                ),
                                hintText: _t(
                                  isEnglish,
                                  'Low grip, high grip, dusty...',
                                  'グリップ感、ほこり、荒れ具合など',
                                ),
                                prefixIcon: const Icon(Icons.route),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(isEnglish, 'Result', '走行結果'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _bestLapController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: _t(
                                  isEnglish,
                                  'Best Lap',
                                  'ベストラップ',
                                ),
                                hintText: '13.52 / 0:13.52',
                                prefixIcon: const Icon(Icons.timer),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: runFeelTags.map((tag) {
                                final selected =
                                    _selectedFeelTagIds.contains(tag.id);
                                return FilterChip(
                                  label: Text(
                                    isEnglish ? tag.labelEn : tag.labelJa,
                                  ),
                                  selected: selected,
                                  onSelected: (value) {
                                    setState(() {
                                      if (value) {
                                        _selectedFeelTagIds.add(tag.id);
                                      } else {
                                        _selectedFeelTagIds.remove(tag.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _memoController,
                              minLines: 3,
                              maxLines: 6,
                              decoration: InputDecoration(
                                labelText: _t(isEnglish, 'Memo', 'メモ'),
                                hintText: _t(
                                  isEnglish,
                                  'Grip, balance, mistakes, tires...',
                                  'グリップ感、バランス、ミス、タイヤなど',
                                ),
                                prefixIcon: const Icon(Icons.notes),
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _t(
                                      isEnglish,
                                      'Setting Changes',
                                      'セッティング変更',
                                    ),
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _addChange(provider, isEnglish),
                                  icon: const Icon(Icons.add_circle_outline),
                                  tooltip: _t(
                                    isEnglish,
                                    'Add change',
                                    '変更を追加',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_changes.isEmpty)
                              Text(
                                _t(
                                  isEnglish,
                                  'No setting changes recorded.',
                                  'セッティング変更は未入力です。',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              )
                            else
                              ..._changes.map(
                                (change) => _ChangeTile(
                                  change: change,
                                  onRemove: () => _removeChange(change),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              onPressed:
                  _isSaving ? null : () => _saveRunLog(provider, isEnglish),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_t(isEnglish, 'Save Run Log', '走行ログを保存')),
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  final RunSettingChange change;
  final VoidCallback onRemove;

  const _ChangeTile({
    required this.change,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: true,
          title: Text(change.settingLabel),
          subtitle: Text(
            '${change.beforeValue ?? '-'} -> ${change.afterValue ?? '-'}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ),
      ),
    );
  }
}

class _RunChangeDialog extends StatefulWidget {
  final List<SettingItem> settings;
  final Map<String, dynamic> baseValues;
  final bool isEnglish;
  final VoidCallback onOpenDetailedEditor;

  const _RunChangeDialog({
    required this.settings,
    required this.baseValues,
    required this.isEnglish,
    required this.onOpenDetailedEditor,
  });

  @override
  State<_RunChangeDialog> createState() => _RunChangeDialogState();
}

class _RunChangeDialogState extends State<_RunChangeDialog> {
  final TextEditingController _afterController = TextEditingController();
  SettingItem? _selectedSetting;
  String? _selectedOption;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedSetting = _firstOrNull(widget.settings);
    _syncAfterInput();
  }

  @override
  void dispose() {
    _afterController.dispose();
    super.dispose();
  }

  bool get _isSupported {
    final setting = _selectedSetting;
    if (setting == null) {
      return false;
    }
    if (setting.type == 'grid' ||
        setting.constraints.containsKey('composite')) {
      return false;
    }
    return setting.type == 'text' ||
        setting.type == 'number' ||
        setting.type == 'slider' ||
        setting.type == 'select';
  }

  void _selectSetting(String key) {
    final setting = widget.settings.firstWhere((item) => item.key == key);
    setState(() {
      _selectedSetting = setting;
      _errorText = null;
      _syncAfterInput();
    });
  }

  void _syncAfterInput() {
    final setting = _selectedSetting;
    _afterController.clear();
    _selectedOption = null;

    if (setting?.type == 'select') {
      final options = setting?.options ?? const <String>[];
      final beforeValue = widget.baseValues[setting!.key]?.toString();
      _selectedOption = options.contains(beforeValue)
          ? beforeValue
          : (options.isNotEmpty ? options.first : null);
    }
  }

  dynamic _afterValue() {
    final setting = _selectedSetting;
    if (setting == null) {
      return null;
    }

    if (setting.type == 'select') {
      return _selectedOption;
    }

    final text = _afterController.text.trim();
    if (setting.type == 'number' || setting.type == 'slider') {
      return double.tryParse(text);
    }

    return text;
  }

  void _submit() {
    final setting = _selectedSetting;
    if (setting == null || !_isSupported) {
      return;
    }

    final afterValue = _afterValue();
    if (afterValue == null || afterValue.toString().trim().isEmpty) {
      setState(() {
        _errorText = _t(
          widget.isEnglish,
          'Enter the new value.',
          '変更後の値を入力してください。',
        );
      });
      return;
    }

    Navigator.of(context).pop(
      RunSettingChange(
        settingKey: setting.key,
        settingLabel: setting.label,
        beforeValue: widget.baseValues[setting.key],
        afterValue: afterValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setting = _selectedSetting;
    final beforeValue = setting == null ? null : widget.baseValues[setting.key];

    return AlertDialog(
      title: Text(_t(widget.isEnglish, 'Add Setting Change', '変更を追加')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('setting-${setting?.key ?? ''}'),
              initialValue: setting?.key,
              decoration: InputDecoration(
                labelText: _t(widget.isEnglish, 'Setting', '項目'),
              ),
              items: widget.settings
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.key,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _selectSetting(value);
                }
              },
            ),
            const SizedBox(height: 12),
            Text(
              '${_t(widget.isEnglish, 'Current', '変更前')}: ${beforeValue ?? '-'}',
            ),
            const SizedBox(height: 12),
            if (!_isSupported)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t(
                    widget.isEnglish,
                    'This setting uses a detailed editor.',
                    'この項目は詳細編集画面で変更してください。',
                  )),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenDetailedEditor();
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: Text(_t(
                      widget.isEnglish,
                      'Open Detail Editor',
                      '詳細編集を開く',
                    )),
                  ),
                ],
              )
            else if (setting?.type == 'select')
              DropdownButtonFormField<String>(
                key: ValueKey('option-${setting?.key ?? ''}'),
                initialValue: _selectedOption,
                decoration: InputDecoration(
                  labelText: _t(widget.isEnglish, 'New value', '変更後'),
                  errorText: _errorText,
                ),
                items: (setting?.options ?? const <String>[])
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOption = value;
                    _errorText = null;
                  });
                },
              )
            else
              TextField(
                controller: _afterController,
                keyboardType:
                    setting?.type == 'number' || setting?.type == 'slider'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                decoration: InputDecoration(
                  labelText: _t(widget.isEnglish, 'New value', '変更後'),
                  errorText: _errorText,
                ),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() {
                      _errorText = null;
                    });
                  }
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t(widget.isEnglish, 'Cancel', 'キャンセル')),
        ),
        FilledButton(
          onPressed: _isSupported ? _submit : null,
          child: Text(_t(widget.isEnglish, 'Add', '追加')),
        ),
      ],
    );
  }
}
