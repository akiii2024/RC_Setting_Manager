import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/car.dart';
import '../models/saved_setting.dart';
import '../models/settings_operation_result.dart';
import '../models/super_gt.dart';
import '../providers/settings_provider.dart';
import '../utils/external_url_launcher.dart';
import '../utils/setting_number_input.dart';
import '../utils/settings_operation_feedback.dart';
import '../widgets/final_drive_ratio_calculator.dart';

class SuperGtPage extends StatefulWidget {
  const SuperGtPage({
    super.key,
    this.car,
    this.initialSettings = const {},
    this.parentSettingId,
    this.settingName,
  });

  final Car? car;
  final Map<String, dynamic> initialSettings;
  final String? parentSettingId;
  final String? settingName;

  @override
  State<SuperGtPage> createState() => _SuperGtPageState();
}

class _SuperGtPageState extends State<SuperGtPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _motor = TextEditingController();
  final _ratio = TextEditingController();
  final _tireRpm = TextEditingController();
  final _carWeight = TextEditingController();
  final _bodyWeight = TextEditingController();
  final _voltage = TextEditingController();
  final _memo = TextEditingController();
  final _targetRatio = TextEditingController();
  SuperGtRuleProfile _rules = SuperGtRuleProfile.hobbywingA;
  Map<String, bool> _confirmations = {};
  Map<String, dynamic> _baseSettings = {};
  String? _carId;
  String? _sourceSettingId;
  DateTime _measuredAt = DateTime.now();
  bool _saving = false;
  bool _dirty = false;
  bool _saved = false;
  int _selectionRevision = 0;
  bool _hasLoadError = false;

  bool get _isEnglish => context.read<SettingsProvider>().isEnglish;

  String _t(String en, String ja) => _isEnglish ? en : ja;

  @override
  void initState() {
    super.initState();
    _carId = widget.car?.id;
    _loadSettings(widget.initialSettings,
        settingId: widget.parentSettingId, name: widget.settingName);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _motor,
      _ratio,
      _tireRpm,
      _carWeight,
      _bodyWeight,
      _voltage,
      _memo,
      _targetRatio,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static double? _positive(String text) {
    final value = double.tryParse(normalizeSettingNumberInput(text));
    return value != null && value.isFinite && value > 0 && value <= 1000000000
        ? value
        : null;
  }

  static String _text(Object? value) => value?.toString() ?? '';

  void _loadSettings(Map<String, dynamic> settings,
      {String? settingId, String? name}) {
    _baseSettings = Map.of(settings);
    _sourceSettingId = settingId;
    _rules = SuperGtRuleProfile.hobbywingA;
    _confirmations = {};
    _measuredAt = DateTime.now();
    _name.text = name == null ? 'SUPER GT 測定' : '$name / SUPER GT';
    _motor.text = _text(settings['motor']);
    _memo.clear();
    _ratio.clear();
    _tireRpm.clear();
    _carWeight.clear();
    _bodyWeight.clear();
    _voltage.clear();
    _targetRatio.clear();
    _hasLoadError = false;
    try {
      final measurement = SuperGtMeasurement.fromSettings(settings);
      if (measurement != null) {
        if (name != null) _name.text = name;
        _rules = measurement.rules;
        _confirmations = Map.of(measurement.confirmations);
        _measuredAt = measurement.measuredAt;
        _motor.text = measurement.motorName;
        _memo.text = measurement.memo;
        _ratio.text = _text(measurement.finalDriveRatio);
        _tireRpm.text = _text(measurement.tireRpm);
        _carWeight.text = _text(measurement.carWeightGrams);
        _bodyWeight.text = _text(measurement.bodyWeightGrams);
        _voltage.text = _text(measurement.batteryVoltage);
        final raw = settings[SuperGtMeasurement.settingKey] as Map;
        final target = _positive(_text(raw['predictionFinalDriveRatio']));
        _targetRatio.text = _text(target);
      }
    } on FormatException {
      _hasLoadError = true;
    }
    _dirty = false;
    _saved = false;
  }

  Car? _selectedCar(SettingsProvider provider) {
    if (_carId == null) {
      return widget.car ??
          (provider.garageCars.isNotEmpty
              ? provider.garageCars.first
              : provider.cars.firstOrNull);
    }
    return provider.cars.where((car) => car.id == _carId).firstOrNull ??
        (widget.car?.id == _carId ? widget.car : null);
  }

  void _changed({bool measured = false}) {
    setState(() {
      _dirty = true;
      _saved = false;
      if (measured) _measuredAt = DateTime.now();
    });
  }

  SuperGtMeasurement? get _measurement {
    final ratio = _positive(_ratio.text);
    final rpm = _positive(_tireRpm.text);
    if (ratio == null ||
        rpm == null ||
        !(ratio * rpm).isFinite ||
        ratio * rpm <= 0) {
      return null;
    }
    for (final field in [_carWeight, _bodyWeight, _voltage]) {
      if (field.text.trim().isNotEmpty && _positive(field.text) == null) {
        return null;
      }
    }
    return SuperGtMeasurement(
      measuredAt: _measuredAt,
      rules: _rules,
      finalDriveRatio: ratio,
      tireRpm: rpm,
      carWeightGrams: _positive(_carWeight.text),
      bodyWeightGrams: _positive(_bodyWeight.text),
      batteryVoltage: _positive(_voltage.text),
      motorName: _motor.text.trim(),
      memo: _memo.text.trim(),
      confirmations: _confirmations,
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_t('Unsaved Measurement', '未保存の測定記録')),
            content: Text(_t(
                'Discard your changes? Return to the form to save them.',
                '入力内容を破棄しますか？ 保存する場合は画面に戻ってください。')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_t('Keep Editing', '入力に戻る'))),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_t('Discard', '破棄する'))),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final provider = context.read<SettingsProvider>();
    final car = _selectedCar(provider);
    final measurement = _measurement;
    if (car == null || measurement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_t(
                'Check the car, measured final drive ratio, and tire RPM.',
                '車両、測定時の最終減速比、タイヤ回転数を確認してください。'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await provider.addSetting(
        _name.text.trim(),
        car,
        {
          ..._baseSettings,
          SuperGtMeasurement.settingKey: {
            ...measurement.toJson(),
            'inferredMotorRpm': measurement.inferredMotorRpm,
            'predictionFinalDriveRatio': _positive(_targetRatio.text),
          },
        },
        parentSettingId: _sourceSettingId,
      );
      if (!mounted) return;
      final success =
          handleSettingsOperationResult(context, result, isEnglish: _isEnglish);
      if (success) {
        final saved = (result as SettingsOperationSuccess<SavedSetting>).value!;
        setState(() {
          _sourceSettingId = saved.id;
          _baseSettings = Map.of(saved.settings);
          _dirty = false;
          _saved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_t('Measurement saved as a new setup.',
                  '測定記録を新しいセットアップとして保存しました。'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _number(TextEditingController controller, String key, String label,
      {String? unit, bool required = false, bool measured = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey(key),
        controller: controller,
        decoration: InputDecoration(labelText: label, suffixText: unit),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: (_) => _changed(measured: measured),
        validator: (value) {
          if ((value ?? '').trim().isEmpty && !required) return null;
          final number = _positive(value ?? '');
          if (number == null || number > 1000000000) {
            return _t('Enter a number greater than 0 and at most 1 billion.',
                '0より大きく10億以下の数値を入力してください。');
          }
          return null;
        },
      ),
    );
  }

  Widget _confirmation(String key, String title, String detail) {
    final value = _confirmations[key];
    final state = value == null
        ? _t('Unchecked', '未確認')
        : (value ? _t('Confirmed', '確認済み') : _t('Out of spec', '条件外'));
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      tristate: true,
      value: value,
      title: Text(_t('$title: $state', '$title：$state')),
      subtitle: Text(detail),
      onChanged: (_) {
        setState(() {
          if (value == null) {
            _confirmations[key] = true;
          } else if (value) {
            _confirmations[key] = false;
          } else {
            _confirmations.remove(key);
          }
        });
        _changed();
      },
    );
  }

  Widget _prediction(SuperGtMeasurement? measurement) {
    final target = _positive(_targetRatio.text);
    final motorRpm = measurement?.inferredMotorRpm;
    double? predicted;
    if (target != null && motorRpm != null) {
      try {
        predicted = SuperGtDriveMath.predictedTireRpm(
            motorRpm: motorRpm, finalDriveRatio: target);
      } on ArgumentError {
        // 入力途中や表現可能範囲外の値からは予測しない。
      }
    }
    final validPrediction = predicted != null && predicted.isFinite;
    return _section(_t('Gear Change Prediction', 'ギヤ変更の予測'), [
      _number(_targetRatio, 'targetRatio',
          _t('New Final Drive Ratio', '変更後の最終減速比')),
      if (validPrediction) ...[
        Text(
            _t('Predicted tire speed: ${predicted.toStringAsFixed(1)} rpm',
                '予測タイヤ回転数 ${predicted.toStringAsFixed(1)} rpm'),
            key: const ValueKey('predictedTireRpm'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          predicted > _rules.maxTireRpm
              ? _t(
                  'Predicted tire speed exceeds the limit by ${(predicted - _rules.maxTireRpm).toStringAsFixed(1)} rpm.',
                  '予測は上限を ${(predicted - _rules.maxTireRpm).toStringAsFixed(1)} rpm 超えています。')
              : _t(
                  'Predicted headroom: ${(_rules.maxTireRpm - predicted).toStringAsFixed(1)} rpm',
                  '予測上の上限までの余裕 ${(_rules.maxTireRpm - predicted).toStringAsFixed(1)} rpm'),
        ),
        if (target! < _rules.minimumFinalDriveRatio)
          Text(
              _t('The new final drive ratio is below the minimum of ${_rules.minimumFinalDriveRatio}.',
                  '変更後の最終減速比が下限 ${_rules.minimumFinalDriveRatio} を下回っています。'),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 12),
      ] else
        Text(_t(
            'Enter the measured final drive ratio and tire RPM, then enter the new final drive ratio to see a prediction.',
            '測定時の最終減速比・タイヤ回転数と、変更後の最終減速比を入力すると予測できます。')),
      Text(_t(
          'This estimate assumes the same motor RPM. Voltage, temperature, and load can affect the result, so measure again after changing gears. Only measured values are used for compliance checks.',
          'モーター回転数が同じと仮定した参考値です。電圧・温度・負荷で変わるため、ギヤ変更後は再測定してください。予測値は実測のチェック結果には使いません。')),
      const SizedBox(height: 12),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(_t('Calculate from New Gear Tooth Counts', '変更後のギヤ歯数から計算')),
        children: [
          FinalDriveRatioCalculator(
            key: ValueKey('calculator-$_carId-$_sourceSettingId'),
            isEnglish: _isEnglish,
            carId: _selectedCar(context.read<SettingsProvider>())?.id,
            spurTeeth: _baseSettings['spurGear'],
            pinionTeeth: _baseSettings['pinionGear'],
            onCalculated: (ratio) {
              _targetRatio.text = ratio.toString();
              _changed();
            },
          ),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final car = _selectedCar(provider);
    final cars = [...provider.cars];
    if (car != null && !cars.any((item) => item.id == car.id)) cars.add(car);
    final savedSettings = provider.savedSettings
        .where((setting) => setting.car.id == car?.id)
        .toList();
    final sourceExists =
        savedSettings.any((setting) => setting.id == _sourceSettingId);
    final measurement = _measurement;
    return PopScope(
      canPop: !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saving) return;
        if (await _confirmDiscard() && mounted) {
          setState(() => _dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(_t('SUPER GT Regulations', 'SUPER GT レギュレーション'))),
        body: !provider.isInitialized
            ? const Center(child: CircularProgressIndicator())
            : AbsorbPointer(
                absorbing: _saving,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _section(_t('Car and Setup', '車両とセットアップ'), [
                              if (car == null)
                                Text(_t(
                                    'Add a car before creating a measurement record.',
                                    '車両を登録してから測定記録を作成してください。'))
                              else
                                DropdownButtonFormField<String>(
                                  key: ValueKey(
                                      'car-${car.id}-$_selectionRevision'),
                                  initialValue: car.id,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                      labelText: _t('Car', '車両')),
                                  items: cars
                                      .map((item) => DropdownMenuItem(
                                          value: item.id,
                                          child: Text(item.name)))
                                      .toList(),
                                  onChanged: (id) async {
                                    if (id == null || id == car.id) return;
                                    final discard = await _confirmDiscard();
                                    if (!mounted) return;
                                    if (!discard) {
                                      setState(() => _selectionRevision++);
                                      return;
                                    }
                                    setState(() {
                                      _carId = id;
                                      _loadSettings({});
                                    });
                                  },
                                ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                key: ValueKey(
                                    'source-${sourceExists ? _sourceSettingId : ''}-${car?.id}-$_selectionRevision'),
                                initialValue:
                                    sourceExists ? _sourceSettingId : '',
                                isExpanded: true,
                                decoration: InputDecoration(
                                    labelText: _t('Load a Setup or Measurement',
                                        '設定・保存済みの測定を呼び出す')),
                                items: [
                                  DropdownMenuItem(
                                      value: '',
                                      child:
                                          Text(_t('New Measurement', '新しい測定'))),
                                  ...savedSettings.map((setting) =>
                                      DropdownMenuItem(
                                          value: setting.id,
                                          child: Text(setting.name,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis))),
                                ],
                                onChanged: (id) async {
                                  if (id == null) return;
                                  final discard = await _confirmDiscard();
                                  if (!mounted) return;
                                  if (!discard) {
                                    setState(() => _selectionRevision++);
                                    return;
                                  }
                                  final selected = savedSettings
                                      .where((item) => item.id == id)
                                      .firstOrNull;
                                  setState(() => _loadSettings(
                                      selected?.settings ?? {},
                                      settingId: selected?.id,
                                      name: selected?.name));
                                },
                              ),
                              if (_hasLoadError) ...[
                                const SizedBox(height: 16),
                                Text(
                                    _t('Could not load the measurement. Your original setup is intact. Enter new measured values.',
                                        '測定記録を読み込めませんでした。元の設定は保持しています。新しい実測値を入力してください。'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                              ],
                            ]),
                            _section(_t('Applicable Rules', '適用する規則'), [
                              Text(_t(
                                  '2026 National 4WD Rules (updated August 10, 2026)',
                                  '2026年度 4WD／全国統一規則（2026年8月10日更新）')),
                              Text(_rules.title),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<SuperGtPowerSource>(
                                key: ValueKey('power-${_rules.id}'),
                                initialValue: _rules.powerSource,
                                isExpanded: true,
                                decoration: InputDecoration(
                                    labelText: _t('Power Source', 'パワーソース')),
                                items: [
                                  DropdownMenuItem(
                                      value: SuperGtPowerSource.hobbywing,
                                      child: Text(_t('Approved Hobbywing Combo',
                                          'Hobbywing 指定コンボ'))),
                                  DropdownMenuItem(
                                      value: SuperGtPowerSource.yokomo,
                                      child: Text(_t('Approved Yokomo Combo',
                                          'ヨコモ 指定コンボ'))),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _rules = SuperGtRuleProfile.for4wd(
                                        value, _rules.bodyGroup);
                                    _confirmations.remove('powerSource');
                                  });
                                  _changed();
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<SuperGtBodyGroup>(
                                key: ValueKey('group-${_rules.id}'),
                                initialValue: _rules.bodyGroup,
                                decoration: InputDecoration(
                                    labelText: _t('Body Group', 'ボディグループ')),
                                items: [
                                  DropdownMenuItem(
                                      value: SuperGtBodyGroup.a,
                                      child: Text(_t('Group A', 'グループ A'))),
                                  DropdownMenuItem(
                                      value: SuperGtBodyGroup.b,
                                      child: Text(_t('Group B', 'グループ B'))),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _rules = SuperGtRuleProfile.for4wd(
                                        _rules.powerSource, value);
                                    _confirmations.remove('body');
                                  });
                                  _changed();
                                },
                              ),
                              const SizedBox(height: 16),
                              Text(_t(
                                  'Min. final drive ratio: ${_rules.minimumFinalDriveRatio} / Max. tire speed: ${_rules.maxTireRpm.toStringAsFixed(0)} rpm\nMin. car weight: ${_rules.minCarWeightGrams.toStringAsFixed(0)} g / Min. body weight: ${_rules.minBodyWeightGrams.toStringAsFixed(0)} g',
                                  '最終減速比 ${_rules.minimumFinalDriveRatio} 以上／タイヤ ${_rules.maxTireRpm.toStringAsFixed(0)} rpm 以下\n車重 ${_rules.minCarWeightGrams.toStringAsFixed(0)} g 以上／ボディ ${_rules.minBodyWeightGrams.toStringAsFixed(0)} g 以上')),
                              const SizedBox(height: 8),
                              Text(_t(
                                  'Check any additional venue rules and the approved parts list. FWD, GT3000, and event-specific requirements are outside the scope of these checks.',
                                  '会場の追加規則・公認品一覧も確認してください。FWD・GT3000・大会独自条件には未対応です。')),
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    await openWebUrl(_rules.sourceUrl);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(_t(
                                                  'Could not open the official rules. Check your connection and browser.',
                                                  '公式規則を開けませんでした。通信状態や端末のブラウザを確認してください。'))));
                                    }
                                  }
                                },
                                icon: const Icon(Icons.open_in_new),
                                label: Text(_t(
                                    'View Official Rules and Approved Parts',
                                    '公式規則・公認品一覧を確認')),
                              ),
                            ]),
                            _section(
                                _t('Baseline Measurements', '測定記録（予測の基準）'), [
                              Text(_t(
                                  'Measured at: ${_measuredAt.toLocal().toString().split('.').first}',
                                  '測定日時：${_measuredAt.toLocal().toString().split('.').first}')),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _motor,
                                  decoration: InputDecoration(
                                      labelText: _t(
                                          'Motor Name or Notes', 'モーター名・個体メモ')),
                                  onChanged: (_) => _changed()),
                              const SizedBox(height: 16),
                              _number(_ratio, 'measuredRatio',
                                  _t('Measured Final Drive Ratio', '測定時の最終減速比'),
                                  required: true, measured: true),
                              Text(_t(
                                  'Enter (spur teeth ÷ pinion teeth) × internal drive ratio.',
                                  'スパー ÷ ピニオン × 内部減速比の値を入力します。')),
                              const SizedBox(height: 16),
                              _number(_tireRpm, 'measuredTireRpm',
                                  _t('Measured Tire Speed', '実測タイヤ回転数'),
                                  unit: 'rpm', required: true, measured: true),
                              if (measurement != null) ...[
                                Text(
                                    _t('Estimated motor speed: ${measurement.inferredMotorRpm.toStringAsFixed(1)} rpm',
                                        '推定モーター回転数 ${measurement.inferredMotorRpm.toStringAsFixed(1)} rpm'),
                                    key: const ValueKey('inferredMotorRpm'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                const SizedBox(height: 8),
                                Text(_t(
                                    'Measured tire RPM × measured final drive ratio',
                                    '実測タイヤ回転数 × 測定時の最終減速比')),
                                const SizedBox(height: 16),
                              ],
                              _number(
                                  _carWeight,
                                  'carWeight',
                                  _t('Measured Car Weight (with Body)',
                                      '実測車重（ボディを含む）'),
                                  unit: 'g',
                                  measured: true),
                              _number(_bodyWeight, 'bodyWeight',
                                  _t('Measured Body Weight', '実測ボディ重量'),
                                  unit: 'g', measured: true),
                              _number(
                                  _voltage,
                                  'batteryVoltage',
                                  _t('Battery Voltage at Measurement',
                                      '測定時バッテリー電圧'),
                                  unit: 'V',
                                  measured: true),
                              TextFormField(
                                  controller: _memo,
                                  decoration: InputDecoration(
                                      labelText: _t(
                                          'Measurement Notes (event, track, temperature, etc.)',
                                          '大会・コース・温度などの測定メモ')),
                                  minLines: 2,
                                  maxLines: 5,
                                  onChanged: (_) => _changed()),
                            ]),
                            _prediction(measurement),
                            _section(
                                _t('Parts and Prohibited Practices',
                                    '指定品・禁止事項の確認'),
                                [
                                  Text(_t(
                                      'Tap to cycle through Unchecked → Confirmed → Out of spec. Inspect the actual car against the official rules.',
                                      'タップで「未確認 → 確認済み → 条件外」を切り替えます。実物と公式規則を照合してください。')),
                                  _confirmation(
                                      'powerSource',
                                      _t('Car and Power Source', '車両・パワーソース'),
                                      _t('Check the 4WD chassis, selected approved motor and ESC combo, and settings.',
                                          '4WDシャーシと選択した指定モーター／ESCの組合せ、使用設定を確認')),
                                  _confirmation(
                                      'body',
                                      _t('Approved Body', '公認ボディ'),
                                      _t('Check approval, body group, and cut lines.',
                                          '公認品・グループ・カットラインを確認')),
                                  _confirmation(
                                      'tires',
                                      _t('Specified Tires', '指定タイヤ'),
                                      _t('Check the tire model, hardness, and purchase or marking requirements for the venue.',
                                          '開催地指定の銘柄・硬度・購入／マーキング条件を確認')),
                                  _confirmation(
                                      'prohibitedTreatments',
                                      _t('Prohibited Practices', '禁止事項'),
                                      _t('Avoid tire additives, warmers, and prohibited modifications. Check the specified cleaner.',
                                          'グリップ剤・ウォーマー・禁止加工を使用せず、指定クリーナーを確認')),
                                ]),
                            _section(
                                _t('Measurement and Check Results', '実測・確認結果'),
                                [
                                  if (measurement == null)
                                    Text(_t(
                                        'Enter the measured final drive ratio and tire RPM. Blank items remain unchecked.',
                                        '測定時の最終減速比とタイヤ回転数を入力してください。未入力項目は条件内として扱いません。'))
                                  else ...[
                                    Text(
                                        measurement.hasFailures
                                            ? _t('Some items are out of spec.',
                                                '条件外の項目があります')
                                            : measurement.hasUnconfirmed
                                                ? _t(
                                                    'Some items still need checking.',
                                                    '未確認の項目があります')
                                                : _t(
                                                    'All recorded items meet the requirements.',
                                                    '記録した項目はすべて条件内です'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 16),
                                    ...measurement
                                        .localizedChecks(isEnglish: _isEnglish)
                                        .map((check) => Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 12),
                                              child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                        switch (check.state) {
                                                          SuperGtCheckState
                                                                .pass =>
                                                            Icons
                                                                .check_circle_outline,
                                                          SuperGtCheckState
                                                                .fail =>
                                                            Icons.error_outline,
                                                          SuperGtCheckState
                                                                .unconfirmed =>
                                                            Icons.help_outline
                                                        },
                                                        color: check.state ==
                                                                SuperGtCheckState
                                                                    .fail
                                                            ? Theme.of(context)
                                                                .colorScheme
                                                                .error
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                        child: Text(_t(
                                                            '${check.label}: ${check.message}',
                                                            '${check.label}：${check.message}'))),
                                                  ]),
                                            )),
                                  ],
                                  Text(_t(
                                      'These results are based on your entries and manual checks. Passing official scrutineering is subject to a separate inspection.',
                                      '入力値と手動確認による補助結果です。公式車検の合格を保証するものではありません。')),
                                ]),
                            _section(_t('Save Measurement', '測定記録を保存'), [
                              TextFormField(
                                  key: const ValueKey('measurementName'),
                                  controller: _name,
                                  decoration: InputDecoration(
                                      labelText: _t('Setup Name', '保存名')),
                                  onChanged: (_) => _changed(),
                                  validator: (value) =>
                                      (value ?? '').trim().isEmpty
                                          ? _t('Enter a name for the setup.',
                                              '保存名を入力してください。')
                                          : null),
                              const SizedBox(height: 12),
                              Text(_t(
                                  'Save the measurements, estimated motor RPM, and rule version as a new setup. The original setup stays intact. You can also save unchecked and out-of-spec items.',
                                  '元のセットアップを残し、測定値・推定モーター回転数・規則の版を新しいセットアップとして保存します。未確認・条件外も記録できます。')),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('saveMeasurement'),
                      onPressed: _saving ||
                              _saved ||
                              car == null ||
                              !provider.isInitialized
                          ? null
                          : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving
                          ? _t('Saving…', '保存中…')
                          : _saved
                              ? _t('Saved', '保存済み')
                              : _t('Save Measurement', '測定記録を保存')),
                    )),
              )),
        ),
      ),
    );
  }
}
