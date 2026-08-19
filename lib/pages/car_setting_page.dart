import 'package:rc_setting_manager/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/car.dart';

import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../models/saved_setting.dart';
import '../models/settings_operation_result.dart';

import '../data/car_settings_definitions.dart';
import '../models/car_setting_definition.dart';
import '../widgets/grid_selector.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../models/track_location.dart';
import '../services/track_location_service.dart';
import './ocr_import_page.dart';
import './ai_setting_advisor_page.dart';
import './ai_provider_settings_page.dart';
import '../services/ai_advisor_service.dart';
import '../services/ai_configuration_service.dart';
import '../services/api_consent_service.dart';
import '../widgets/ai_provider_indicator.dart';
import '../utils/settings_operation_feedback.dart';

part 'car_setting_page_ui_helpers.dart';
part 'car_setting_page_track_search_dialog.dart';
part 'car_setting_page_conversation_dialog.dart';
part 'car_setting_page_trf420x_editor.dart';
part 'car_setting_page_edit_controller.dart';
part 'car_setting_page_environment.dart';
part 'car_setting_page_paper_editor.dart';
part 'car_setting_page_save_flow.dart';
part 'car_setting_page_normal_editor.dart';

enum _GaragePromptAction {
  add,
  notNow,
  suppress,
}

class CarSettingPage extends StatefulWidget {
  final Car originalCar;
  final Map<String, dynamic>? savedSettings;
  final String? savedSettingId;
  final String? settingName;

  const CarSettingPage({
    super.key,
    required this.originalCar,
    this.savedSettings,
    this.savedSettingId,
    this.settingName,
  });

  @override
  State<CarSettingPage> createState() => _CarSettingPageState();
}

