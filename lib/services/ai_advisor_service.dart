import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/car.dart';
import '../models/car_setting_definition.dart';
import '../models/track_location.dart';
import '../services/weather_service.dart';

class AIAdvisorService {
  late final GenerativeModel _model;

  AIAdvisorService() {
    // 環境変数からGemini APIキーを取得
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY が環境変数に設定されていません');
    }

    // Gemini Pro モデルを初期化
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
  }

  /// セッティングを分析してアドバイスを生成
  Future<SettingAdvice> analyzeSettings({
    required Car car,
    required Map<String, dynamic> settings,
    required CarSettingDefinition settingDefinition,
    TrackLocation? trackInfo,
    WeatherData? weatherInfo,
  }) async {
    try {
      final prompt = _buildAnalysisPrompt(
        car: car,
        settings: settings,
        settingDefinition: settingDefinition,
        trackInfo: trackInfo,
        weatherInfo: weatherInfo,
      );

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final result = response.text;

      if (result == null || result.isEmpty) {
        throw Exception('AIからの応答が空です');
      }

      return _parseAdviceResponse(result);
    } catch (e) {
      print('AI アドバイス生成エラー: $e');
      rethrow;
    }
  }

  /// 分析用プロンプトを構築
  String _buildAnalysisPrompt({
    required Car car,
    required Map<String, dynamic> settings,
    required CarSettingDefinition settingDefinition,
    TrackLocation? trackInfo,
    WeatherData? weatherInfo,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('あなたはRCカーのセッティングアドバイザーです。');
    buffer.writeln('以下のセッティングを分析し、詳細なアドバイスを提供してください。');
    buffer.writeln('');

    // 車種情報
    buffer.writeln('【車種情報】');
    buffer.writeln('車種: ${car.name}');
    buffer.writeln('メーカー: ${car.manufacturer.name}');
    buffer.writeln('カテゴリー: ${car.category}');
    buffer.writeln('');

    // セッティング情報
    buffer.writeln('【現在のセッティング】');
    for (final settingItem in settingDefinition.availableSettings) {
      final value = settings[settingItem.key];
      if (value != null && value.toString().isNotEmpty) {
        final unit = settingItem.unit ?? '';
        buffer.writeln('- ${settingItem.label}: $value$unit');
      }
    }
    buffer.writeln('');

    // トラック情報
    if (trackInfo != null) {
      buffer.writeln('【サーキット情報】');
      buffer.writeln('サーキット: ${trackInfo.name}');
      buffer.writeln('路面タイプ: ${trackInfo.surfaceType}');
      buffer.writeln('タイプ: ${trackInfo.type}');
      if (trackInfo.description != null && trackInfo.description!.isNotEmpty) {
        buffer.writeln('詳細: ${trackInfo.description}');
      }
      buffer.writeln('');
    }

    // 天気情報
    if (weatherInfo != null) {
      buffer.writeln('【天候情報】');
      buffer.writeln('天気: ${weatherInfo.description}');
      buffer.writeln('気温: ${weatherInfo.temperature}°C');
      buffer.writeln('湿度: ${weatherInfo.humidity}%');
      buffer.writeln('風速: ${weatherInfo.windSpeed}m/s');
      buffer.writeln('');
    }

    // アドバイス要求
    buffer.writeln('【アドバイス要求】');
    buffer.writeln('以下の形式で分析結果とアドバイスを提供してください：');
    buffer.writeln('');
    buffer.writeln('## 総合評価');
    buffer.writeln('[セッティング全体の評価を5段階で示し、簡潔なコメントを記載]');
    buffer.writeln('');
    buffer.writeln('## セッティング分析');
    buffer.writeln('[各セッティング項目について、以下の観点で分析]');
    buffer.writeln('- 妥当性（適切か、極端すぎないか）');
    buffer.writeln('- バランス（前後のバランスなど）');
    buffer.writeln('- トラックとの相性（トラック情報がある場合）');
    buffer.writeln('');
    buffer.writeln('## 改善提案');
    buffer.writeln('[具体的な改善提案を優先度順に3-5個程度]');
    buffer.writeln('各提案について：');
    buffer.writeln('- どの項目をどう変更するか');
    buffer.writeln('- その理由と期待される効果');
    buffer.writeln('');
    buffer.writeln('## 走行アドバイス');
    buffer.writeln('[このセッティングでの走行時の注意点やドライビングのコツ]');
    buffer.writeln('');
    buffer.writeln('注意：RCカーのセッティングに関する専門知識を活用し、実践的で具体的なアドバイスを提供してください。');

    return buffer.toString();
  }

  /// AIの応答を解析してSettingAdviceオブジェクトに変換
  SettingAdvice _parseAdviceResponse(String response) {
    final sections = <String, String>{};
    String currentSection = '';
    final sectionBuffer = StringBuffer();

    final lines = response.split('\n');

    for (final line in lines) {
      // セクションヘッダーを検出（## で始まる行）
      if (line.trim().startsWith('##')) {
        // 前のセクションを保存
        if (currentSection.isNotEmpty) {
          sections[currentSection] = sectionBuffer.toString().trim();
          sectionBuffer.clear();
        }
        // 新しいセクションを開始
        currentSection = line.trim().replaceAll('#', '').trim();
      } else {
        // セクションの内容を追加
        if (currentSection.isNotEmpty) {
          sectionBuffer.writeln(line);
        }
      }
    }

    // 最後のセクションを保存
    if (currentSection.isNotEmpty) {
      sections[currentSection] = sectionBuffer.toString().trim();
    }

    // 評価スコアを抽出（5段階評価）
    int overallScore = 3; // デフォルト値
    final overallText = sections['総合評価'] ?? '';
    final scoreMatch = RegExp(r'([1-5])/5|([1-5])点').firstMatch(overallText);
    if (scoreMatch != null) {
      final scoreStr = scoreMatch.group(1) ?? scoreMatch.group(2);
      if (scoreStr != null) {
        overallScore = int.tryParse(scoreStr) ?? 3;
      }
    }

    return SettingAdvice(
      overallScore: overallScore,
      overallComment: sections['総合評価'] ?? 'セッティングの評価を取得できませんでした',
      detailedAnalysis: sections['セッティング分析'] ?? '分析結果を取得できませんでした',
      recommendations: sections['改善提案'] ?? '改善提案を取得できませんでした',
      drivingTips: sections['走行アドバイス'] ?? '走行アドバイスを取得できませんでした',
      fullResponse: response,
    );
  }

  /// 特定のセッティング項目についてのアドバイスを取得
  Future<String> getSpecificAdvice({
    required String settingKey,
    required String settingLabel,
    required dynamic currentValue,
    required Car car,
    TrackLocation? trackInfo,
  }) async {
    try {
      final prompt = '''
あなたはRCカーのセッティングアドバイザーです。

【車種】
${car.name} (${car.manufacturer.name})

【対象セッティング】
${settingLabel}: $currentValue

${trackInfo != null ? '''
【サーキット情報】
サーキット: ${trackInfo.name}
路面: ${trackInfo.surfaceType}
''' : ''}

この${settingLabel}の現在値 ($currentValue) について：
1. この値は適切か、極端すぎないか
2. この車種に対して一般的な値の範囲はどれくらいか
3. どのような効果があるか
4. おすすめの調整方法

上記について、簡潔かつ実践的なアドバイスを提供してください。
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? 'アドバイスを取得できませんでした';
    } catch (e) {
      print('個別アドバイス取得エラー: $e');
      return 'アドバイスの取得中にエラーが発生しました: $e';
    }
  }
}

/// セッティングアドバイスの結果を格納するクラス
class SettingAdvice {
  final int overallScore; // 1-5の評価スコア
  final String overallComment; // 総合評価のコメント
  final String detailedAnalysis; // 詳細な分析結果
  final String recommendations; // 改善提案
  final String drivingTips; // 走行アドバイス
  final String fullResponse; // AI の完全な応答

  SettingAdvice({
    required this.overallScore,
    required this.overallComment,
    required this.detailedAnalysis,
    required this.recommendations,
    required this.drivingTips,
    required this.fullResponse,
  });

  /// スコアに応じた評価テキストを取得
  String get scoreText {
    switch (overallScore) {
      case 5:
        return '優秀';
      case 4:
        return '良好';
      case 3:
        return '標準';
      case 2:
        return '要改善';
      case 1:
        return '要見直し';
      default:
        return '不明';
    }
  }

  /// スコアに応じた色を取得（Flutter の Color は使用せず文字列で返す）
  String get scoreColorName {
    switch (overallScore) {
      case 5:
        return 'green';
      case 4:
        return 'lightGreen';
      case 3:
        return 'orange';
      case 2:
        return 'deepOrange';
      case 1:
        return 'red';
      default:
        return 'grey';
    }
  }
}
