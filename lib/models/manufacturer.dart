import 'car.dart';

class Manufacturer {
  final String id;
  final String name;
  final List<Car> cars;

  Manufacturer({
    required this.id,
    required this.name,
    required this.cars,
  });
}
