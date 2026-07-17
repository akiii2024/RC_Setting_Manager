import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_advisor.dart';
import '../models/car.dart';
import '../models/car_setting_definition.dart';
import '../models/saved_setting.dart';
import '../models/track_location.dart';
import '../providers/settings_provider.dart';
import '../services/ai_advisor_context_builder.dart';
import '../services/ai_advisor_service.dart';
import '../services/weather_service.dart';
import '../widgets/gemini_usage_indicator.dart';

class AISettingAdvisorPage extends StatefulWidget {
  final Car car;
  final Map<String, dynamic> currentSettings;
  final Map<String, dynamic> initialSettings;
  final CarSettingDefinition settingDefinition;
  final String settingName;
  final String? savedSettingId;
  final TrackLocation? trackInfo;
  final WeatherData? weatherInfo;
  final bool isEnglish;
  final AIAdvisorService? advisorService;

  const AISettingAdvisorPage({
    super.key,
    required this.car,
    required this.currentSettings,
    required this.initialSettings,
    required this.settingDefinition,
    required this.settingName,
    this.savedSettingId,
    this.trackInfo,
    this.weatherInfo,
    required this.isEnglish,
    this.advisorService,
  });

  @override
  State<AISettingAdvisorPage> createState() => _AISettingAdvisorPageState();
}

class _AISettingAdvisorPageState extends State<AISettingAdvisorPage> {
  static const Map<String, List<String>> _symptomLabels = {
    'push': ['曲がらない', 'Push / understeer'],
    'spin': ['巻く', 'Spin'],
    'loose_rear': ['リアが軽い', 'Loose rear'],
    'no_power': ['握れない', 'Hard to apply power'],
    'bounce': ['跳ねる', 'Bounces'],
    'unstable': ['不安定', 'Unstable'],
    'other': ['その他', 'Other'],
  };

  static const Map<String, List<String>> _phaseLabels = {
    'braking': ['ブレーキ', 'Braking'],
    'corner_entry': ['コーナー進入', 'Corner entry'],
    'mid_corner': ['コーナー中間', 'Mid-corner'],
    'corner_exit': ['立ち上がり', 'Corner exit'],
    'on_power': ['加速時', 'On power'],
    'high_speed': ['高速', 'High speed'],
    'low_speed': ['低速', 'Low speed'],
    'bumps': ['ギャップ', 'Bumps'],
    'unknown': ['不明', 'Unknown'],
  };

  static const Map<String, List<String>> _severityLabels = {
    'mild': ['軽い', 'Mild'],
    'medium': ['中程度', 'Medium'],
    'severe': ['深刻', 'Severe'],
  };

  static const Map<String, List<String>> _gripLabels = {
    'low': ['低い', 'Low'],
    'medium': ['普通', 'Medium'],
    'high': ['高い', 'High'],
    'changing': ['変化する', 'Changing'],
    'unknown': ['不明', 'Unknown'],
  };

  static const Map<String, List<String>> _goalLabels = {
    'balanced': ['扱いやすいバランス', 'Balanced handling'],
    'stability': ['安定性', 'Stability'],
    'rotation': ['旋回性', 'Rotation'],
    'traction': ['トラクション', 'Traction'],
    'lap_time': ['ラップタイム', 'Lap time'],
    'tire_life': ['タイヤ寿命', 'Tire life'],
    'other': ['その他', 'Other'],
  };

  late final AIAdvisorService _advisorService;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  late final TextEditingController _derivedNameController;
  final Set<String> _symptoms = {};
  final Set<String> _phases = {};
  final List<AdvisorMessage> _messages = [];
  final Set<int> _selectedChangeIndexes = {};
  final Map<int, dynamic> _validatedChanges = {};

  AIAdvisorContext? _advisorContext;
  AIAdvisorIntake? _intake;
  AISettingAdvice? _advice;
  int _step = 0;
  int _userFollowups = 0;
  bool _includeHistory = true;
  bool _isLoading = false;
  bool _readyForAdvice = false;
  String _severity = 'medium';
  String _trackGrip = 'unknown';
  String _goal = 'balanced';

  bool get _isEnglish => widget.isEnglish;

