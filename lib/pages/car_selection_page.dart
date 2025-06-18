import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'car_setting_page.dart';
import 'settings_page.dart';
import '../models/car.dart';
import '../models/manufacturer.dart';
import 'car_list_page.dart';

class CarSelectionPage extends StatefulWidget {
  const CarSelectionPage({super.key});

  @override
  State<CarSelectionPage> createState() => _CarSelectionPageState();
}

class _CarSelectionPageState extends State<CarSelectionPage> {
  late final List<Manufacturer> manufacturers;

  @override
  void initState() {
    super.initState();
    
    final tamiyaManufacturer = Manufacturer(
      id: '1',
      name: 'タミヤ',
      logoPath: 'assets/images/tamiya.png',
    );
    
    final yokomoManufacturer = Manufacturer(
      id: '2',
      name: 'ヨコモ',
      logoPath: 'assets/images/yokomo.png',
    );
    
    manufacturers = [
      tamiyaManufacturer,
      yokomoManufacturer,
    ];
  }

  List<Car> get allCars => [
    Car(
      id: 'tamiya/trf420x',
      name: 'TRF420x',
      imageUrl: 'assets/images/drift_car.png',
      manufacturer: manufacturers[0],
      category: 'Touring Car',
    ),
    Car(
      id: 'tamiya/trf421',
      name: 'TRF421',
      imageUrl: 'assets/images/touring_car.png',
      manufacturer: manufacturers[0],
      category: 'Touring Car',
    ),
    Car(
      id: 'yokomo/bd12',
      name: 'BD12',
      imageUrl: 'assets/images/buggy.png',
      manufacturer: manufacturers[1],
      category: 'Buggy',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? 'Manufacturer Selection' : 'メーカー選択'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: manufacturers.length,
        itemBuilder: (context, index) {
          return ManufacturerListItem(
            manufacturer: manufacturers[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CarListPage(manufacturer: manufacturers[index]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddManufacturerDialog();
        },
        tooltip: isEnglish ? 'Add Manufacturer' : 'メーカーを追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddManufacturerDialog() {
    final TextEditingController nameController = TextEditingController();
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isEnglish = settingsProvider.isEnglish;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEnglish ? 'Add New Manufacturer' : '新しいメーカーを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Manufacturer Name' : 'メーカー名',
                ),
              ),
              const SizedBox(height: 16),
              Text(isEnglish
                  ? 'Note: Default image will be used for now.'
                  : '注: 現在はデフォルト画像が使用されます'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    manufacturers.add(Manufacturer(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      logoPath: '',
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(isEnglish ? 'Add' : '追加'),
            ),
          ],
        );
      },
    );
  }
}

class ManufacturerListItem extends StatelessWidget {
  final Manufacturer manufacturer;
  final VoidCallback onTap;

  const ManufacturerListItem({
    super.key,
    required this.manufacturer,
    required this.onTap,
  });

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
                child: const Icon(Icons.business, size: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manufacturer.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Consumer<SettingsProvider>(
                      builder: (context, settingsProvider, child) {
                        final carCount = settingsProvider.cars
                            .where((car) => car.manufacturer.id == manufacturer.id)
                            .length;
                        return Text(
                          isEnglish
                              ? '$carCount models'
                              : '$carCount 車種',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class CarListPage extends StatefulWidget {
  final Manufacturer manufacturer;

  const CarListPage({super.key, required this.manufacturer});

  @override
  State<CarListPage> createState() => _CarListPageState();
}

class _CarListPageState extends State<CarListPage> {
  List<Car> get manufacturerCars {
    // 親ページのallCarsから該当メーカーの車種を取得
    final parentState = context.findAncestorStateOfType<_CarSelectionPageState>();
    if (parentState != null) {
      return parentState.allCars
          .where((car) => car.manufacturer.id == widget.manufacturer.id)
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final cars = manufacturerCars;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.manufacturer.name}の車種'),
      ),
      body: ListView.builder(
        itemCount: cars.length,
        itemBuilder: (context, index) {
          return CarListItem(
            car: cars[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CarSettingPage(
                      originalCar: cars[index]),
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
        tooltip: '車種を追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCarDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新しい車種を追加'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '車種名',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final newCar = Car(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    imageUrl: 'assets/images/default_car.png',
                    manufacturer: widget.manufacturer,
                    category: 'Custom',
                  );
                  
                  // SettingsProviderに車種を追加
                  final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                  settingsProvider.addCar(newCar);
                  
                  Navigator.of(context).pop();
                  setState(() {}); // UIを更新
                }
              },
              child: const Text('追加'),
            ),
          ],
        );
      },
    );
  }
}

class CarListItem extends StatelessWidget {
  final Car car;
  final VoidCallback onTap;

  const CarListItem({
    super.key,
    required this.car,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Image.asset(
          car.imageUrl,
          width: 60,
          height: 60,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.directions_car, size: 60);
          },
        ),
        title: Text(car.name),
        subtitle: const Text('タップしてセッティングを表示'),
        onTap: onTap,
      ),
    );
  }
}

