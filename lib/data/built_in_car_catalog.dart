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
    final xray = Manufacturer(
      id: 'xray',
      name: 'XRAY',
      logoPath: 'assets/images/xray.png',
    );
    final arc = Manufacturer(
      id: 'arc',
      name: 'ARC',
      logoPath: 'assets/images/arc.png',
    );
    final awesomatix = Manufacturer(
      id: 'awesomatix',
      name: 'Awesomatix',
      logoPath: 'assets/images/awesomatix.png',
    );
    final infinity = Manufacturer(
      id: 'infinity',
      name: 'Infinity',
      logoPath: 'assets/images/infinity.png',
    );
    final mugen = Manufacturer(
      id: 'mugen',
      name: 'Mugen',
      logoPath: 'assets/images/mugen.png',
    );
    final schumacher = Manufacturer(
      id: 'schumacher',
      name: 'Schumacher',
      logoPath: 'assets/images/schumacher.png',
    );
    final xpress = Manufacturer(
      id: 'xpress',
      name: 'Xpress',
      logoPath: 'assets/images/xpress.png',
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
        id: 'tamiya/trf420',
        name: 'TRF420',
        imageUrl: 'assets/images/trf420.jpg',
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
      Car(
        id: 'xray/x4_24',
        name: "X4'24",
        imageUrl: 'assets/images/x4_24.jpg',
        manufacturer: xray,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'awesomatix/a800r',
        name: 'A800R',
        imageUrl: 'assets/images/a800r.jpg',
        manufacturer: awesomatix,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'schumacher/mi9',
        name: 'Mi9',
        imageUrl: 'assets/images/mi9.jpg',
        manufacturer: schumacher,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'infinity/if14_2',
        name: 'IF14-2',
        imageUrl: 'assets/images/if14_2.jpg',
        manufacturer: infinity,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'arc/arc_r12',
        name: 'R12',
        imageUrl: 'assets/images/arc_r12.jpg',
        manufacturer: arc,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'xpress/xq11r',
        name: 'XQ11R',
        imageUrl: 'assets/images/xq11r.jpg',
        manufacturer: xpress,
        category: 'ツーリングカー',
      ),
      Car(
        id: 'mugen/mtc2_fwd',
        name: 'MTC2 FWD',
        imageUrl: 'assets/images/mtc2_fwd.jpg',
        manufacturer: mugen,
        category: 'FFツーリングカー',
      ),
      Car(
        id: 'mugen/mtc3',
        name: 'MTC3',
        imageUrl: 'assets/images/mtc3.jpg',
        manufacturer: mugen,
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
