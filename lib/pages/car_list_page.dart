import 'package:flutter/material.dart';
import 'car_setting_page.dart';
import '../models/manufacturer.dart';
import '../models/car.dart';

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
