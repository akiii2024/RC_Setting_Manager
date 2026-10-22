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
  String? _loadError;

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
    _loadError = null;
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
      _loadError = '測定記録を読み込めませんでした。元の設定は保持しています。新しい実測値を入力してください。';
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
            title: const Text('未保存の測定記録'),
            content: const Text('入力内容を破棄しますか？ 保存する場合は画面に戻ってください。'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('入力に戻る')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('破棄する')),
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
        const SnackBar(content: Text('車両、測定時の最終減速比、タイヤ回転数を確認してください。')),
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
          handleSettingsOperationResult(context, result, isEnglish: false);
      if (success) {
        final saved = (result as SettingsOperationSuccess<SavedSetting>).value!;
        setState(() {
          _sourceSettingId = saved.id;
          _baseSettings = Map.of(saved.settings);
          _dirty = false;
          _saved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('測定記録を新しいセットアップとして保存しました。')),
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
            return '0より大きく10億以下の数値を入力してください。';
          }
          return null;
        },
      ),
    );
  }

  Widget _confirmation(String key, String title, String detail) {
    final value = _confirmations[key];
    final state = value == null ? '未確認' : (value ? '確認済み' : '条件外');
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      tristate: true,
      value: value,
      title: Text('$title：$state'),
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
    return _section('ギヤ変更の予測', [
      _number(_targetRatio, 'targetRatio', '変更後の最終減速比'),
      if (validPrediction) ...[
        Text('予測タイヤ回転数 ${predicted.toStringAsFixed(1)} rpm',
            key: const ValueKey('predictedTireRpm'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          predicted > _rules.maxTireRpm
              ? '予測は上限を ${(predicted - _rules.maxTireRpm).toStringAsFixed(1)} rpm 超えています。'
              : '予測上の上限までの余裕 ${(_rules.maxTireRpm - predicted).toStringAsFixed(1)} rpm',
        ),
        if (target! < _rules.minimumFinalDriveRatio)
          Text('変更後の最終減速比が下限 ${_rules.minimumFinalDriveRatio} を下回っています。',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 12),
      ] else
        const Text('測定時の最終減速比・タイヤ回転数と、変更後の最終減速比を入力すると予測できます。'),
      const Text(
          'モーター回転数が同じと仮定した参考値です。電圧・温度・負荷で変わるため、ギヤ変更後は再測定してください。予測値は実測のチェック結果には使いません。'),
      const SizedBox(height: 12),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('変更後のギヤ歯数から計算'),
        children: [
          FinalDriveRatioCalculator(
            key: ValueKey('calculator-$_carId-$_sourceSettingId'),
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
        appBar: AppBar(title: const Text('SUPER GT レギュレーション')),
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
                            _section('車両とセットアップ', [
                              if (car == null)
                                const Text('車両を登録してから測定記録を作成してください。')
                              else
                                DropdownButtonFormField<String>(
                                  key: ValueKey(
                                      'car-${car.id}-$_selectionRevision'),
                                  initialValue: car.id,
                                  isExpanded: true,
                                  decoration:
                                      const InputDecoration(labelText: '車両'),
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
                                decoration: const InputDecoration(
                                    labelText: '設定・保存済みの測定を呼び出す'),
                                items: [
                                  const DropdownMenuItem(
                                      value: '', child: Text('新しい測定')),
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
                              if (_loadError != null) ...[
                                const SizedBox(height: 16),
                                Text(_loadError!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                              ],
                            ]),
                            _section('適用する規則', [
                              const Text('2026年度 4WD／全国統一規則（2026年8月10日更新）'),
                              Text(_rules.title),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<SuperGtPowerSource>(
                                key: ValueKey('power-${_rules.id}'),
                                initialValue: _rules.powerSource,
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: 'パワーソース'),
                                items: const [
                                  DropdownMenuItem(
                                      value: SuperGtPowerSource.hobbywing,
                                      child: Text('Hobbywing 指定コンボ')),
                                  DropdownMenuItem(
                                      value: SuperGtPowerSource.yokomo,
                                      child: Text('ヨコモ 指定コンボ')),
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
                                decoration:
                                    const InputDecoration(labelText: 'ボディグループ'),
                                items: const [
                                  DropdownMenuItem(
                                      value: SuperGtBodyGroup.a,
                                      child: Text('グループ A')),
                                  DropdownMenuItem(
                                      value: SuperGtBodyGroup.b,
                                      child: Text('グループ B')),
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
                              Text(
                                  '最終減速比 ${_rules.minimumFinalDriveRatio} 以上／タイヤ ${_rules.maxTireRpm.toStringAsFixed(0)} rpm 以下\n車重 ${_rules.minCarWeightGrams.toStringAsFixed(0)} g 以上／ボディ ${_rules.minBodyWeightGrams.toStringAsFixed(0)} g 以上'),
                              const SizedBox(height: 8),
                              const Text(
                                  '会場の追加規則・公認品一覧も確認してください。FWD・GT3000・大会独自条件には未対応です。'),
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    await openWebUrl(_rules.sourceUrl);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  '公式規則を開けませんでした。通信状態や端末のブラウザを確認してください。')));
                                    }
                                  }
                                },
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('公式規則・公認品一覧を確認'),
                              ),
                            ]),
                            _section('測定記録（予測の基準）', [
                              Text(
                                  '測定日時：${_measuredAt.toLocal().toString().split('.').first}'),
                              const SizedBox(height: 16),
                              TextFormField(
                                  controller: _motor,
                                  decoration: const InputDecoration(
                                      labelText: 'モーター名・個体メモ'),
                                  onChanged: (_) => _changed()),
                              const SizedBox(height: 16),
                              _number(_ratio, 'measuredRatio', '測定時の最終減速比',
                                  required: true, measured: true),
                              const Text('スパー ÷ ピニオン × 内部減速比の値を入力します。'),
                              const SizedBox(height: 16),
                              _number(_tireRpm, 'measuredTireRpm', '実測タイヤ回転数',
                                  unit: 'rpm', required: true, measured: true),
                              if (measurement != null) ...[
                                Text(
                                    '推定モーター回転数 ${measurement.inferredMotorRpm.toStringAsFixed(1)} rpm',
                                    key: const ValueKey('inferredMotorRpm'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                const SizedBox(height: 8),
                                const Text('実測タイヤ回転数 × 測定時の最終減速比'),
                                const SizedBox(height: 16),
                              ],
                              _number(_carWeight, 'carWeight', '実測車重（ボディを含む）',
                                  unit: 'g', measured: true),
                              _number(_bodyWeight, 'bodyWeight', '実測ボディ重量',
                                  unit: 'g', measured: true),
                              _number(_voltage, 'batteryVoltage', '測定時バッテリー電圧',
                                  unit: 'V', measured: true),
                              TextFormField(
                                  controller: _memo,
                                  decoration: const InputDecoration(
                                      labelText: '大会・コース・温度などの測定メモ'),
                                  minLines: 2,
                                  maxLines: 5,
                                  onChanged: (_) => _changed()),
                            ]),
                            _prediction(measurement),
                            _section('指定品・禁止事項の確認', [
                              const Text(
                                  'タップで「未確認 → 確認済み → 条件外」を切り替えます。実物と公式規則を照合してください。'),
                              _confirmation('powerSource', '車両・パワーソース',
                                  '4WDシャーシと選択した指定モーター／ESCの組合せ、使用設定を確認'),
                              _confirmation(
                                  'body', '公認ボディ', '公認品・グループ・カットラインを確認'),
                              _confirmation('tires', '指定タイヤ',
                                  '開催地指定の銘柄・硬度・購入／マーキング条件を確認'),
                              _confirmation('prohibitedTreatments', '禁止事項',
                                  'グリップ剤・ウォーマー・禁止加工を使用せず、指定クリーナーを確認'),
                            ]),
                            _section('実測・確認結果', [
                              if (measurement == null)
                                const Text(
                                    '測定時の最終減速比とタイヤ回転数を入力してください。未入力項目は条件内として扱いません。')
                              else ...[
                                Text(
                                    measurement.hasFailures
                                        ? '条件外の項目があります'
                                        : measurement.hasUnconfirmed
                                            ? '未確認の項目があります'
                                            : '記録した項目はすべて条件内です',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 16),
                                ...measurement.checks.map((check) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                                switch (check.state) {
                                                  SuperGtCheckState.pass =>
                                                    Icons.check_circle_outline,
                                                  SuperGtCheckState.fail =>
                                                    Icons.error_outline,
                                                  SuperGtCheckState
                                                        .unconfirmed =>
                                                    Icons.help_outline
                                                },
                                                color: check.state ==
                                                        SuperGtCheckState.fail
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .error
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Text(
                                                    '${check.label}：${check.message}')),
                                          ]),
                                    )),
                              ],
                              const Text(
                                  '入力値と手動確認による補助結果です。公式車検の合格を保証するものではありません。'),
                            ]),
                            _section('測定記録を保存', [
                              TextFormField(
                                  key: const ValueKey('measurementName'),
                                  controller: _name,
                                  decoration:
                                      const InputDecoration(labelText: '保存名'),
                                  onChanged: (_) => _changed(),
                                  validator: (value) =>
                                      (value ?? '').trim().isEmpty
                                          ? '保存名を入力してください。'
                                          : null),
                              const SizedBox(height: 12),
                              const Text(
                                  '元のセットアップを残し、測定値・推定モーター回転数・規則の版を新しいセットアップとして保存します。未確認・条件外も記録できます。'),
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
                          ? '保存中…'
                          : _saved
                              ? '保存済み'
                              : '測定記録を保存'),
                    )),
              )),
        ),
      ),
    );
  }
}
