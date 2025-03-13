import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'car_setting_page.dart';
import '../models/manufacturer.dart';
import '../models/car.dart';
import '../models/visibility_settings.dart';

// ユーティリティクラス - 車種ごとの設定を管理
class CarSettingsUtil {
  // 車種名に基づいて追加の固有設定項目を取得する
  static Map<String, String> getAdditionalSettingsForModel(String modelName) {
    final Map<String, String> additionalSettings = {};

    if (modelName.toLowerCase().contains('trf421')) {
      // TRF421専用の設定項目を追加
      additionalSettings['frontSusMountPosition'] = 'number'; // サスマウントの位置を数値入力に
      additionalSettings['rearSusMountPosition'] =
          'number'; // リアサスマウントの位置を数値入力に
      additionalSettings['frontSuspensionArmThickness'] =
          'number'; // サスアームの厚みを追加
      additionalSettings['rearSuspensionArmThickness'] =
          'number'; // リアサスアームの厚みを追加
    } else if (modelName.toLowerCase().contains('trf420')) {
      // TRF420専用の設定項目を追加
      additionalSettings['frontAxisHeight'] = 'number'; // フロントアクスル高さ
      additionalSettings['motorCoolingType'] = 'select'; // モーター冷却タイプ
    }

    return additionalSettings;
  }
}

class CarListPage extends StatefulWidget {
  final Manufacturer manufacturer;

  const CarListPage({super.key, required this.manufacturer});

  @override
  State<CarListPage> createState() => _CarListPageState();
}

