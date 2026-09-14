import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/maps.dart';

void main() {
  test('mapsDirUrl with origin and stops', () {
    expect(
      mapsDirUrl(origin: const Geo(-3.1, -60), stops: const [Geo(-3.2, -60.1), Geo(-3.3, -60.2)]),
      'https://www.google.com/maps/dir/-3.1,-60.0/-3.2,-60.1/-3.3,-60.2',
    );
  });

  test('mapsDirUrl skips empty', () {
    expect(mapsDirUrl(origin: const Geo(-3.1, -60), stops: const []), '');
    expect(mapsDirUrl(stops: const [Geo(0, 0)]), '');
  });

  test('mapsStopUrl and wazeNavUrl', () {
    expect(
      mapsStopUrl(-3.1, -60),
      'https://www.google.com/maps/dir/?api=1&destination=-3.1,-60.0&travelmode=driving',
    );
    expect(wazeNavUrl(-3.1, -60), 'https://waze.com/ul?ll=-3.1,-60.0&navigate=yes');
  });
}
