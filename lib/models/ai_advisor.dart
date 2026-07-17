enum AdvisorMessageRole {
  user,
  model,
}

class AdvisorMessage {
  final AdvisorMessageRole role;
  final String text;

  const AdvisorMessage({
    required this.role,
    required this.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'text': text,
    };
  }
}

class AIAdvisorContext {
  final Map<String, dynamic> vehicle;
  final String settingName;
  final bool definitionVerified;
  final List<Map<String, dynamic>> settings;
  final List<Map<String, dynamic>> settingCatalog;
  final Map<String, dynamic>? track;
  final Map<String, dynamic>? weather;
  final String settingMemo;
  final List<Map<String, dynamic>> relatedRuns;

  const AIAdvisorContext({
    required this.vehicle,
    required this.settingName,
    required this.definitionVerified,
    required this.settings,
    required this.settingCatalog,
    this.track,
    this.weather,
    this.settingMemo = '',
    this.relatedRuns = const [],
  });

  Map<String, dynamic> toJson({bool includeHistory = true}) {
    return {
      'vehicle': vehicle,
      'settingName': settingName,
      'definitionVerified': definitionVerified,
      'settings': settings,
      'settingCatalog': settingCatalog,
      if (track != null) 'track': track,
      if (weather != null) 'weather': weather,
      if (settingMemo.isNotEmpty) 'settingMemo': settingMemo,
      'relatedRuns': includeHistory ? relatedRuns : const [],
    };
  }
}

class AIAdvisorIntake {
  final List<String> symptoms;
  final List<String> phases;
  final String severity;
  final String trackGrip;
  final String goal;
  final String notes;

  const AIAdvisorIntake({
    required this.symptoms,
    required this.phases,
    required this.severity,
    required this.trackGrip,
    required this.goal,
    this.notes = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'symptoms': symptoms,
      'phases': phases,
      'severity': severity,
      'trackGrip': trackGrip,
      'goal': goal,
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
  }
}

class AdvisorChatTurn {
  final String message;
  final bool readyForAdvice;
  final List<String> missingTopics;

  const AdvisorChatTurn({
    required this.message,
    required this.readyForAdvice,
    this.missingTopics = const [],
  });

  factory AdvisorChatTurn.fromJson(Map<String, dynamic> json) {
    return AdvisorChatTurn(
      message: json['message'] as String? ?? '',
      readyForAdvice: json['readyForAdvice'] as bool? ?? false,
      missingTopics: (json['missingTopics'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
    );
  }
}

class AdvisorSettingChange {
  final String settingKey;
  final String settingLabel;
  final String currentValue;
  final String proposedValue;
  final String reason;
  final String expectedEffect;
  final String tradeoff;
  final int priority;

  const AdvisorSettingChange({
    required this.settingKey,
    required this.settingLabel,
    required this.currentValue,
    required this.proposedValue,
    required this.reason,
    required this.expectedEffect,
    required this.tradeoff,
    required this.priority,
  });

  factory AdvisorSettingChange.fromJson(Map<String, dynamic> json) {
    final rawPriority = json['priority'];
    return AdvisorSettingChange(
      settingKey: json['settingKey'] as String? ?? '',
      settingLabel: json['settingLabel'] as String? ?? '',
      currentValue: json['currentValue']?.toString() ?? '',
      proposedValue: json['proposedValue']?.toString() ?? '',
      reason: json['reason'] as String? ?? '',
      expectedEffect: json['expectedEffect'] as String? ?? '',
      tradeoff: json['tradeoff'] as String? ?? '',
      priority: rawPriority is num ? rawPriority.toInt() : 3,
    );
  }
}

class AISettingAdvice {
  final String summary;
  final String confidence;
  final List<String> evidence;
  final List<String> missingInformation;
  final List<AdvisorSettingChange> changes;
  final List<String> manualTips;
  final String testPlan;
  final String drivingTips;

  const AISettingAdvice({
    required this.summary,
    required this.confidence,
    this.evidence = const [],
    this.missingInformation = const [],
    this.changes = const [],
    this.manualTips = const [],
    required this.testPlan,
    required this.drivingTips,
  });

  factory AISettingAdvice.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'] as List? ?? const [];
    return AISettingAdvice(
      summary: json['summary'] as String? ?? '',
      confidence: json['confidence'] as String? ?? 'low',
      evidence: (json['evidence'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
      missingInformation: (json['missingInformation'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
      changes: rawChanges
          .whereType<Map>()
          .map(
            (item) => AdvisorSettingChange.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .take(3)
          .toList(growable: false),
      manualTips: (json['manualTips'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
      testPlan: json['testPlan'] as String? ?? '',
      drivingTips: json['drivingTips'] as String? ?? '',
    );
  }
}
