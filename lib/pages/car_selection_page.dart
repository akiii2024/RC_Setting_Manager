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
  final List<Manufacturer> manufacturers = [
    Manufacturer(
      id: '1',
      name: 'タミヤ',
      //imageUrl: 'assets/images/tamia.png',
      cars: [
        Car(
            id: 'trf420',
            name: 'TRF420x',
            imageUrl: 'assets/images/drift_car.png'),
        Car(
            id: 'trf421',
            name: 'TRF421',
            imageUrl: 'assets/images/touring_car.png'),
      ],
    ),
    Manufacturer(
      id: '2',
      name: 'ヨコモ',
      //imageUrl: 'assets/images/yokomo.png',
      cars: [
        Car(id: 'bd12', name: 'BD12', imageUrl: 'assets/images/buggy.png'),
      ],
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
                      cars: [],
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
    Key? key,
    required this.manufacturer,
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
                    Text(
                      isEnglish
                          ? '${manufacturer.cars.length} models'
                          : '${manufacturer.cars.length} 車種',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.manufacturer.name}の車種'),
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
                  setState(() {
                    widget.manufacturer.cars.add(
                      Car(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        imageUrl: 'assets/images/default_car.png',
                      ),
                    );
                  });
                  Navigator.of(context).pop();
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

class Manufacturer {
  final String id;
  final String name;
  //final String imageUrl;
  final List<Car> cars;

  Manufacturer({
    required this.id,
    required this.name,
    //required this.imageUrl,
    required this.cars,
  });
}
