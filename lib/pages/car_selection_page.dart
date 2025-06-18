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
  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isEnglish = settingsProvider.isEnglish;
    final manufacturers = settingsProvider.getManufacturers();

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
      body: manufacturers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_car,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEnglish 
                        ? 'No manufacturers available.\nTap + to add one.'
                        : 'メーカーがありません。\n+ボタンで追加してください。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
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
                  // 新しいメーカーの車種を追加（サンプル車種として）
                  final newManufacturer = Manufacturer(
                    id: name.toLowerCase().replaceAll(' ', '_'),
                    name: name,
                    logoPath: 'assets/images/default_manufacturer.png',
                  );
                  
                  final sampleCar = Car(
                    id: '${newManufacturer.id}/sample_car',
                    name: 'Sample Car',
                    imageUrl: 'assets/images/default_car.png',
                    manufacturer: newManufacturer,
                    category: 'Custom',
                  );
                  
                  settingsProvider.addCar(sampleCar);
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

