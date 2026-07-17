import 'dart:convert';

import '../data/run_feel_tags.dart';
import '../models/ai_advisor.dart';
import '../models/car.dart';
import '../models/car_setting_definition.dart';
import '../models/run_log.dart';
import '../models/track_location.dart';
import 'weather_service.dart';

class AIAdvisorContextBuilder {
  const AIAdvisorContextBuilder._();

  static AIAdvisorContext build({
    required Car car,
    required String settingName,
    required Map<String, dynamic> currentSettings,
    required CarSettingDefinition settingDefinition,
    required List<RunLog> runLogs,
    required bool isSavedSetting,
    required bool isEnglish,
    String? activeSettingId,
    Map<String, dynamic> initialSettings = const {},
    Set<String> autoFilledKeys = const {},
    TrackLocation? track,
    WeatherData? weather,
  }) {
    final catalog = settingDefinition.availableSettings.map((item) {
      return <String, dynamic>{
        'key': item.key,
        'label': item.label,
        'category': item.category,
        'type': item.type,
        if (item.unit != null && item.unit!.isNotEmpty) 'unit': item.unit,
        if (item.options != null && item.options!.isNotEmpty)
          'options': item.options!.take(50).toList(growable: false),
        if (item.constraints['min'] is num) 'min': item.constraints['min'],
        if (item.constraints['max'] is num) 'max': item.constraints['max'],
        if (item.constraints['step'] is num) 'step': item.constraints['step'],
        'autoApplicable': isAutoApplicableSetting(item),
        if (isAutoApplicableSetting(item)) 'maxDeltaSteps': 1,
      };
    }).toList(growable: false);

    final values = <Map<String, dynamic>>[];
    for (final item in settingDefinition.availableSettings) {
      if (item.key == 'date' || item.key == 'memo') {
        continue;
      }

      final value = currentSettings[item.key];
      if (_isEmpty(value)) {
        continue;
      }

      values.add({
        'key': item.key,
        'label': item.label,
        'value': _normalizeValue(value),
        'source': isSavedSetting
            ? 'confirmed'
            : autoFilledKeys.contains(item.key)
                ? 'auto'
                : _sameValue(value, initialSettings[item.key])
                    ? 'default'
                    : 'entered',
      });
    }

    return AIAdvisorContext(
      vehicle: {
        'id': car.id,
        'name': car.name,
        'manufacturer': car.manufacturer.name,
        'category': car.category,
      },
      settingName: settingName.trim(),
      definitionVerified: settingDefinition.isHumanVerified,
      settings: values,
      settingCatalog: catalog,
      track: track == null
          ? null
          : {
              'name': track.name,
              'type': track.type,
              'surfaceType': track.surfaceType,
              if (track.description != null &&
                  track.description!.trim().isNotEmpty)
                'description': _truncate(track.description!, 300),
            },
      weather: weather == null
          ? null
          : {
              'temperatureC': weather.temperature,
              'humidityPercent': weather.humidity,
              'description': weather.description,
              'windSpeedMps': weather.windSpeed,
            },
      settingMemo: _truncate(
        currentSettings['memo']?.toString().trim() ?? '',
        500,
      ),
      relatedRuns: _selectRelatedRuns(
        runLogs: runLogs,
        carId: car.id,
        activeSettingId: activeSettingId,
        trackName: track?.name,
        isEnglish: isEnglish,
      ),
    );
  }

  static bool isAutoApplicableSetting(SettingItem item) {
    if (item.type != 'number') {
      return false;
    }
    if (item.constraints['min'] is! num ||
        item.constraints['max'] is! num ||
        item.constraints['step'] is! num) {
      return false;
    }

    final key = item.key.toLowerCase();
    final isCamber = key.endsWith('camber') || key.endsWith('camberangle');
    final isToe = key.endsWith('toeangle');
    final isRideHeight =
        key.endsWith('rideheight') || key.endsWith('groundclearance');
    final isDroop = key.endsWith('droop');
    final isStabilizer = key.endsWith('stabilizer') || key.endsWith('swaybar');
    return isCamber || isToe || isRideHeight || isDroop || isStabilizer;
  }

