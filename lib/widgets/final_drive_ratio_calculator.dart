import 'package:flutter/material.dart';

import '../data/car_drive_ratios.dart';
import '../models/car.dart';
import '../models/super_gt.dart';
import '../utils/setting_number_input.dart';

/// 歯数から最終減速比を求める。既知の車種は標準内部減速比を初期入力する。
class FinalDriveRatioCalculator extends StatefulWidget {
  const FinalDriveRatioCalculator({
    super.key,
    this.spurTeeth,
    this.pinionTeeth,
    this.carId,
    this.cars = const [],
    this.onCalculated,
    this.isEnglish = false,
  });

  final Object? spurTeeth;
  final Object? pinionTeeth;
  final String? carId;
  final List<Car> cars;
  final ValueChanged<double>? onCalculated;
  final bool isEnglish;

  @override
  State<FinalDriveRatioCalculator> createState() =>
      _FinalDriveRatioCalculatorState();
}

class _FinalDriveRatioCalculatorState extends State<FinalDriveRatioCalculator> {
  final _formKey = GlobalKey<FormState>();
  late final _spur = TextEditingController(text: widget.spurTeeth?.toString());
  late final _pinion =
      TextEditingController(text: widget.pinionTeeth?.toString());
  late String? _selectedCarId = widget.carId;
  late final _internal = TextEditingController(
    text: CarDriveRatios.forCarId(_selectedCarId)?.toString() ?? '',
  );
  double? _result;
  String? _calculationError;

  @override
  void didUpdateWidget(covariant FinalDriveRatioCalculator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.carId != widget.carId) {
      _selectCar(widget.carId);
    }
  }

  void _selectCar(String? carId) {
    _selectedCarId = carId;
    _internal.text = CarDriveRatios.forCarId(carId)?.toString() ?? '';
    _result = null;
    _calculationError = null;
  }

  @override
  void dispose() {
    _spur.dispose();
    _pinion.dispose();
    _internal.dispose();
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(normalizeSettingNumberInput(text));

  Widget _field(TextEditingController controller, String label,
      {bool integer = false, String? helperText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
            labelText: label, helperText: helperText, helperMaxLines: 2),
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: (_) => setState(() {
          _result = null;
          _calculationError = null;
        }),
        validator: (text) {
          final value = _parse(text ?? '');
          if (value == null ||
              !value.isFinite ||
              value <= 0 ||
              (integer && value != value.roundToDouble())) {
            return widget.isEnglish
                ? (integer
                    ? 'Enter a positive whole number.'
                    : 'Enter a positive number.')
                : (integer ? '1以上の整数を入力してください。' : '0より大きい数値を入力してください。');
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final english = widget.isEnglish;
    final standardRatio = CarDriveRatios.forCarId(_selectedCarId);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.cars.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              key: ValueKey('drive-ratio-car-$_selectedCarId'),
              initialValue: _selectedCarId,
              isExpanded: true,
              decoration: InputDecoration(labelText: english ? 'Car' : '車両'),
              items: widget.cars
                  .map((car) =>
                      DropdownMenuItem(value: car.id, child: Text(car.name)))
                  .toList(),
              onChanged: (id) {
                if (id != _selectedCarId) setState(() => _selectCar(id));
              },
            ),
            const SizedBox(height: 16),
          ],
          _field(_spur, english ? 'Spur gear (teeth)' : 'スパーギヤ（歯数）',
              integer: true),
          _field(_pinion, english ? 'Pinion gear (teeth)' : 'ピニオンギヤ（歯数）',
              integer: true),
          _field(_internal, english ? 'Internal drive ratio' : '内部減速比',
              helperText: standardRatio == null
                  ? (english
                      ? 'Enter the ratio for your drivetrain.'
                      : '車両の内部減速比を入力してください。')
                  : (english
                      ? 'Standard: $standardRatio (editable)'
                      : '車種の標準値：$standardRatio（変更可）')),
          Text(
            english
                ? 'Final drive ratio = spur ÷ pinion × internal ratio. Update the internal ratio if you changed the pulleys.'
                : '最終減速比 = スパー ÷ ピニオン × 内部減速比。プーリーを変更した場合は内部減速比を修正してください。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              try {
                final result = SuperGtDriveMath.finalDriveRatio(
                  spurTeeth: _parse(_spur.text)!,
                  pinionTeeth: _parse(_pinion.text)!,
                  internalRatio: _parse(_internal.text)!,
                );
                setState(() {
                  _result = result;
                  _calculationError = null;
                });
                widget.onCalculated?.call(result);
              } on ArgumentError {
                setState(() {
                  _result = null;
                  _calculationError = english
                      ? 'The result is outside the calculable range. Check the values.'
                      : '計算できる範囲を超えています。入力値を確認してください。';
                });
              }
            },
            icon: const Icon(Icons.calculate_outlined),
            label: Text(english ? 'Calculate final drive ratio' : '最終減速比を計算'),
          ),
          if (_calculationError != null)
            Text(_calculationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(
              '${english ? 'Final drive ratio' : '最終減速比'}: ${_result!.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ],
      ),
    );
  }
}
