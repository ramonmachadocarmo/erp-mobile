import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/sales/data/mappers.dart';

void main() {
  test('orderFrom', () {
    final o = orderFrom({
      'id': 'so1',
      'customer_id': 'c1',
      'status': 'UNDELIVERED',
      'total_amount': '12.5',
      'delivery_note': 'ausente',
      'address': {'alias': 'Casa', 'street': 'Rua', 'city': 'Manaus', 'state': 'AM'},
      'items': [
        {'product_id': 'p1', 'quantity': 2, 'unit_price': 6.25},
      ],
    });
    expect(o.status, 'UNDELIVERED');
    expect(o.totalAmount, 12.5);
    expect(o.deliveryNote, 'ausente');
    expect(o.address.alias, 'Casa');
    expect(o.items.single.quantity, 2);
  });

  test('candidateFrom and planFrom', () {
    final c = candidateFrom({
      'id': 'so1',
      'customer_id': 'c1',
      'weight_kg': 10,
      'volume_m3': 0.4,
      'has_geo': true,
      'planned': true,
    });
    expect(c.hasGeo, isTrue);
    expect(c.planned, isTrue);
    expect(c.weightKg, 10);

    final p = planFrom({
      'id': 'p1',
      'status': 'PLANNED',
      'distance_m': 1500,
      'duration_s': 120,
      'options': [
        {
          'label': 'Melhor tempo',
          'selected': true,
          'distance_m': 1500,
          'stops': [
            {'seq': 1, 'sales_order_id': 'so1', 'lat': -3.1, 'lng': -60},
          ],
        },
      ],
      'stops': [
        {'seq': 1, 'sales_order_id': 'so1', 'lat': -3.1, 'lng': -60},
      ],
    });
    expect(p.options.single.selected, isTrue);
    expect(p.stops.single.lat, -3.1);
  });

  test('planResultFrom skipped', () {
    final r = planResultFrom({
      'plans': [],
      'skipped': [
        {'order_id': 'so2', 'reason': 'already planned'},
      ],
    });
    expect(r.skipped.single.reason, 'already planned');
  });
}
