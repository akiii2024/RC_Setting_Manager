import 'package:flutter/material.dart';

import '../models/super_gt.dart';
import '../utils/setting_number_input.dart';

/// 歯数から最終減速比を求める。内部減速比は車両の実際の構成を入力する。
class FinalDriveRatioCalculator extends StatefulWidget {
  const FinalDriveRatioCalculator({
    super.key,
    this.spurTeeth,
    this.pinionTeeth,
    this.onCalculated,
    this.isEnglish = false,
  });

  final Object? spurTeeth;
  final Object? pinionTeeth;
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
  final _internal = TextEditingController();
  double? _result;
  String? _calculationError;

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
      {bool integer = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
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
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(_spur, english ? 'Spur gear (teeth)' : 'スパーギヤ（歯数）',
              integer: true),
          _field(_pinion, english ? 'Pinion gear (teeth)' : 'ピニオンギヤ（歯数）',
              integer: true),
          _field(_internal, english ? 'Internal drive ratio' : '内部減速比'),
          Text(
            english
                ? 'Final drive ratio = spur ÷ pinion × internal ratio. Check the internal ratio for your actual drivetrain.'
                : '最終減速比 = スパー ÷ ピニオン × 内部減速比。内部減速比は車両の実際の構成を確認して入力してください。',
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
