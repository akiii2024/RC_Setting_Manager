import '../../data/built_in_car_catalog.dart';
import '../../data/car_settings_definitions.dart';
import '../../models/car.dart';
import '../../models/manufacturer.dart';

/// 車両状態と車両固有の参照ルールを保持する内部ストア。
class CarStore {
  List<Car> _cars = [];

  List<Car> get cars => _cars;

  List<Car> get garageCars =>
      _cars.where((car) => car.isInGarage).toList(growable: false);

  void replace(List<Car> cars) {
    _cars = cars;
  }

  void useInitialCars() {
    _cars = BuiltInCarCatalog.create();
  }

  bool mergeBuiltInCars({void Function(Object error)? onError}) {
    try {
      final mergedCars = BuiltInCarCatalog.mergeInto(_cars);
      final didAddCars = mergedCars.length != _cars.length;
      _cars = mergedCars;
      return didAddCars;
    } catch (error) {
      onError?.call(error);
      return false;
    }
  }

  bool update(Car updatedCar) {
    final index = _cars.indexWhere((car) => car.id == updatedCar.id);
    if (index == -1) {
      return false;
    }
    _cars[index] = updatedCar;
    return true;
  }

  void add(Car car) {
    _cars.add(car);
  }

  void delete(String carId) {
    _cars.removeWhere((car) => car.id == carId);
  }

  Car? byId(String carId) {
    for (final car in _cars) {
      if (car.id == carId) {
        return car;
      }
    }
    return null;
  }

  List<Manufacturer> manufacturers() {
    final manufacturers = <String, Manufacturer>{};
    for (final car in _cars) {
      manufacturers[car.manufacturer.id] = car.manufacturer;
    }
    final values = manufacturers.values.toList();
    values.sort((a, b) => a.name.compareTo(b.name));
    return values;
  }

  Map<Manufacturer, List<Car>> garageCarsByManufacturer() {
    final groupedCars = <String, List<Car>>{};
    final manufacturers = <String, Manufacturer>{};

    for (final car in garageCars) {
      manufacturers[car.manufacturer.id] = car.manufacturer;
      groupedCars.putIfAbsent(car.manufacturer.id, () => <Car>[]).add(car);
    }

    final manufacturerIds = groupedCars.keys.toList()
      ..sort(
        (a, b) => manufacturers[a]!.name.compareTo(manufacturers[b]!.name),
      );

    return {
      for (final manufacturerId in manufacturerIds)
        manufacturers[manufacturerId]!: groupedCars[manufacturerId]!
          ..sort((a, b) => a.name.compareTo(b.name)),
    };
  }

  List<String> availableSettings(String carId) {
    final car = byId(carId);
    if (car != null && car.availableSettings.isNotEmpty) {
      return car.availableSettings;
    }

    final definition = getCarSettingDefinition(carId);
    return definition?.availableSettings
            .map((setting) => setting.key)
            .toList(growable: false) ??
        [];
  }
}
