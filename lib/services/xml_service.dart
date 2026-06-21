import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/run_log.dart';
import '../models/saved_setting.dart';
import '../models/car.dart';
import '../models/manufacturer.dart';
import '../models/visibility_settings.dart';

// エクスポート・インポートのデータタイプ
enum DataType {
  cars,
  savedSettings,
  runLogs,
  visibilitySettings,
  languageSettings,
}

// エクスポート・インポートのオプション
class ExportImportOptions {
  final bool includeCars;
  final bool includeSavedSettings;
  final bool includeRunLogs;
  final bool includeVisibilitySettings;
  final bool includeLanguageSettings;

  const ExportImportOptions({
    this.includeCars = true,
    this.includeSavedSettings = true,
    this.includeRunLogs = true,
    this.includeVisibilitySettings = true,
    this.includeLanguageSettings = true,
  });

  List<DataType> get selectedTypes {
    List<DataType> types = [];
    if (includeCars) types.add(DataType.cars);
    if (includeSavedSettings) types.add(DataType.savedSettings);
    if (includeRunLogs) types.add(DataType.runLogs);
    if (includeVisibilitySettings) types.add(DataType.visibilitySettings);
    if (includeLanguageSettings) types.add(DataType.languageSettings);
    return types;
  }
}

class XmlService {
  // データをXML形式でエクスポート（部分的エクスポート対応）
  static Future<String> exportToXml({
    required List<SavedSetting> savedSettings,
    List<RunLog> runLogs = const [],
    required List<Car> cars,
    required Map<String, VisibilitySettings> visibilitySettings,
    required bool isEnglish,
    ExportImportOptions? options,
  }) async {
    final exportOptions = options ?? const ExportImportOptions();
    final builder = XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('RCCarSettingsData', nest: () {
      // メタデータ
      builder.element('metadata', nest: () {
        builder.element('exportDate', nest: DateTime.now().toIso8601String());
        builder.element('version', nest: '1.0');
        builder.element('exportedTypes', nest: () {
          for (final type in exportOptions.selectedTypes) {
            builder.element('type', nest: type.name);
          }
        });
        if (exportOptions.includeLanguageSettings) {
          builder.element('language', nest: isEnglish ? 'en' : 'ja');
        }
      });

      // 車種データ（選択されている場合のみ）
      if (exportOptions.includeCars) {
        builder.element('cars', nest: () {
          for (final car in cars) {
            builder.element('car', nest: () {
              builder.element('id', nest: car.id);
              builder.element('name', nest: car.name);
              builder.element('manufacturer', nest: car.manufacturer.name);
              builder.element('category', nest: car.category);
              builder.element('isInGarage', nest: car.isInGarage.toString());
              builder.element(
                'suppressGaragePrompt',
                nest: car.suppressGaragePrompt.toString(),
              );
              builder.element('availableSettings', nest: () {
                for (final setting in car.availableSettings) {
                  builder.element('setting', nest: setting);
                }
              });
            });
          }
        });
      }

      // 保存された設定データ（選択されている場合のみ）
      if (exportOptions.includeSavedSettings) {
        builder.element('savedSettings', nest: () {
          for (final setting in savedSettings) {
            builder.element('savedSetting', nest: () {
              builder.element('id', nest: setting.id);
              builder.element('name', nest: setting.name);
              builder.element('createdAt',
                  nest: setting.createdAt.toIso8601String());
              builder.element('kind', nest: setting.kind.name);
              builder.element('sourceRunLogId',
                  nest: setting.sourceRunLogId ?? '');
              builder.element('parentSettingId',
                  nest: setting.parentSettingId ?? '');

              // 車種情報
              builder.element('car', nest: () {
                builder.element('id', nest: setting.car.id);
                builder.element('name', nest: setting.car.name);
                builder.element('manufacturer',
                    nest: setting.car.manufacturer.name);
                builder.element('category', nest: setting.car.category);
              });

              // 設定値
              builder.element('settings', nest: () {
                setting.settings.forEach((key, value) {
                  builder.element('setting', nest: () {
                    builder.attribute('key', key);
                    builder.text(value.toString());
                  });
                });
              });
            });
          }
        });
      }

      // 走行ログデータ（選択されている場合のみ）
      if (exportOptions.includeRunLogs) {
        builder.element('runLogs', nest: () {
          for (final runLog in runLogs) {
            builder.element('runLog', nest: () {
              builder.element('id', nest: runLog.id);
              builder.element('createdAt',
                  nest: runLog.createdAt.toIso8601String());
              builder.element('runAt', nest: runLog.runAt.toIso8601String());

              builder.element('car', nest: () {
                builder.element('id', nest: runLog.car.id);
                builder.element('name', nest: runLog.car.name);
                builder.element('manufacturer',
                    nest: runLog.car.manufacturer.name);
                builder.element('category', nest: runLog.car.category);
              });

              builder.element('baseSettingId',
                  nest: runLog.baseSettingId ?? '');
              builder.element('baseSettingName',
                  nest: runLog.baseSettingName ?? '');
              builder.element('resultSettingId',
                  nest: runLog.resultSettingId ?? '');
              builder.element('resultSettingName',
                  nest: runLog.resultSettingName ?? '');
              builder.element('bestLapMillis',
                  nest: runLog.bestLapMillis.toString());
              builder.element('conditions', nest: () {
                builder.element('airTempC',
                    nest: runLog.airTempC?.toString() ?? '');
                builder.element('humidityPercent',
                    nest: runLog.humidityPercent?.toString() ?? '');
                builder.element('weatherCondition',
                    nest: runLog.weatherCondition);
                builder.element('trackTempC',
                    nest: runLog.trackTempC?.toString() ?? '');
                builder.element('trackCondition', nest: runLog.trackCondition);
              });
              builder.element('memo', nest: runLog.memo);

              builder.element('feelTagIds', nest: () {
                for (final tagId in runLog.feelTagIds) {
                  builder.element('tag', nest: tagId);
                }
              });

              builder.element('changes', nest: () {
                for (final change in runLog.changes) {
                  builder.element('change', nest: () {
                    builder.element('settingKey', nest: change.settingKey);
                    builder.element('settingLabel', nest: change.settingLabel);
                    builder.element('beforeValue',
                        nest: change.beforeValue?.toString() ?? '');
                    builder.element('afterValue',
                        nest: change.afterValue?.toString() ?? '');
                  });
                }
              });
            });
          }
        });
      }

      if (exportOptions.includeVisibilitySettings) {
        builder.element('visibilitySettings', nest: () {
          visibilitySettings.forEach((carId, visibility) {
            builder.element('carVisibility', nest: () {
              builder.element('carId', nest: carId);
              builder.element('settings', nest: () {
                visibility.settingsVisibility.forEach((key, isVisible) {
                  builder.element('setting', nest: () {
                    builder.attribute('key', key);
                    builder.text(isVisible.toString());
                  });
                });
              });
            });
          });
        });
      }
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }

  // XMLファイルをエクスポート（部分的エクスポート対応）
  static Future<void> exportToFile({
    required List<SavedSetting> savedSettings,
    List<RunLog> runLogs = const [],
    required List<Car> cars,
    required Map<String, VisibilitySettings> visibilitySettings,
    required bool isEnglish,
    ExportImportOptions? options,
  }) async {
    try {
      final xmlContent = await exportToXml(
        savedSettings: savedSettings,
        runLogs: runLogs,
        cars: cars,
        visibilitySettings: visibilitySettings,
        isEnglish: isEnglish,
        options: options,
      );

      final fileName =
          'rc_car_settings_${DateTime.now().millisecondsSinceEpoch}.xml';

      if (kIsWeb) {
        // Web環境では直接共有
        await Share.share(xmlContent, subject: fileName);
      } else {
        // モバイル環境では従来の方法
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');

        await file.writeAsString(xmlContent);

        // ファイルを共有
        await Share.shareXFiles(
          [XFile(file.path)],
          text: isEnglish ? 'RC Car Settings Export' : 'RCカーセッティングエクスポート',
        );
      }
    } catch (e) {
      throw Exception('Export failed: $e');
    }
  }

  // XMLからデータをインポート（部分的インポート対応）
  static Future<ImportResult> importFromXml(String xmlContent,
      {ExportImportOptions? options}) async {
    final importOptions = options ?? const ExportImportOptions();
    try {
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement;

      if (root.name.local != 'RCCarSettingsData') {
        throw Exception(
            'Invalid XML format: Root element must be RCCarSettingsData');
      }

      // メタデータを読み込み
      final metadataElement = root.findElements('metadata').firstOrNull;
      String? version;
      String? language;
      DateTime? exportDate;
      List<String> exportedTypes = [];

      if (metadataElement != null) {
        version =
            metadataElement.findElements('version').firstOrNull?.innerText;
        language =
            metadataElement.findElements('language').firstOrNull?.innerText;
        final exportDateStr =
            metadataElement.findElements('exportDate').firstOrNull?.innerText;
        if (exportDateStr != null) {
          exportDate = DateTime.tryParse(exportDateStr);
        }

        // エクスポートされたデータタイプを取得
        final exportedTypesElement =
            metadataElement.findElements('exportedTypes').firstOrNull;
        if (exportedTypesElement != null) {
          for (final typeElement in exportedTypesElement.findElements('type')) {
            exportedTypes.add(typeElement.innerText);
          }
        }
      }

      // 車種データを読み込み（インポートオプションで選択されている場合のみ）
      final cars = <Car>[];
      if (importOptions.includeCars) {
        final carsElement = root.findElements('cars').firstOrNull;
        if (carsElement != null) {
          for (final carElement in carsElement.findElements('car')) {
            final id =
                carElement.findElements('id').firstOrNull?.innerText ?? '';
            final name =
                carElement.findElements('name').firstOrNull?.innerText ?? '';
            final manufacturerName = carElement
                    .findElements('manufacturer')
                    .firstOrNull
                    ?.innerText ??
                '';
            final category =
                carElement.findElements('category').firstOrNull?.innerText ??
                    '';
            final isInGarage = carElement
                    .findElements('isInGarage')
                    .firstOrNull
                    ?.innerText
                    .toLowerCase() ==
                'true';
            final suppressGaragePrompt = carElement
                    .findElements('suppressGaragePrompt')
                    .firstOrNull
                    ?.innerText
                    .toLowerCase() ==
                'true';

            final availableSettings = <String>[];
            final availableSettingsElement =
                carElement.findElements('availableSettings').firstOrNull;
            if (availableSettingsElement != null) {
              for (final settingElement
                  in availableSettingsElement.findElements('setting')) {
                availableSettings.add(settingElement.innerText);
              }
            }

            // Manufacturerオブジェクトを作成（簡易版）
            final manufacturer = Manufacturer(
              id: manufacturerName.toLowerCase(),
              name: manufacturerName,
              logoPath: '', // デフォルト値
            );

            cars.add(Car(
              id: id,
              name: name,
              imageUrl: '', // デフォルト値
              manufacturer: manufacturer,
              category: category,
              availableSettings: availableSettings,
              isInGarage: isInGarage,
              suppressGaragePrompt: suppressGaragePrompt,
            ));
          }
        }
      }

      // 保存された設定データを読み込み（インポートオプションで選択されている場合のみ）
      final savedSettings = <SavedSetting>[];
      if (importOptions.includeSavedSettings) {
        final savedSettingsElement =
            root.findElements('savedSettings').firstOrNull;
        if (savedSettingsElement != null) {
          for (final settingElement
              in savedSettingsElement.findElements('savedSetting')) {
            final id =
                settingElement.findElements('id').firstOrNull?.innerText ?? '';
            final name =
                settingElement.findElements('name').firstOrNull?.innerText ??
                    '';
            final createdAtStr = settingElement
                    .findElements('createdAt')
                    .firstOrNull
                    ?.innerText ??
                '';
            final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();

            // 車種情報を読み込み
            final carElement = settingElement.findElements('car').firstOrNull;
            Car? car;
            if (carElement != null) {
              final carId =
                  carElement.findElements('id').firstOrNull?.innerText ?? '';
              final carName =
                  carElement.findElements('name').firstOrNull?.innerText ?? '';
              final manufacturerName = carElement
                      .findElements('manufacturer')
                      .firstOrNull
                      ?.innerText ??
                  '';
              final category =
                  carElement.findElements('category').firstOrNull?.innerText ??
                      '';

              final manufacturer = Manufacturer(
                id: manufacturerName.toLowerCase(),
                name: manufacturerName,
                logoPath: '',
              );

              car = Car(
                id: carId,
                name: carName,
                imageUrl: '', // デフォルト値
                manufacturer: manufacturer,
                category: category,
                availableSettings: [],
              );
            }

            // 設定値を読み込み
            final settings = <String, dynamic>{};
            final settingsElement =
                settingElement.findElements('settings').firstOrNull;
            if (settingsElement != null) {
              for (final setting in settingsElement.findElements('setting')) {
                final key = setting.getAttribute('key') ?? '';
                final value = setting.innerText;

                // 数値の場合は適切な型に変換
                if (double.tryParse(value) != null) {
                  settings[key] = double.parse(value);
                } else if (int.tryParse(value) != null) {
                  settings[key] = int.parse(value);
                } else if (value.toLowerCase() == 'true' ||
                    value.toLowerCase() == 'false') {
                  settings[key] = value.toLowerCase() == 'true';
                } else {
                  settings[key] = value;
                }
              }
            }

            if (car != null) {
              savedSettings.add(SavedSetting(
                id: id,
                name: name,
                createdAt: createdAt,
                car: car,
                settings: settings,
                kind: _parseSavedSettingKind(
                    settingElement.findElements('kind').firstOrNull?.innerText),
                sourceRunLogId: _emptyToNull(settingElement
                    .findElements('sourceRunLogId')
                    .firstOrNull
                    ?.innerText),
                parentSettingId: _emptyToNull(settingElement
                    .findElements('parentSettingId')
                    .firstOrNull
                    ?.innerText),
              ));
            }
          }
        }
      }

      // 走行ログデータを読み込み（インポートオプションで選択されている場合のみ）
      final runLogs = <RunLog>[];
      if (importOptions.includeRunLogs) {
        final runLogsElement = root.findElements('runLogs').firstOrNull;
        if (runLogsElement != null) {
          for (final runLogElement in runLogsElement.findElements('runLog')) {
            final id =
                runLogElement.findElements('id').firstOrNull?.innerText ?? '';
            final createdAtStr = runLogElement
                    .findElements('createdAt')
                    .firstOrNull
                    ?.innerText ??
                '';
            final runAtStr =
                runLogElement.findElements('runAt').firstOrNull?.innerText ??
                    '';
            final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
            final runAt = DateTime.tryParse(runAtStr) ?? createdAt;

            final carElement = runLogElement.findElements('car').firstOrNull;
            Car? car;
            if (carElement != null) {
              final carId =
                  carElement.findElements('id').firstOrNull?.innerText ?? '';
              final carName =
                  carElement.findElements('name').firstOrNull?.innerText ?? '';
              final manufacturerName = carElement
                      .findElements('manufacturer')
                      .firstOrNull
                      ?.innerText ??
                  '';
              final category =
                  carElement.findElements('category').firstOrNull?.innerText ??
                      '';
              final manufacturer = Manufacturer(
                id: manufacturerName.toLowerCase(),
                name: manufacturerName,
                logoPath: '',
              );
              car = Car(
                id: carId,
                name: carName,
                imageUrl: '',
                manufacturer: manufacturer,
                category: category,
              );
            }

            final feelTagIds = <String>[];
            final feelTagIdsElement =
                runLogElement.findElements('feelTagIds').firstOrNull;
            if (feelTagIdsElement != null) {
              for (final tagElement in feelTagIdsElement.findElements('tag')) {
                feelTagIds.add(tagElement.innerText);
              }
            }

            final changes = <RunSettingChange>[];
            final changesElement =
                runLogElement.findElements('changes').firstOrNull;
            if (changesElement != null) {
              for (final changeElement
                  in changesElement.findElements('change')) {
                final beforeElement =
                    changeElement.findElements('beforeValue').firstOrNull;
                final afterElement =
                    changeElement.findElements('afterValue').firstOrNull;
                changes.add(
                  RunSettingChange(
                    settingKey: changeElement
                            .findElements('settingKey')
                            .firstOrNull
                            ?.innerText ??
                        '',
                    settingLabel: changeElement
                            .findElements('settingLabel')
                            .firstOrNull
                            ?.innerText ??
                        '',
                    beforeValue: beforeElement == null
                        ? null
                        : _parseXmlValue(beforeElement.innerText),
                    afterValue: afterElement == null
                        ? null
                        : _parseXmlValue(afterElement.innerText),
                  ),
                );
              }
            }

            final conditionsElement =
                runLogElement.findElements('conditions').firstOrNull;

            if (car != null) {
              runLogs.add(
                RunLog(
                  id: id,
                  createdAt: createdAt,
                  runAt: runAt,
                  car: car,
                  baseSettingId: _emptyToNull(runLogElement
                      .findElements('baseSettingId')
                      .firstOrNull
                      ?.innerText),
                  baseSettingName: _emptyToNull(runLogElement
                      .findElements('baseSettingName')
                      .firstOrNull
                      ?.innerText),
                  resultSettingId: _emptyToNull(runLogElement
                      .findElements('resultSettingId')
                      .firstOrNull
                      ?.innerText),
                  resultSettingName: _emptyToNull(runLogElement
                      .findElements('resultSettingName')
                      .firstOrNull
                      ?.innerText),
                  bestLapMillis: int.tryParse(runLogElement
                              .findElements('bestLapMillis')
                              .firstOrNull
                              ?.innerText ??
                          '') ??
                      0,
                  airTempC: _readOptionalDouble(
                    conditionsElement,
                    'airTempC',
                  ),
                  humidityPercent: _readOptionalDouble(
                    conditionsElement,
                    'humidityPercent',
                  ),
                  weatherCondition: conditionsElement
                          ?.findElements('weatherCondition')
                          .firstOrNull
                          ?.innerText ??
                      '',
                  trackTempC: _readOptionalDouble(
                    conditionsElement,
                    'trackTempC',
                  ),
                  trackCondition: conditionsElement
                          ?.findElements('trackCondition')
                          .firstOrNull
                          ?.innerText ??
                      '',
                  feelTagIds: feelTagIds,
                  memo: runLogElement
                          .findElements('memo')
                          .firstOrNull
                          ?.innerText ??
                      '',
                  changes: changes,
                ),
              );
            }
          }
        }
      }

      final visibilitySettings = <String, VisibilitySettings>{};
      if (importOptions.includeVisibilitySettings) {
        final visibilitySettingsElement =
            root.findElements('visibilitySettings').firstOrNull;
        if (visibilitySettingsElement != null) {
          for (final carVisibilityElement
              in visibilitySettingsElement.findElements('carVisibility')) {
            final carId = carVisibilityElement
                    .findElements('carId')
                    .firstOrNull
                    ?.innerText ??
                '';

            final settingsVisibility = <String, bool>{};
            final settingsElement =
                carVisibilityElement.findElements('settings').firstOrNull;
            if (settingsElement != null) {
              for (final setting in settingsElement.findElements('setting')) {
                final key = setting.getAttribute('key') ?? '';
                final isVisible = setting.innerText.toLowerCase() == 'true';
                settingsVisibility[key] = isVisible;
              }
            }

            if (carId.isNotEmpty) {
              visibilitySettings[carId] = VisibilitySettings(
                carId: carId,
                settingsVisibility: settingsVisibility,
              );
            }
          }
        }
      }

      return ImportResult(
        cars: cars,
        savedSettings: savedSettings,
        runLogs: runLogs,
        visibilitySettings: visibilitySettings,
        metadata: ImportMetadata(
          version: version,
          language: language,
          exportDate: exportDate,
          exportedTypes: exportedTypes,
        ),
      );
    } catch (e) {
      throw Exception('Import failed: $e');
    }
  }

  // ファイルからXMLをインポート（部分的インポート対応）
  static SavedSettingKind _parseSavedSettingKind(String? value) {
    if (value != null) {
      for (final kind in SavedSettingKind.values) {
        if (kind.name == value) {
          return kind;
        }
      }
    }
    return SavedSettingKind.manual;
  }

  static double? _readOptionalDouble(XmlElement? parent, String elementName) {
    final value = parent?.findElements(elementName).firstOrNull?.innerText;
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  static dynamic _parseXmlValue(String value) {
    if (int.tryParse(value) != null) {
      return int.parse(value);
    }
    if (double.tryParse(value) != null) {
      return double.parse(value);
    }
    if (value.toLowerCase() == 'true' || value.toLowerCase() == 'false') {
      return value.toLowerCase() == 'true';
    }
    return value;
  }

  static String? _emptyToNull(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static Future<ImportResult> importFromFile(String filePath,
      {ExportImportOptions? options}) async {
    if (kIsWeb) {
      throw UnsupportedError('Web環境ではファイルからのインポートはできません');
    }

    try {
      final file = File(filePath);
      final xmlContent = await file.readAsString();
      return await importFromXml(xmlContent, options: options);
    } catch (e) {
      throw Exception('Failed to read file: $e');
    }
  }
}

// インポート結果を格納するクラス
class ImportResult {
  final List<Car> cars;
  final List<SavedSetting> savedSettings;
  final List<RunLog> runLogs;
  final Map<String, VisibilitySettings> visibilitySettings;
  final ImportMetadata metadata;

  ImportResult({
    required this.cars,
    required this.savedSettings,
    this.runLogs = const [],
    required this.visibilitySettings,
    required this.metadata,
  });
}

// インポートメタデータを格納するクラス
class ImportMetadata {
  final String? version;
  final String? language;
  final DateTime? exportDate;
  final List<String> exportedTypes;

  ImportMetadata({
    this.version,
    this.language,
    this.exportDate,
    this.exportedTypes = const [],
  });
}
