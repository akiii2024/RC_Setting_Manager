import 'package:flutter/material.dart';

import '../utils/setting_number_input.dart';

/// 正負の方向と角度を別々に入力する共通欄。
class SignedAngleInputField extends StatefulWidget {
  const SignedAngleInputField({
    super.key,
    required this.settingKey,
    required this.onChanged,
    required this.negativeLabel,
    required this.positiveLabel,
    this.negativeByDefault = true,
    this.initialValue,
    this.unit = '°',
    this.labelText,
    this.errorText,
    this.isEnglish = false,
  });

  final String settingKey;
  final Object? initialValue;
  final ValueChanged<String> onChanged;
  final String? unit;
  final String? labelText;
  final String? errorText;
  final bool isEnglish;
  final String negativeLabel;
  final String positiveLabel;
  final bool negativeByDefault;

  @override
  State<SignedAngleInputField> createState() => _SignedAngleInputFieldState();
}

class _SignedAngleInputFieldState extends State<SignedAngleInputField> {
  late final TextEditingController _controller;
  late String _lastText;
  late bool _negative;
  bool _normalizing = false;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    final text = normalizeSettingNumberInput(
      widget.initialValue?.toString() ?? '0',
    );
    final number = double.tryParse(text);
    // 保存値は入力規則で再解釈せず、その方向を復元する。
    _negative =
        number == null || number == 0 ? widget.negativeByDefault : number < 0;
    _controller = TextEditingController(
      text: text.replaceFirst(RegExp(r'^[+-]'), ''),
    );
    _lastText = _controller.text;
    _controller.addListener(_handleInputChanged);
  }

  String _signedInput(String text) {
    final normalized = normalizeSettingNumberInput(text);
    if (normalized.isEmpty) return '0';
    final number = double.tryParse(normalized);
    if (number == null || !number.isFinite) return normalized;
    final magnitude = normalized.replaceFirst(RegExp(r'^[+-]'), '');
    return '${_negative ? '-' : '+'}$magnitude';
  }

  void _handleInputChanged() {
    if (_normalizing) return;
    final raw = _controller.text;
    final text = normalizeSettingNumberInput(raw);
    final number = double.tryParse(text);
    final validNumber = number != null && number.isFinite;
    final hasSign = text.startsWith('+') || text.startsWith('-');
    final magnitude = validNumber && hasSign ? text.substring(1) : text;
    final composing = _controller.value.composing;
    final composingActive = composing.isValid && !composing.isCollapsed;
    final needsNormalization = !composingActive && raw != magnitude;
    if (raw == _lastText && !needsNormalization) return;
    _lastText = raw;

    // IMEで変換中の文字列には書き戻さず、確定後に表示を整える。
    if (needsNormalization) {
      _normalizing = true;
      final offset = (_controller.selection.extentOffset -
              (validNumber && hasSign ? 1 : 0))
          .clamp(0, magnitude.length);
      _controller.value = TextEditingValue(
        text: magnitude,
        selection: TextSelection.collapsed(offset: offset),
      );
      _lastText = magnitude;
      _normalizing = false;
    }

    setState(() {
      if (hasSign) _negative = text.startsWith('-');
      _invalid = text.isNotEmpty && !validNumber;
    });
    widget.onChanged(_signedInput(magnitude));
  }

  @override
  void dispose() {
    _controller.removeListener(_handleInputChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final negativeLabel = widget.negativeLabel;
    final positiveLabel = widget.positiveLabel;
    final direction = SegmentedButton<bool>(
      key: ValueKey('${widget.settingKey}_direction'),
      segments: [
        ButtonSegment(
          value: true,
          label: Semantics(label: negativeLabel, child: const Text('−')),
          tooltip: negativeLabel,
        ),
        ButtonSegment(
          value: false,
          label: Semantics(label: positiveLabel, child: const Text('+')),
          tooltip: positiveLabel,
        ),
      ],
      selected: {_negative},
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(48, 48)),
      ),
      onSelectionChanged: (selection) {
        setState(() => _negative = selection.single);
        widget.onChanged(_signedInput(_controller.text));
      },
    );
    final angle = TextFormField(
      key: ValueKey(widget.settingKey),
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.labelText ?? (widget.isEnglish ? 'Angle' : '角度'),
        suffixText: widget.unit,
        helperText: _negative ? negativeLabel : positiveLabel,
        helperMaxLines: 3,
        errorMaxLines: 3,
        errorText: _invalid
            ? (widget.isEnglish ? 'Enter a valid number' : '有効な数値を入力してください')
            : widget.errorText,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 幅が狭い紙UIでも方向選択と角度欄の操作領域を確保する。
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [direction, const SizedBox(height: 8), angle],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            direction,
            const SizedBox(width: 8),
            Expanded(child: angle)
          ],
        );
      },
    );
  }
}