class _CarListPageState extends State<CarListPage> {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish
            ? '${widget.manufacturer.name} Models'
            : '${widget.manufacturer.name}の車種'),
      ),
      body: ListView.builder(
        itemCount: widget.manufacturer.cars.length,
        itemBuilder: (context, index) {
          return CarListItem(
            car: widget.manufacturer.cars[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CarSettingPage(
                      originalCar: widget.manufacturer.cars[index]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddCarDialog();
        },
        tooltip: isEnglish ? 'Add Model' : '車種を追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCarDialog() {
    final TextEditingController nameController = TextEditingController();
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    // 利用可能な設定項目のチェックボックスの状態を管理
    Map<String, bool> availableSettingsState = {};

    // 設定項目のタイプを管理
    Map<String, String> settingTypes = {};

    // 全ての設定項目リスト（デフォルトの設定項目から抽出）
    final allSettingKeys = VisibilitySettings.createDefault('temp')
        .settingsVisibility
        .keys
        .toList();

    // 初期状態を設定（デフォルトはすべて未選択）
    for (var key in allSettingKeys) {
      availableSettingsState[key] = false;
      settingTypes[key] = 'select'; // デフォルトは選択式
    }

    // 追加の設定項目
    final additionalSettings =
        CarSettingsUtil.getAdditionalSettingsForModel(nameController.text);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 車種名が変更された場合に追加設定を更新
            void updateAdditionalSettings() {
              final newAdditionalSettings =
                  CarSettingsUtil.getAdditionalSettingsForModel(
                      nameController.text);
              if (newAdditionalSettings.isNotEmpty) {
                setState(() {
                  for (var entry in newAdditionalSettings.entries) {
                    availableSettingsState[entry.key] = true;
                    settingTypes[entry.key] = entry.value;
                  }
                });
              }
            }

            return AlertDialog(
              title: Text(isEnglish ? 'Add New Model' : '新しい車種を追加'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500, // より多くの内容を表示するために高さを増やす
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Model Name' : '車種名',
                      ),
                      onChanged: (value) {
                        updateAdditionalSettings();
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEnglish ? 'Available Settings' : '利用可能な設定項目',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: _buildSettingCheckboxesWithType(
                            context,
                            availableSettingsState,
                            settingTypes,
                            setState,
                            isEnglish),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      // 選択された設定項目のリストを作成
                      List<String> selectedSettings = [];
                      Map<String, String> selectedTypes = {};

                      availableSettingsState.forEach((key, value) {
                        if (value) {
                          selectedSettings.add(key);
                          selectedTypes[key] = settingTypes[key]!;
                        }
                      });

                      // 新しい車種を作成
                      final newCar = Car(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        imageUrl: 'assets/images/default_car.png',
                        availableSettings: selectedSettings,
                        settingTypes: selectedTypes,
                      );

                      // 車種リストに追加
                      setState(() {
                        widget.manufacturer.cars.add(newCar);
                      });

                      // SettingsProviderの車種リストにも追加
                      settingsProvider.addCar(newCar);

                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(isEnglish ? 'Add' : '追加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 設定項目のチェックボックスを生成するヘルパーメソッド
  List<Widget> _buildSettingCheckboxes(
    Map<String, bool> availableSettingsState,
    Function(Function()) setState,
    bool isEnglish,
  ) {
    // 設定項目をカテゴリ別にグループ化
    Map<String, List<String>> groupedSettings = {};

    availableSettingsState.forEach((key, value) {
      String category = 'その他';

      if (key.startsWith('front')) {
        if (key.contains('Damper') || key.contains('Dumper')) {
          category = isEnglish ? 'Front Damper Settings' : 'フロントダンパー設定';
        } else {
          category = isEnglish ? 'Front Settings' : 'フロント設定';
        }
      } else if (key.startsWith('rear')) {
        if (key.contains('Damper') || key.contains('Dumper')) {
          category = isEnglish ? 'Rear Damper Settings' : 'リアダンパー設定';
        } else {
          category = isEnglish ? 'Rear Settings' : 'リア設定';
        }
      } else if (key == 'date' ||
          key == 'track' ||
          key == 'surface' ||
          key == 'airTemp' ||
          key == 'humidity' ||
          key == 'trackTemp' ||
          key == 'condition') {
        category = isEnglish ? 'Basic Information' : '基本情報';
      } else if (key.contains('upperDeck') || key.contains('ballast')) {
        category = isEnglish ? 'Top Settings' : 'トップ設定';
      } else if (key.contains('knucklearm') ||
          key.contains('steering') ||
          key.contains('lowerDeck')) {
        category = isEnglish ? 'Top Detailed Settings' : 'トップ詳細設定';
      } else if (key == 'motor' ||
          key == 'spurGear' ||
          key == 'pinionGear' ||
          key == 'battery' ||
          key == 'body' ||
          key == 'tire' ||
          key == 'wheel') {
        category = isEnglish ? 'Other Settings' : 'その他設定';
      }

      if (!groupedSettings.containsKey(category)) {
        groupedSettings[category] = [];
      }
      groupedSettings[category]!.add(key);
    });

    // チェックボックスウィジェットのリストを作成
    List<Widget> widgets = [];

    groupedSettings.forEach((category, keys) {
      widgets.add(
        ExpansionTile(
          title: Text(category),
          children: keys.map((key) {
            String label = key;

            // 設定項目名からラベルを生成（簡易的な実装）
            if (isEnglish) {
              // 英語ラベルの生成（ここでは簡易的に実装）
              label = key.replaceAllMapped(
                  RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}');
              label = label[0].toUpperCase() + label.substring(1);
            } else {
              // 日本語ラベルの生成（ここでは簡易的に実装）
              if (key.startsWith('front')) {
                label = 'フロント' + key.substring(5);
              } else if (key.startsWith('rear')) {
                label = 'リア' + key.substring(4);
              }
            }

            return CheckboxListTile(
              title: Text(label),
              value: availableSettingsState[key],
              onChanged: (bool? value) {
                setState(() {
                  availableSettingsState[key] = value ?? false;
                });
              },
            );
          }).toList(),
        ),
      );
    });

    return widgets;
  }

  // 設定項目のチェックボックスとタイプ選択を生成するヘルパーメソッド
  List<Widget> _buildSettingCheckboxesWithType(
    BuildContext context,
    Map<String, bool> availableSettingsState,
    Map<String, String> settingTypes,
    Function(Function()) setState,
    bool isEnglish,
  ) {
    // 設定項目をカテゴリ別にグループ化
    Map<String, List<String>> groupedSettings = {};

    availableSettingsState.forEach((key, value) {
      String category = 'その他';

      if (key.startsWith('front')) {
        if (key.contains('Damper') || key.contains('Dumper')) {
          category = isEnglish ? 'Front Damper Settings' : 'フロントダンパー設定';
        } else {
          category = isEnglish ? 'Front Settings' : 'フロント設定';
        }
      } else if (key.startsWith('rear')) {
        if (key.contains('Damper') || key.contains('Dumper')) {
          category = isEnglish ? 'Rear Damper Settings' : 'リアダンパー設定';
        } else {
          category = isEnglish ? 'Rear Settings' : 'リア設定';
        }
      } else if (key == 'date' ||
          key == 'track' ||
          key == 'surface' ||
          key == 'airTemp' ||
          key == 'humidity' ||
          key == 'trackTemp' ||
          key == 'condition') {
        category = isEnglish ? 'Basic Information' : '基本情報';
      } else if (key.contains('upperDeck') || key.contains('ballast')) {
        category = isEnglish ? 'Top Settings' : 'トップ設定';
      } else if (key.contains('knucklearm') ||
          key.contains('steering') ||
          key.contains('lowerDeck')) {
        category = isEnglish ? 'Top Detailed Settings' : 'トップ詳細設定';
      } else if (key == 'motor' ||
          key == 'spurGear' ||
          key == 'pinionGear' ||
          key == 'battery' ||
          key == 'body' ||
          key == 'tire' ||
          key == 'wheel') {
        category = isEnglish ? 'Other Settings' : 'その他設定';
      }

      if (!groupedSettings.containsKey(category)) {
        groupedSettings[category] = [];
      }
      groupedSettings[category]!.add(key);
    });

    // チェックボックスウィジェットのリストを作成
    List<Widget> widgets = [];

    groupedSettings.forEach((category, keys) {
      widgets.add(
        ExpansionTile(
          title: Text(category),
          children: keys.map((key) {
            String label = key;

            // 設定項目名からラベルを生成（簡易的な実装）
            if (isEnglish) {
              // 英語ラベルの生成
              label = key.replaceAllMapped(
                  RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}');
              label = label[0].toUpperCase() + label.substring(1);
            } else {
              // 日本語ラベルの生成
              if (key.startsWith('front')) {
                label = 'フロント' + key.substring(5);
              } else if (key.startsWith('rear')) {
                label = 'リア' + key.substring(4);
              }
            }

            return Column(
              children: [
                CheckboxListTile(
                  title: Text(label),
                  value: availableSettingsState[key],
                  onChanged: (bool? value) {
                    setState(() {
                      availableSettingsState[key] = value ?? false;
                    });
                  },
                ),
                // チェックボックスがオンの場合のみタイプ選択を表示
                if (availableSettingsState[key] == true)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, right: 16.0, bottom: 8.0),
                    child: Row(
                      children: [
                        Text(isEnglish ? 'Input Type: ' : '入力タイプ: '),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: settingTypes[key],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  settingTypes[key] = newValue;
                                });
                              }
                            },
                            items: <String>[
                              'select',
                              'text',
                              'number',
                              'slider'
                            ].map<DropdownMenuItem<String>>((String value) {
                              String displayValue;
                              switch (value) {
                                case 'select':
                                  displayValue =
                                      isEnglish ? 'Selection' : '選択式';
                                  break;
                                case 'text':
                                  displayValue =
                                      isEnglish ? 'Text Input' : 'テキスト入力';
                                  break;
                                case 'number':
                                  displayValue =
                                      isEnglish ? 'Number Input' : '数値入力';
                                  break;
                                case 'slider':
                                  displayValue = isEnglish ? 'Slider' : 'スライダー';
                                  break;
                                default:
                                  displayValue = value;
                              }

                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(displayValue),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      );
    });

    return widgets;
  }
}

class CarListItem extends StatelessWidget {
  final Car car;
  final VoidCallback onTap;

  const CarListItem({
    Key? key,
    required this.car,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_car, size: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEnglish
                          ? 'Tap to configure settings'
                          : 'タップしてセッティングを行う',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditCarDialog(context, car);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20),
                        const SizedBox(width: 8),
                        Text(isEnglish ? 'Edit Model Settings' : '車種設定を編集'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditCarDialog(BuildContext context, Car car) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;
    final TextEditingController nameController =
        TextEditingController(text: car.name);

    // 利用可能な設定項目のチェックボックスの状態を管理
    Map<String, bool> availableSettingsState = {};

    // 設定項目のタイプを管理
    Map<String, String> settingTypes = Map.from(car.settingTypes);

    // 全ての設定項目リスト（デフォルトの設定項目から抽出）
    final allSettingKeys = VisibilitySettings.createDefault('temp')
        .settingsVisibility
        .keys
        .toList();

    // 初期状態を設定
    for (var key in allSettingKeys) {
      availableSettingsState[key] = car.availableSettings.contains(key);
      // 設定タイプが未設定の場合はデフォルト値「select」を設定
      if (!settingTypes.containsKey(key)) {
        settingTypes[key] = 'select';
      }
    }

    // 車種固有の追加設定項目を取得
    final additionalSettings =
        CarSettingsUtil.getAdditionalSettingsForModel(car.name);
    if (additionalSettings.isNotEmpty) {
      for (var entry in additionalSettings.entries) {
        if (!availableSettingsState.containsKey(entry.key)) {
          availableSettingsState[entry.key] = true;
        }
        if (!settingTypes.containsKey(entry.key)) {
          settingTypes[entry.key] = entry.value;
        }
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 車種名が変更された場合に追加設定を更新
            void updateAdditionalSettings(String newName) {
              final newAdditionalSettings =
                  CarSettingsUtil.getAdditionalSettingsForModel(newName);
              if (newAdditionalSettings.isNotEmpty) {
                setState(() {
                  for (var entry in newAdditionalSettings.entries) {
                    availableSettingsState[entry.key] = true;
                    settingTypes[entry.key] = entry.value;
                  }
                });
              }
            }

            return AlertDialog(
              title: Text(isEnglish ? 'Edit Model Settings' : '車種設定の編集'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: isEnglish ? 'Model Name' : '車種名',
                      ),
                      onChanged: (value) {
                        updateAdditionalSettings(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEnglish ? 'Available Settings' : '利用可能な設定項目',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: _buildSettingCheckboxesWithType(
                            context,
                            availableSettingsState,
                            settingTypes,
                            setState,
                            isEnglish),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    // 選択された設定項目のリストを作成
                    List<String> selectedSettings = [];
                    Map<String, String> selectedTypes = {};

                    availableSettingsState.forEach((key, value) {
                      if (value) {
                        selectedSettings.add(key);
                        selectedTypes[key] = settingTypes[key]!;
                      }
                    });

                    // 車種を更新
                    final updatedCar = Car(
                      id: car.id,
                      name: nameController.text,
                      imageUrl: car.imageUrl,
                      settings: car.settings,
                      availableSettings: selectedSettings,
                      settingTypes: selectedTypes,
                    );

                    // SettingsProviderを通じて更新
                    settingsProvider.updateCar(updatedCar);

                    // 表示設定も更新（新しい利用可能な設定項目に基づいて）
                    final visibilitySettings =
                        settingsProvider.getVisibilitySettings(car.id);
                    Map<String, bool> updatedVisibility = {};

                    // 選択された設定項目のみを含める
                    for (var key in selectedSettings) {
                      updatedVisibility[key] =
                          visibilitySettings.settingsVisibility[key] ?? true;
                    }

                    final updatedVisibilitySettings = VisibilitySettings(
                      carId: car.id,
                      settingsVisibility: updatedVisibility,
                    );

                    settingsProvider
                        .updateVisibilitySettings(updatedVisibilitySettings);

                    Navigator.of(context).pop();
                  },
                  child: Text(isEnglish ? 'Save' : '保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 設定項目のチェックボックスとタイプ選択を生成するヘルパーメソッド
  List<Widget> _buildSettingCheckboxesWithType(
    BuildContext context,
    Map<String, bool> availableSettingsState,
    Map<String, String> settingTypes,
    Function(Function()) setState,
    bool isEnglish,
  ) {
    // 設定項目をカテゴリ別にグループ化
    Map<String, List<String>> groupedSettings = {};

    availableSettingsState.forEach((key, value) {
      String category = 'その他';

      if (key.startsWith('front')) {
        if (key.contains('Damper') || key.contains('Dumper')) {
          category = isEnglish ? 'Front Damper Settings' : 'フロントダンパー設定';
        } else {
          category = isEnglish ? 'Front Settings' : 'フロント設定';
        }
      } else if (key.startsWith('rear')) {
        if (key.contains('Damper') || key.contains('Dumper')) {
          category = isEnglish ? 'Rear Damper Settings' : 'リアダンパー設定';
        } else {
          category = isEnglish ? 'Rear Settings' : 'リア設定';
        }
      } else if (key == 'date' ||
          key == 'track' ||
          key == 'surface' ||
          key == 'airTemp' ||
          key == 'humidity' ||
          key == 'trackTemp' ||
          key == 'condition') {
        category = isEnglish ? 'Basic Information' : '基本情報';
      } else if (key.contains('upperDeck') || key.contains('ballast')) {
        category = isEnglish ? 'Top Settings' : 'トップ設定';
      } else if (key.contains('knucklearm') ||
          key.contains('steering') ||
          key.contains('lowerDeck')) {
        category = isEnglish ? 'Top Detailed Settings' : 'トップ詳細設定';
      } else if (key == 'motor' ||
          key == 'spurGear' ||
          key == 'pinionGear' ||
          key == 'battery' ||
          key == 'body' ||
          key == 'tire' ||
          key == 'wheel') {
        category = isEnglish ? 'Other Settings' : 'その他設定';
      }

      if (!groupedSettings.containsKey(category)) {
        groupedSettings[category] = [];
      }
      groupedSettings[category]!.add(key);
    });

    // チェックボックスウィジェットのリストを作成
    List<Widget> widgets = [];

    groupedSettings.forEach((category, keys) {
      widgets.add(
        ExpansionTile(
          title: Text(category),
          children: keys.map((key) {
            String label = key;

            // 設定項目名からラベルを生成（簡易的な実装）
            if (isEnglish) {
              // 英語ラベルの生成
              label = key.replaceAllMapped(
                  RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}');
              label = label[0].toUpperCase() + label.substring(1);
            } else {
              // 日本語ラベルの生成
              if (key.startsWith('front')) {
                label = 'フロント' + key.substring(5);
              } else if (key.startsWith('rear')) {
                label = 'リア' + key.substring(4);
              }
            }

            return Column(
              children: [
                CheckboxListTile(
                  title: Text(label),
                  value: availableSettingsState[key],
                  onChanged: (bool? value) {
                    setState(() {
                      availableSettingsState[key] = value ?? false;
                    });
                  },
                ),
                // チェックボックスがオンの場合のみタイプ選択を表示
                if (availableSettingsState[key] == true)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, right: 16.0, bottom: 8.0),
                    child: Row(
                      children: [
                        Text(isEnglish ? 'Input Type: ' : '入力タイプ: '),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: settingTypes[key],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  settingTypes[key] = newValue;
                                });
                              }
                            },
                            items: <String>[
                              'select',
                              'text',
                              'number',
                              'slider'
                            ].map<DropdownMenuItem<String>>((String value) {
                              String displayValue;
                              switch (value) {
                                case 'select':
                                  displayValue =
                                      isEnglish ? 'Selection' : '選択式';
                                  break;
                                case 'text':
                                  displayValue =
                                      isEnglish ? 'Text Input' : 'テキスト入力';
                                  break;
                                case 'number':
                                  displayValue =
                                      isEnglish ? 'Number Input' : '数値入力';
                                  break;
                                case 'slider':
                                  displayValue = isEnglish ? 'Slider' : 'スライダー';
                                  break;
                                default:
                                  displayValue = value;
                              }

                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(displayValue),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      );
    });

    return widgets;
  }
}