  static dynamic validatedProposedValue({
    required AdvisorSettingChange change,
    required CarSettingDefinition settingDefinition,
    required Map<String, dynamic> currentSettings,
  }) {
    SettingItem? item;
    for (final candidate in settingDefinition.availableSettings) {
      if (candidate.key == change.settingKey) {
        item = candidate;
        break;
      }
    }
    if (item == null || !isAutoApplicableSetting(item)) {
      return null;
    }

    final current = _asDouble(currentSettings[item.key]);
    final proposed = _asDouble(
      change.proposedValue,
      unit: item.unit,
    );
    final min = (item.constraints['min'] as num).toDouble();
    final max = (item.constraints['max'] as num).toDouble();
    final step = (item.constraints['step'] as num).toDouble().abs();
    if (current == null ||
        proposed == null ||
        step <= 0 ||
        proposed < min ||
        proposed > max) {
      return null;
    }

    final delta = (proposed - current).abs();
    const epsilon = 0.000001;
    if (delta <= epsilon || delta > step + epsilon) {
      return null;
    }

    final fromMin = (proposed - min) / step;
    if ((fromMin - fromMin.round()).abs() > epsilon) {
      return null;
    }

    return proposed;
  }

  static List<Map<String, dynamic>> _selectRelatedRuns({
    required List<RunLog> runLogs,
    required String carId,
    required String? activeSettingId,
    required String? trackName,
    required bool isEnglish,
  }) {
    final normalizedTrack = trackName?.trim().toLowerCase();
    final candidates = runLogs.where((runLog) {
      if (runLog.car.id != carId) {
        return false;
      }
      final linked = activeSettingId != null &&
          (runLog.baseSettingId == activeSettingId ||
              runLog.resultSettingId == activeSettingId);
      final sameTrack = normalizedTrack != null &&
          normalizedTrack.isNotEmpty &&
          runLog.trackName.trim().toLowerCase() == normalizedTrack;
      if (activeSettingId != null || normalizedTrack?.isNotEmpty == true) {
        return linked || sameTrack;
      }
      return true;
    }).toList();

    int rank(RunLog runLog) {
      if (activeSettingId != null &&
          (runLog.baseSettingId == activeSettingId ||
              runLog.resultSettingId == activeSettingId)) {
        return 0;
      }
      if (normalizedTrack != null &&
          runLog.trackName.trim().toLowerCase() == normalizedTrack) {
        return 1;
      }
      return 2;
    }

    candidates.sort((a, b) {
      final rankComparison = rank(a).compareTo(rank(b));
      if (rankComparison != 0) {
        return rankComparison;
      }
      return b.runAt.compareTo(a.runAt);
    });

    return candidates.take(5).map((runLog) {
      return <String, dynamic>{
        'runAt': runLog.runAt.toIso8601String(),
        if (runLog.trackName.trim().isNotEmpty) 'trackName': runLog.trackName,
        if (runLog.bestLapMillis > 0) 'bestLapMillis': runLog.bestLapMillis,
        if (runLog.airTempC != null) 'airTempC': runLog.airTempC,
        if (runLog.humidityPercent != null)
          'humidityPercent': runLog.humidityPercent,
        if (runLog.weatherCondition.trim().isNotEmpty)
          'weatherCondition': runLog.weatherCondition,
        if (runLog.trackTempC != null) 'trackTempC': runLog.trackTempC,
        if (runLog.trackCondition.trim().isNotEmpty)
          'trackCondition': runLog.trackCondition,
        'feelTags': runLog.feelTagIds
            .map((id) => runFeelTagLabel(id, isEnglish))
            .toList(growable: false),
        if (runLog.memo.trim().isNotEmpty)
          'memo': _truncate(runLog.memo.trim(), 500),
        'changes': runLog.changes.take(20).map((change) {
          return {
            'settingKey': change.settingKey,
            'settingLabel': change.settingLabel,
            'beforeValue': _normalizeValue(change.beforeValue),
            'afterValue': _normalizeValue(change.afterValue),
          };
        }).toList(growable: false),
      };
    }).toList(growable: false);
  }

  static bool _isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is List) {
      return value.map((item) {
        if (item is Map && item['row'] is num && item['col'] is num) {
          return 'R${(item['row'] as num).toInt() + 1}'
              'C${(item['col'] as num).toInt() + 1}';
        }
        return item.toString();
      }).toList(growable: false);
    }
    return value.toString();
  }

  static bool _sameValue(dynamic first, dynamic second) {
    try {
      return jsonEncode(first) == jsonEncode(second);
    } catch (_) {
      return first.toString() == second.toString();
    }
  }

  static double? _asDouble(dynamic value, {String? unit}) {
    if (value is num) return value.toDouble();
    if (value is! String) return null;
    var normalized = value.trim().replaceAll(',', '.');
    if (unit != null && unit.isNotEmpty) {
      normalized = normalized.replaceAll(unit, '');
    }
    return double.tryParse(normalized.trim());
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
