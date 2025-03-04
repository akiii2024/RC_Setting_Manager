import 'package:flutter/material.dart';
import 'car_setting_page.dart';
import 'settings_page.dart';
import '../models/car.dart';

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
        Car(id: '1', name: 'TRF420x', imageUrl: 'assets/images/drift_car.png'),
        Car(id: '2', name: 'TRF421', imageUrl: 'assets/images/touring_car.png'),
      ],
    ),
    Manufacturer(
      id: '2',
      name: 'ヨコモ',
      //imageUrl: 'assets/images/yokomo.png',
      cars: [
        Car(id: '3', name: 'BD12', imageUrl: 'assets/images/buggy.png'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メーカー選択'),
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
        tooltip: 'メーカーを追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddManufacturerDialog() {
    final TextEditingController nameController = TextEditingController();
    //String selectedImageUrl = 'assets/images/default_manufacturer.png';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新しいメーカーを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'メーカー名',
                ),
              ),
              const SizedBox(height: 16),
              const Text('注: 現在はデフォルト画像が使用されます'),
            ],
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
                    manufacturers.add(
                      Manufacturer(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        //imageUrl: selectedImageUrl,
                        cars: [],
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        //leading: Image.asset(
        //  manufacturer.imageUrl,
        //  width: 60,
        //  height: 60,
        //  errorBuilder: (context, error, stackTrace) {
        //    return const Icon(Icons.factory, size: 60);
        //  },
        //),
        title: Text(manufacturer.name),
        subtitle: Text('${manufacturer.cars.length}台の車種'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
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
