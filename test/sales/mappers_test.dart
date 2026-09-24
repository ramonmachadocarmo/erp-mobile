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
}