  @override
  void initState() {
    super.initState();
    _advisorService = widget.advisorService ?? AIAdvisorService();
    final baseName = widget.settingName.trim().isEmpty
        ? widget.car.name
        : widget.settingName.trim();
    _derivedNameController = TextEditingController(
      text: _isEnglish ? '$baseName-AI suggestion' : '$baseName-AI提案',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_advisorContext != null) return;
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final autoFilledKeys = <String>{
      if (widget.trackInfo != null) 'surface',
      if (widget.weatherInfo != null) ...{
        'airTemp',
        'humidity',
        'condition',
      },
    };
    _advisorContext = AIAdvisorContextBuilder.build(
      car: widget.car,
      settingName: widget.settingName,
      currentSettings: widget.currentSettings,
      settingDefinition: widget.settingDefinition,
      runLogs: settingsProvider.runLogs,
      isSavedSetting: widget.savedSettingId != null,
      isEnglish: _isEnglish,
      activeSettingId: widget.savedSettingId,
      initialSettings: widget.initialSettings,
      autoFilledKeys: autoFilledKeys,
      track: widget.trackInfo,
      weather: widget.weatherInfo,
    );
  }

  String _label(Map<String, List<String>> labels, String key) {
    final values = labels[key];
    if (values == null) return key;
    return values[_isEnglish ? 1 : 0];
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  AIAdvisorIntake _createIntake() {
    return AIAdvisorIntake(
      symptoms: _symptoms.toList(growable: false),
      phases: _phases.toList(growable: false),
      severity: _severity,
      trackGrip: _trackGrip,
      goal: _goal,
      notes: _notesController.text,
    );
  }

  Future<void> _startConversation() async {
    if (_symptoms.isEmpty || _phases.isEmpty) {
      _showMessage(
        _isEnglish
            ? 'Select at least one symptom and one phase.'
            : '症状と発生場面を1つ以上選択してください。',
      );
      return;
    }
    final context = _advisorContext;
    if (context == null) return;

    final intake = _createIntake();
    setState(() {
      _isLoading = true;
      _intake = intake;
    });
    try {
      final turn = await _advisorService.continueStructuredConversation(
        context: context,
        intake: intake,
        messages: const [],
        isEnglish: _isEnglish,
        includeHistory: _includeHistory,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          AdvisorMessage(role: AdvisorMessageRole.model, text: turn.message),
        );
        _readyForAdvice = turn.readyForAdvice;
        _step = 1;
      });
    } catch (e) {
      _showMessage(
        _isEnglish
            ? 'Failed to start AI consultation: $e'
            : 'AI相談を開始できませんでした: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final context = _advisorContext;
    final intake = _intake;
    if (text.isEmpty || context == null || intake == null || _isLoading) {
      return;
    }
    if (_userFollowups >= 2) {
      _showMessage(
        _isEnglish
            ? 'Generate advice with the information collected so far.'
            : 'ここまでの情報で提案を生成してください。',
      );
      return;
    }

    final userMessage = AdvisorMessage(
      role: AdvisorMessageRole.user,
      text: text,
    );
    setState(() {
      _messages.add(userMessage);
      _userFollowups += 1;
      _isLoading = true;
      _messageController.clear();
    });

    try {
      final turn = await _advisorService.continueStructuredConversation(
        context: context,
        intake: intake,
        messages: List<AdvisorMessage>.from(_messages),
        isEnglish: _isEnglish,
        includeHistory: _includeHistory,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          AdvisorMessage(role: AdvisorMessageRole.model, text: turn.message),
        );
        _readyForAdvice = turn.readyForAdvice || _userFollowups >= 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && identical(_messages.last, userMessage)) {
          _messages.removeLast();
          _userFollowups -= 1;
        }
      });
      _showMessage(_isEnglish ? 'Failed to send: $e' : '送信に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateAdvice() async {
    final context = _advisorContext;
    final intake = _intake;
    if (context == null || intake == null || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final advice = await _advisorService.generateStructuredAdvice(
        context: context,
        intake: intake,
        messages: List<AdvisorMessage>.from(_messages),
        isEnglish: _isEnglish,
        includeHistory: _includeHistory,
      );
      if (!mounted) return;

      final validated = <int, dynamic>{};
      for (var index = 0; index < advice.changes.length; index += 1) {
        final value = AIAdvisorContextBuilder.validatedProposedValue(
          change: advice.changes[index],
          settingDefinition: widget.settingDefinition,
          currentSettings: widget.currentSettings,
        );
        if (value != null) validated[index] = value;
      }

      setState(() {
        _advice = advice;
        _validatedChanges
          ..clear()
          ..addAll(validated);
        _selectedChangeIndexes.clear();
        if (validated.isNotEmpty) {
          _selectedChangeIndexes.add(validated.keys.first);
        }
        _step = 2;
      });
    } catch (e) {
      _showMessage(
        _isEnglish ? 'Failed to generate advice: $e' : '提案の生成に失敗しました: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  SavedSetting? _findSavedSetting(SettingsProvider provider, String? id) {
    if (id == null) return null;
    for (final setting in provider.savedSettings) {
      if (setting.id == id) return setting;
    }
    return null;
  }

  Future<void> _createDerivedSetting() async {
    if (_selectedChangeIndexes.isEmpty || _isLoading) return;
    final name = _derivedNameController.text.trim();
    if (name.isEmpty) {
      _showMessage(
        _isEnglish ? 'Enter a setting name.' : 'セッティング名を入力してください。',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<SettingsProvider>(context, listen: false);
      var baseSetting = _findSavedSetting(provider, widget.savedSettingId);
      baseSetting ??= await provider.addSetting(
        widget.settingName.trim().isEmpty
            ? widget.car.name
            : widget.settingName.trim(),
        widget.car,
        Map<String, dynamic>.from(widget.currentSettings),
      );

      final derivedSettings = Map<String, dynamic>.from(widget.currentSettings);
      for (final index in _selectedChangeIndexes) {
        final value = _validatedChanges[index];
        if (value != null) {
          derivedSettings[_advice!.changes[index].settingKey] = value;
        }
      }

      final derived = await provider.addSetting(
        name,
        widget.car,
        derivedSettings,
        kind: SavedSettingKind.aiSuggestion,
        parentSettingId: baseSetting.id,
      );
      if (mounted) Navigator.of(context).pop(derived);
    } catch (e) {
      _showMessage(
        _isEnglish
            ? 'Failed to save the derived setting: $e'
            : '派生セットを保存できませんでした: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEnglish ? 'AI Setup Advisor' : 'AIセッティング相談'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_step + 1) / 3,
              minHeight: 3,
            ),
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: switch (_step) {
                0 => _buildIntake(),
                1 => _buildConversation(),
                _ => _buildResult(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntake() {
    final contextData = _advisorContext;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _isEnglish
              ? 'Describe when the handling problem occurs.'
              : '症状と、どの場面で発生するかを入力してください。',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        _chipSection(
          title: _isEnglish ? 'Symptoms (required)' : '症状（必須）',
          labels: _symptomLabels,
          selected: _symptoms,
        ),
        const SizedBox(height: 16),
        _chipSection(
          title: _isEnglish ? 'Phase (required)' : '発生場面（必須）',
          labels: _phaseLabels,
          selected: _phases,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _dropdown(
                title: _isEnglish ? 'Severity' : '深刻度',
                labels: _severityLabels,
                value: _severity,
                onChanged: (value) => setState(() => _severity = value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdown(
                title: _isEnglish ? 'Track grip' : '路面グリップ',
                labels: _gripLabels,
                value: _trackGrip,
                onChanged: (value) => setState(() => _trackGrip = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _dropdown(
          title: _isEnglish ? 'Goal' : '目標',
          labels: _goalLabels,
          value: _goal,
          onChanged: (value) => setState(() => _goal = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLength: 1000,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: _isEnglish ? 'Additional details' : '補足',
            hintText: _isEnglish
                ? 'Tire condition, frequency, recent changes, etc.'
                : 'タイヤの状態、再現頻度、直前の変更など',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEnglish ? 'Data sent to AI' : 'AIへ送信する情報',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEnglish
                      ? '${contextData?.settings.length ?? 0} entered settings, car, track and weather context'
                      : '入力済み設定 ${contextData?.settings.length ?? 0}件、車種、コース・天候情報',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _includeHistory,
                  onChanged: (value) => setState(() => _includeHistory = value),
                  title: Text(
                    _isEnglish
                        ? 'Include related run history (${contextData?.relatedRuns.length ?? 0})'
                        : '関連する走行履歴を含める（${contextData?.relatedRuns.length ?? 0}件）',
                  ),
                  subtitle: Text(
                    _isEnglish
                        ? 'Only this car and the linked/current track are selected.'
                        : '同じ車種の、現在セットまたは現在コースに関連する履歴だけを選びます。',
                  ),
                ),
                GeminiUsageIndicator(isEnglish: _isEnglish),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isLoading ? null : _startConversation,
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(_isEnglish ? 'Start consultation' : '相談を開始'),
        ),
      ],
    );
  }

  Widget _chipSection({
    required String title,
    required Map<String, List<String>> labels,
    required Set<String> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: labels.keys.map((key) {
            return FilterChip(
              label: Text(_label(labels, key)),
              selected: selected.contains(key),
              onSelected: (enabled) {
                setState(() {
                  enabled ? selected.add(key) : selected.remove(key);
                });
              },
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String title,
    required Map<String, List<String>> labels,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
      ),
      items: labels.keys
          .map(
            (key) => DropdownMenuItem(
              value: key,
              child: Text(_label(labels, key)),
            ),
          )
          .toList(growable: false),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }

  Widget _buildConversation() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _readyForAdvice
                    ? (_isEnglish
                        ? 'Enough information collected'
                        : '提案に必要な情報が集まりました')
                    : (_isEnglish
                        ? 'AI may ask up to two questions'
                        : 'AIからの追加質問は最大2問です'),
              ),
              const SizedBox(height: 8),
              GeminiUsageIndicator(isEnglish: _isEnglish),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isUser = message.role == AdvisorMessageRole.user;
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 640),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(message.text),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isLoading && _userFollowups < 2,
                      maxLength: 1000,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _isEnglish ? 'Your answer' : '質問への回答',
                        border: const OutlineInputBorder(),
                        counterText: '',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed:
                        !_isLoading && _userFollowups < 2 ? _sendMessage : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _generateAdvice,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    _isEnglish ? 'Generate setup advice' : 'セッティング提案を生成',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final advice = _advice;
    if (advice == null) return const SizedBox.shrink();
    final confidenceLabel = switch (advice.confidence) {
      'high' => _isEnglish ? 'High' : '高',
      'medium' => _isEnglish ? 'Medium' : '中',
      _ => _isEnglish ? 'Low' : '低',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isEnglish ? 'Diagnosis' : '診断',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Chip(
              label: Text(
                _isEnglish
                    ? 'Confidence: $confidenceLabel'
                    : '確信度: $confidenceLabel',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(advice.summary),
        if (advice.evidence.isNotEmpty) ...[
          const SizedBox(height: 16),
          _textList(_isEnglish ? 'Evidence' : '根拠', advice.evidence),
        ],
        if (advice.missingInformation.isNotEmpty) ...[
          const SizedBox(height: 16),
          _textList(
            _isEnglish ? 'Missing information' : '不足している情報',
            advice.missingInformation,
          ),
        ],
        const SizedBox(height: 20),
        Text(
          _isEnglish ? 'Proposed changes' : '変更提案',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          _isEnglish
              ? 'The highest-priority change is selected first. Test one change at a time when possible.'
              : '最優先の変更だけを初期選択しています。可能な限り1項目ずつ試してください。',
        ),
        const SizedBox(height: 8),
        if (advice.changes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _isEnglish
                    ? 'No safely applicable numeric change was generated.'
                    : '安全に自動反映できる数値変更は生成されませんでした。',
              ),
            ),
          ),
        for (var index = 0; index < advice.changes.length; index += 1)
          _changeCard(index, advice.changes[index]),
        if (advice.manualTips.isNotEmpty) ...[
          const SizedBox(height: 16),
          _textList(
              _isEnglish ? 'Manual checks' : '手動で確認する項目', advice.manualTips),
        ],
        const SizedBox(height: 16),
        _textBlock(_isEnglish ? 'Test plan' : '走行テスト方法', advice.testPlan),
        if (advice.drivingTips.isNotEmpty) ...[
          const SizedBox(height: 12),
          _textBlock(
            _isEnglish ? 'Driving tips' : '走行アドバイス',
            advice.drivingTips,
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _derivedNameController,
          decoration: InputDecoration(
            labelText: _isEnglish ? 'Derived setting name' : '派生セット名',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isLoading || _selectedChangeIndexes.isEmpty
              ? null
              : _createDerivedSetting,
          icon: const Icon(Icons.fork_right),
          label: Text(
            _isEnglish ? 'Create derived setting' : '派生セットを作成',
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : () => setState(() => _step = 1),
          child: Text(_isEnglish ? 'Back to conversation' : '会話に戻る'),
        ),
      ],
    );
  }

  Widget _changeCard(int index, AdvisorSettingChange change) {
    final applicable = _validatedChanges.containsKey(index);
    final selected = _selectedChangeIndexes.contains(index);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: CheckboxListTile(
        value: selected,
        onChanged: applicable
            ? (enabled) {
                setState(() {
                  enabled == true
                      ? _selectedChangeIndexes.add(index)
                      : _selectedChangeIndexes.remove(index);
                });
              }
            : null,
        title: Text(
          '${change.settingLabel}: ${change.currentValue} → ${change.proposedValue}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(change.reason),
              const SizedBox(height: 4),
              Text(
                '${_isEnglish ? "Expected" : "期待効果"}: ${change.expectedEffect}',
              ),
              if (change.tradeoff.isNotEmpty)
                Text(
                  '${_isEnglish ? "Trade-off" : "注意点"}: ${change.tradeoff}',
                ),
              if (!applicable)
                Text(
                  _isEnglish
                      ? 'This value failed local validation and cannot be applied.'
                      : 'ローカル検証を通らなかったため自動反映できません。',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _textList(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $item'),
          ),
      ],
    );
  }

  Widget _textBlock(String title, String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(text),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _messageController.dispose();
    _derivedNameController.dispose();
    super.dispose();
  }
}
