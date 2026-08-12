import '../models/car.dart';
import '../models/manufacturer.dart';

/// Canonical built-in chassis catalog.
///
/// IDs and serialized model values are persisted, so this catalog deliberately
/// keeps the legacy values stable.
abstract final class BuiltInCarCatalog {
  static List<Car> create() {
    final tamiya = Manufacturer(
      id: 'tamiya',
      name: 'タミヤ',
      logoPath: 'assets/images/tamiya.png',
    );
    final yokomo = Manufacturer(
      id: 'yokomo',
      name: 'ヨコモ',
      logoPath: 'assets/images/yokomo.png',
    );

    return [
      Car(
        id: 'tamiya/trf421',
        name: 'TRF421',
        imageUrl: 'assets/images/trf421.jpg',
        manufacturer: tamiya,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'tamiya/trf420x',
        name: 'TRF420X',
        imageUrl: 'assets/images/trf420x.jpg',
        manufacturer: tamiya,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'tamiya/trf421x',
        name: 'TRF421X',
        imageUrl: 'assets/images/trf421x.jpg',
        manufacturer: tamiya,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'yokomo/bd11',
        name: 'BD11',
        imageUrl: 'assets/images/bd11.jpg',
        manufacturer: yokomo,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'yokomo/bd12',
        name: 'BD12',
        imageUrl: 'assets/images/bd12.jpg',
        manufacturer: yokomo,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'yokomo/ms1_0',
        name: 'MS1.0',
        imageUrl: 'assets/images/ms1_0.jpg',
        manufacturer: yokomo,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'yokomo/ms2_0',
        name: 'MS2.0',
        imageUrl: 'assets/images/ms2_0.jpg',
        manufacturer: yokomo,
        category: 'ツーリングカー',
      ),
    ];
  }

  static List<Car> mergeInto(Iterable<Car> cars) {
    final merged = List<Car>.from(cars);
    final existingIds = merged.map((car) => car.id).toSet();

    for (final builtInCar in create()) {
      if (existingIds.add(builtInCar.id)) {
        merged.add(builtInCar);
      }
    }
    return merged;
  }
}