class _CarSettingPageState extends State<CarSettingPage>
    with
        _CarSettingEnvironment,
        _CarSettingPaperEditor,
        _CarSettingSaveFlow,
        _CarSettingNormalEditor,
        _CarSettingTrf420xEditor {
  late final _CarSettingEditController _editController;

  @override
  String get carName => _editController.carName;

  @override
  Map<String, dynamic> get settings => _editController.settings;
  set settings(Map<String, dynamic> value) => _editController.settings = value;

  Map<String, dynamic> get _initialSettingsSnapshot =>
      _editController.initialSettingsSnapshot;
  set _initialSettingsSnapshot(Map<String, dynamic> value) =>
      _editController.initialSettingsSnapshot = value;

  @override
  String? get _activeSavedSettingId => _editController.activeSavedSettingId;
  set _activeSavedSettingId(String? value) =>
      _editController.activeSavedSettingId = value;

  @override
  TextEditingController get _settingNameController =>
      _editController.settingNameController;
  @override
  TextEditingController get _trackNameController =>
      _editController.trackNameController;

  @override
  bool get _isEditing => _editController.isEditing;
  set _isEditing(bool value) => _editController.isEditing = value;

  @override
  CarSettingDefinition? get _carSettingDefinition =>
      _editController.settingDefinition;

  bool _isLoading = true;
  @override
  TrackLocation? _currentTrack;
  @override
  Position? _currentPosition;
  @override
  LocationStatus? _locationFailureStatus;
  @override
  bool _isLocationLoading = false;
  @override
  WeatherData? _currentWeather;
  @override
  WeatherStatus? _weatherErrorStatus;
  @override
  bool _isWeatherLoading = false;
  bool _isAIAnalyzing = false;
  @override
  bool _isSavingSetting = false;
  final Set<String> _settingsMutationsInFlight = <String>{};

  @override
  void initState() {
    super.initState();
    _editController = _CarSettingEditController(
      page: widget,
      settingDefinition: getCarSettingDefinition(widget.originalCar.id),
    );
    debugLog('Car ID: ${widget.originalCar.id}'); // デバッグ用ログ
    debugLog('Car Setting Definition: $_carSettingDefinition'); // デバッグ用ログ

    _initializeSettings();
    // 位置情報と天気情報の初期化を少し遅延させる
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (mounted) {
        // Safariで位置情報要求が競合しないよう、順番に実行する。
        await _initializeLocationAndTrack();
        if (mounted) {
          await _initializeWeather();
        }
      }
    });
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Future<bool> _handleSettingsMutation<T>(
    String operationKey,
    Future<SettingsOperationResult<T>> Function() operation,
  ) async {
    if (!_settingsMutationsInFlight.add(operationKey)) return false;
    try {
      final result = await operation();
      if (!mounted) {
        return result.isSuccess;
      }
      return handleSettingsOperationResult(
        context,
        result,
        isEnglish:
            Provider.of<SettingsProvider>(context, listen: false).isEnglish,
      );
    } finally {
      _settingsMutationsInFlight.remove(operationKey);
    }
  }

  Future<void> _initializeSettings() async {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  // OCRから設定をインポート
  Future<void> _importFromOCR() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => OCRImportPage(
          car: widget.originalCar,
          currentSettings: settings,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null && result.isNotEmpty) {
      setState(() {
        settings = result;
      });

      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final isEnglish = settingsProvider.isEnglish;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'Settings imported successfully'
              : 'セッティングをインポートしました'),
        ),
      );
    }
  }

  // AIセッティング相談
  Future<void> _getAIAdvice() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    if (_carSettingDefinition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEnglish
              ? 'Car settings definition not found'
              : 'セッティング定義が見つかりません'),
        ),
      );
      return;
    }

    if (!await _ensureAiConfigured(isEnglish) || !mounted) {
      return;
    }

    final consentGranted = await ApiConsentService.requestConsent(
      context,
      type: ApiConsentType.aiAndOcr,
      isEnglish: isEnglish,
    );
    if (!consentGranted || !mounted) {
      return;
    }

    final derivedSetting = await Navigator.of(context).push<SavedSetting>(
      MaterialPageRoute(
        builder: (context) => AISettingAdvisorPage(
          car: widget.originalCar,
          currentSettings: Map<String, dynamic>.from(settings),
          initialSettings: Map<String, dynamic>.from(_initialSettingsSnapshot),
          settingDefinition: _carSettingDefinition!,
          settingName: _settingNameController.text,
          savedSettingId: _activeSavedSettingId,
          trackInfo: _currentTrack,
          weatherInfo: _currentWeather,
          isEnglish: isEnglish,
        ),
      ),
    );

    if (derivedSetting != null && mounted) {
      setState(() {
        settings = Map<String, dynamic>.from(derivedSetting.settings);
        _initialSettingsSnapshot =
            Map<String, dynamic>.from(derivedSetting.settings);
        _settingNameController.text = derivedSetting.name;
        _activeSavedSettingId = derivedSetting.id;
        _isEditing = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEnglish
                ? 'Created and opened the AI-derived setting'
                : 'AI提案の派生セットを作成して開きました',
          ),
        ),
      );
    }
  }

  Future<bool> _ensureAiConfigured(bool isEnglish) async {
    try {
      if (await AiConfigurationService().activeConfiguration != null) {
        return true;
      }
    } catch (_) {
      // Secure-storage failures use the same actionable setup dialog.
    }
    if (!mounted) return false;
    final openSettings = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(isEnglish ? 'AI setup required' : 'AI設定が必要です'),
            content: Text(
              isEnglish
                  ? 'Set an OpenAI, Anthropic, or Gemini API key before '
                      'starting AI setup advice.'
                  : 'AIセッティング相談を始める前に、OpenAI・Anthropic・Geminiの'
                      'いずれかのAPIキーを設定してください。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(isEnglish ? 'Open settings' : '設定を開く'),
              ),
            ],
          ),
        ) ??
        false;
    if (openSettings && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AiProviderSettingsPage(
            isEnglish: isEnglish,
          ),
        ),
      );
      if (!mounted) return false;
      setState(() {});
      try {
        return await AiConfigurationService().activeConfiguration != null;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  // 会話モードを開始
  // ignore: unused_element
  Future<void> _startConversationMode() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    if (!mounted) return;

    // 会話画面を表示
    await showDialog(
      context: context,
      builder: (context) => _ConversationDialog(
        car: widget.originalCar,
        settings: settings,
        settingDefinition: _carSettingDefinition!,
        trackInfo: _currentTrack,
        weatherInfo: _currentWeather,
        isEnglish: isEnglish,
      ),
    );
  }

  // 評価モードを実行（従来の一括分析）
  // ignore: unused_element
  Future<void> _startAnalysisMode() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    // 分析中の状態を表示
    setState(() {
      _isAIAnalyzing = true;
    });

    // プログレスダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(isEnglish ? 'Analyzing settings...' : 'セッティングを分析中...'),
          ],
        ),
      ),
    );

    try {
      final aiService = AIAdvisorService();
      final advice = await aiService.analyzeSettings(
        car: widget.originalCar,
        settings: settings,
        settingDefinition: _carSettingDefinition!,
        trackInfo: _currentTrack,
        weatherInfo: _currentWeather,
      );

      // プログレスダイアログを閉じる
      if (mounted) {
        Navigator.of(context).pop();

        // アドバイス結果を表示
        _showAdviceDialog(advice);
      }
    } catch (e) {
      debugLog('Failed to get AI advice: $e');
      // プログレスダイアログを閉じる
      if (mounted) {
        Navigator.of(context).pop();

        // エラーメッセージを表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isEnglish ? 'Failed to get AI advice.' : 'AIアドバイスの取得に失敗しました。'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAIAnalyzing = false;
        });
      }
    }
  }

  // AIアドバイス結果を表示するダイアログ
  void _showAdviceDialog(SettingAdvice advice) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (dialogContext) => _buildResponsiveDialog(
        context: dialogContext,
        child: Column(
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEnglish ? 'AI Setting Advice' : 'AIセッティングアドバイス',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AiProviderIndicator(),
            ),

            // コンテンツ
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 総合評価カード
                    _buildScoreCard(advice, isEnglish),
                    const SizedBox(height: 16),

                    // タブビュー
                    DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          TabBar(
                            isScrollable: true,
                            labelColor: Theme.of(context).colorScheme.primary,
                            tabs: [
                              Tab(text: isEnglish ? 'Analysis' : '分析結果'),
                              Tab(text: isEnglish ? 'Recommendations' : '改善提案'),
                              Tab(text: isEnglish ? 'Driving Tips' : '走行アドバイス'),
                            ],
                          ),
                          SizedBox(
                            height:
                                MediaQuery.sizeOf(dialogContext).height * 0.35,
                            child: TabBarView(
                              children: [
                                // 分析結果タブ
                                _buildAnalysisTab(advice),
                                // 改善提案タブ
                                _buildRecommendationsTab(advice),
                                // 走行アドバイスタブ
                                _buildDrivingTipsTab(advice),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // スコアカードウィジェット
  Widget _buildScoreCard(SettingAdvice advice, bool isEnglish) {
    Color scoreColor;
    switch (advice.scoreColorName) {
      case 'green':
        scoreColor = Colors.green;
        break;
      case 'lightGreen':
        scoreColor = Colors.lightGreen;
        break;
      case 'orange':
        scoreColor = Colors.orange;
        break;
      case 'deepOrange':
        scoreColor = Colors.deepOrange;
        break;
      case 'red':
        scoreColor = Colors.red;
        break;
      default:
        scoreColor = Colors.grey;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: scoreColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${advice.overallScore}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnglish ? 'Overall Rating' : '総合評価',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        advice.scoreText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              advice.overallComment,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // 分析結果タブ
  Widget _buildAnalysisTab(SettingAdvice advice) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        advice.detailedAnalysis,
        style: const TextStyle(fontSize: 14, height: 1.6),
      ),
    );
  }

  // 改善提案タブ
  Widget _buildRecommendationsTab(SettingAdvice advice) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        advice.recommendations,
        style: const TextStyle(fontSize: 14, height: 1.6),
      ),
    );
  }

  // 走行アドバイスタブ
  Widget _buildDrivingTipsTab(SettingAdvice advice) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        advice.drivingTips,
        style: const TextStyle(fontSize: 14, height: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final usePaperStyleEditor = settingsProvider.usePaperStyleEditor;

    return PopScope(
      canPop: !_isSavingSetting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing
              ? (isEnglish ? 'Edit Setting' : 'セッティング編集')
              : (isEnglish ? 'New Setting' : '新規セッティング')),
          actions: [
            IconButton(
              icon: const Icon(Icons.psychology),
              onPressed: _isAIAnalyzing ? null : _getAIAdvice,
              tooltip: isEnglish ? 'AI Advice' : 'AIアドバイス',
            ),
            IconButton(
              icon: const Icon(Icons.document_scanner),
              onPressed: _importFromOCR,
              tooltip: isEnglish ? 'Import from Image' : '画像から読み込み',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: usePaperStyleEditor
              ? _buildPaperEditorBody(context, isEnglish)
              : _buildSettingTabs(context),
        ),
        bottomNavigationBar: _buildSaveActionBar(isEnglish),
      ),
    );
  }

  @override
  Widget _buildAppEditorHeader(bool isEnglish) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEditorLayoutSelector(isEnglish, false),
        const SizedBox(height: 16),
        TextField(
          controller: _settingNameController,
          decoration: InputDecoration(
            labelText: isEnglish ? 'Setting Name' : 'セッティング名',
            hintText: isEnglish ? 'e.g. Race Setup 1' : '例：レースセットアップ1',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _trackNameController,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Track Name' : 'トラック名',
                  hintText: isEnglish ? 'e.g. Tamiya Circuit' : '例：タミヤサーキット',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  prefixIcon: _currentTrack != null
                      ? Icon(
                          _currentTrack!.type == 'indoor'
                              ? Icons.home_work
                              : Icons.landscape,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : const Icon(Icons.place),
                  suffixIcon: _isLocationLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  helperText: _currentTrack != null
                      ? '${_currentTrack!.prefecture} • ${isEnglish ? (_currentTrack!.type == 'indoor' ? 'Indoor' : 'Outdoor') : (_currentTrack!.type == 'indoor' ? '屋内' : '屋外')} • ${_currentTrack!.surfaceType == 'carpet' ? (isEnglish ? 'Carpet' : 'カーペット') : (isEnglish ? 'Asphalt' : 'アスファルト')}'
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _refreshLocation,
              icon: const Icon(Icons.my_location),
              tooltip: isEnglish ? 'Get current location' : '現在位置を取得',
            ),
            IconButton(
              onPressed: _searchTrackManually,
              icon: const Icon(Icons.search),
              tooltip: isEnglish ? 'Search track' : 'トラック検索',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${isEnglish ? 'Car' : '車両'}: $carName',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget _buildEditorLayoutSelector(bool isEnglish, bool usePaperStyleEditor) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            isEnglish ? 'Layout' : '表示モード',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          ChoiceChip(
            label: Text(isEnglish ? 'App UI' : 'アプリUI'),
            selected: !usePaperStyleEditor,
            onSelected: (selected) async {
              if (selected) {
                await _handleSettingsMutation(
                  'editor-layout',
                  () => settingsProvider.setPaperStyleEditor(false),
                );
              }
            },
          ),
          ChoiceChip(
            label: Text(isEnglish ? 'Paper UI' : '紙UI'),
            selected: usePaperStyleEditor,
            onSelected: (selected) async {
              if (selected) {
                await _handleSettingsMutation(
                  'editor-layout',
                  () => settingsProvider.setPaperStyleEditor(true),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
